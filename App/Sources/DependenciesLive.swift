import Foundation
import ComposableArchitecture
import Domain
import ArchiveKit
import IntelligenceKit
import PersistenceKit
import ImageCacheKit
import ThumbnailKit
import AppFeature
import BrowseFeature
import LibraryFeature
import ReaderFeature
import SettingsFeature
import SourceKit

enum LiveDependencies {
    static func register() {
        // App-wide default reading settings for users who haven't changed them:
        // right-to-left progression and cover-page-solo (first page on its own),
        // matching how manga is normally read. register(defaults:) never
        // overwrites a value the user has explicitly set.
        UserDefaults.standard.register(defaults: [
            SettingsFeature.directionKey: PageProgressionDirection.rightToLeft.rawValue,
            SettingsFeature.pageOffsetKey: "true"
        ])

        let stack = try! SwiftDataStack.onDisk(
            url: URL.applicationSupportDirectory.appending(path: "mana.store")
        )

        let comicRepo = ComicRepositoryLive(stack: stack)
        let progressRepo = ProgressRepositoryLive(stack: stack)
        let folderRepo = FolderRepositoryLive(stack: stack)
        let router = DefaultArchiveReaderRouter()
        let cache = ImageCache(
            diskDirectory: URL.cachesDirectory.appending(path: "mana-pages"),
            diskCapacityBytes: 200_000_000
        )
        let thumbnails = ThumbnailProviderLive(
            cacheDir: URL.cachesDirectory.appending(path: "mana-thumbs")
        )
        let importer = LibraryImporterLive(
            repo: comicRepo, router: router, cache: cache, thumbnails: thumbnails
        )
        let translationCache = TranslationCacheLive(stack: stack)

        // Online source + download stack.
        let source = RawkumaSource()
        let sourceRegistry = RawkumaRegistry(rawkuma: source)
        let sourceHTTP = SourceHTTP()
        let chapterDownloader = ChapterDownloaderLive(
            source: source, http: sourceHTTP, importer: importer, comicRepo: comicRepo, folderRepo: folderRepo
        )
        let downloadNotifier = DownloadNotifier()
        let downloadQueueStore = DownloadQueueStoreLive()
        let downloadManager = DownloadManagerLive(
            downloader: chapterDownloader, store: downloadQueueStore, notifier: downloadNotifier
        )
        let readChapterRepo = ReadChapterRepositoryLive()
        let libraryReset = LibraryResetServiceLive(
            comicRepo: comicRepo,
            folderRepo: folderRepo,
            progressRepo: progressRepo,
            imageCache: cache,
            translationCache: translationCache
        )

        prepareDependencies {
            $0.archiveReaderRouter = router
            $0.progressRepository = progressRepo
            $0.imageCache = cache
            $0.comicRepository = comicRepo
            $0.libraryImporter = importer
            $0.folderRepository = folderRepo
            $0.userDefaults = LiveUserDefaultsClient()
            $0.libraryResetService = libraryReset
            $0.translationCache = translationCache
            // On-device translation (OCR + Apple Translation framework, iOS 18+).
            // Availability is gated on the OS version inside IntelligenceAvailabilityLive;
            // on older systems the Settings section and Reader controls stay hidden.
            $0.intelligenceAvailability = IntelligenceAvailabilityLive()
            // Engine chosen in Settings (Apple on-device vs Gemini cloud), read fresh per page so a
            // change takes effect without relaunch. An optional build-time key (Info.plist
            // `GeminiDefaultKey`) lets Gemini work before the user enters their own.
            let bundledGeminiKey = (Bundle.main.object(forInfoDictionaryKey: "GeminiDefaultKey") as? String) ?? ""
            let engineRouter = EngineRoutingTranslator(configProvider: {
                let d = UserDefaults.standard
                let engineRaw = d.string(forKey: SettingsFeature.translationEngineKey) ?? TranslationEngine.gemini.rawValue
                return EngineRoutingTranslator.Config(
                    engine: TranslationEngine(rawStringOrDefault: engineRaw),
                    apiKey: d.string(forKey: SettingsFeature.geminiApiKeyKey) ?? "",
                    model: d.string(forKey: SettingsFeature.geminiModelKey).flatMap { $0.isEmpty ? nil : $0 } ?? "gemini-flash-latest",
                    defaultKey: bundledGeminiKey
                )
            })
            $0.pageTranslator = PageTranslatorLive(llm: engineRouter)
            $0.sourceRegistry = sourceRegistry
            $0.downloadManager = downloadManager
            $0.readChapterRepository = readChapterRepo
        }

        let reconcile = LibraryReconcileService(repo: comicRepo, importer: importer)
        Task.detached(priority: .utility) {
            await reconcile.reconcile()
        }

        // Surface and auto-resume any downloads interrupted by a previous app kill.
        downloadNotifier.requestAuthorization()
        Task {
            await downloadManager.restore()
            downloadManager.resumePending()
        }
    }
}
