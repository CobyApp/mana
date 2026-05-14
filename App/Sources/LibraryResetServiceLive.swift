import Foundation
import Domain
import PersistenceKit
import ImageCacheKit

public struct LibraryResetServiceLive: LibraryResetService {
    let comicRepo: any ComicRepository
    let folderRepo: any FolderRepository
    let progressRepo: any ProgressRepository
    let imageCache: ImageCache
    let translationCache: any TranslationCache

    public init(
        comicRepo: any ComicRepository,
        folderRepo: any FolderRepository,
        progressRepo: any ProgressRepository,
        imageCache: ImageCache,
        translationCache: any TranslationCache
    ) {
        self.comicRepo = comicRepo
        self.folderRepo = folderRepo
        self.progressRepo = progressRepo
        self.imageCache = imageCache
        self.translationCache = translationCache
    }

    public func resetAll() async throws {
        let allComics = await comicRepo.all()
        let allFolders = await folderRepo.all()
        for comic in allComics {
            try? FileManager.default.removeItem(at: comic.url)
            try? await comicRepo.delete(comic.id)
        }
        for folder in allFolders {
            try? await folderRepo.delete(folder.id)
        }
        try? await translationCache.deleteEverything()
        let localDir = LibraryStorage.libraryDirectory
        try? FileManager.default.removeItem(at: localDir)
        try? FileManager.default.createDirectory(at: localDir, withIntermediateDirectories: true)
        await imageCache.evictMemory()
    }
}
