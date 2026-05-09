import Foundation
import Domain
import PersistenceKit
import ImageCacheKit

public struct LibraryResetServiceLive: LibraryResetService {
    let comicRepo: any ComicRepository
    let folderRepo: any FolderRepository
    let ubiquityContainerURL: URL?
    let imageCache: ImageCache

    public init(
        comicRepo: any ComicRepository,
        folderRepo: any FolderRepository,
        ubiquityContainerURL: URL?,
        imageCache: ImageCache
    ) {
        self.comicRepo = comicRepo
        self.folderRepo = folderRepo
        self.ubiquityContainerURL = ubiquityContainerURL
        self.imageCache = imageCache
    }

    public func resetAll() async throws {
        let allComics = await comicRepo.all()
        let allFolders = await folderRepo.all()
        let fm = FileManager.default
        for comic in allComics {
            // Delete file (removeItem works for both local and iCloud files on iOS)
            try? fm.removeItem(at: comic.url)
            // Delete record
            try? await comicRepo.delete(comic.id)
        }
        for folder in allFolders {
            try? await folderRepo.delete(folder.id)
        }
        // Wipe local Documents/Mana Library directory entirely (covers any orphan files)
        let localDir = URL.documentsDirectory.appending(path: "Mana Library")
        try? fm.removeItem(at: localDir)
        try? fm.createDirectory(at: localDir, withIntermediateDirectories: true)
        // Wipe ubiquity container Documents (if available)
        if let containerURL = ubiquityContainerURL {
            let items = (try? fm.contentsOfDirectory(at: containerURL, includingPropertiesForKeys: nil)) ?? []
            for item in items {
                try? fm.removeItem(at: item)
            }
        }
        // Evict in-memory image cache (best-effort)
        await imageCache.evictMemory()
    }
}
