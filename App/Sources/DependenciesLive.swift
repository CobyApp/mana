import Foundation
import ComposableArchitecture
import Domain
import ArchiveKit
import IntelligenceKit
import PersistenceKit
import ImageCacheKit
import ThumbnailKit
import AppFeature
import LibraryFeature
import ReaderFeature
import SettingsFeature

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
            $0.pageTranslator = PageTranslatorLive(llm: AppleTranslator())
        }

        let reconcile = LibraryReconcileService(repo: comicRepo, importer: importer)
        Task.detached(priority: .utility) {
            await reconcile.reconcile()
        }
    }
}
