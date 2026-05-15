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
            if #available(iOS 18.0, *) {
                $0.intelligenceAvailability = IntelligenceAvailabilityLive()
                $0.pageTranslator = PageTranslatorLive(llm: AppleTranslator())
            } else {
                $0.intelligenceAvailability = UnavailableIntelligence()
                $0.pageTranslator = NoopPageTranslator()
            }
        }

        let reconcile = LibraryReconcileService(repo: comicRepo, importer: importer)
        Task.detached(priority: .utility) {
            await reconcile.reconcile()
        }
    }
}
