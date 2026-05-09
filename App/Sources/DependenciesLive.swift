import Foundation
import ComposableArchitecture
import Domain
import ArchiveKit
import PersistenceKit
import ImageCacheKit
import ThumbnailKit
import CloudSyncKit
import LibraryFeature
import ReaderFeature
import SettingsFeature

enum LiveDependencies {
    static let containerIdentifier = "iCloud.com.coby.mana"

    static func register() {
        let ubi = UbiquityContainer(identifier: containerIdentifier)

        let stack: SwiftDataStack
        if ubi.isAvailable, let cloudStack = try? SwiftDataStack.cloudKit(containerIdentifier: containerIdentifier) {
            stack = cloudStack
        } else {
            stack = try! SwiftDataStack.onDisk(
                url: URL.applicationSupportDirectory.appending(path: "mana.store")
            )
        }

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
        let fileSync = FileSyncServiceLive(ubi: ubi)
        let importer = LibraryImporterLive(
            repo: comicRepo, router: router, cache: cache,
            thumbnails: thumbnails, fileSync: fileSync
        )
        let libraryReset = LibraryResetServiceLive(
            comicRepo: comicRepo,
            folderRepo: folderRepo,
            ubiquityContainerURL: ubi.containerURL,
            imageCache: cache
        )

        prepareDependencies {
            $0.archiveReaderRouter = router
            $0.progressRepository = progressRepo
            $0.imageCache = cache
            $0.comicRepository = comicRepo
            $0.libraryImporter = importer
            $0.folderRepository = folderRepo
            $0.userDefaults = LiveUserDefaultsClient()
            $0.fileSyncService = fileSync
            $0.libraryResetService = libraryReset
        }
    }
}
