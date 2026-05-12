import Foundation
import Domain
import ArchiveKit
import ImageCacheKit
import ThumbnailKit
import LibraryFeature

public struct LibraryImporterLive: LibraryImporter {
    let repo: any ComicRepository
    let router: any ArchiveReaderRouter
    let cache: ImageCache
    let thumbnails: ThumbnailProviderLive

    public init(
        repo: any ComicRepository,
        router: any ArchiveReaderRouter,
        cache: ImageCache,
        thumbnails: ThumbnailProviderLive
    ) {
        self.repo = repo
        self.router = router
        self.cache = cache
        self.thumbnails = thumbnails
    }

    public func importFiles(_ urls: [URL], folderId: UUID?) async throws -> [ComicItem] {
        var results: [ComicItem] = []
        for url in urls {
            let needsStop = url.startAccessingSecurityScopedResource()
            defer { if needsStop { url.stopAccessingSecurityScopedResource() } }

            guard let format = ComicFormat(fileExtension: url.pathExtension) else {
                throw ArchiveError.unsupportedFormat(url.pathExtension)
            }

            let canonicalURL = try copyToLocalLibrary(source: url)

            let reader = router.reader(for: format)
            let handle = try await reader.openArchive(at: canonicalURL)
            let pageCount = await reader.pageCount(handle)
            let id = UUID()

            var thumb: Data?
            if pageCount > 0, let raw = try? await reader.pageData(handle, index: 0) {
                thumb = try? await thumbnails.storeThumbnail(comicId: id, page: 0, rawPageBytes: raw, maxDim: 256)
            }
            await reader.closeArchive(handle)

            let title = canonicalURL.deletingPathExtension().lastPathComponent
            let size = (try? FileManager.default.attributesOfItem(atPath: canonicalURL.path)[.size] as? NSNumber)?.int64Value ?? 0

            let item = ComicItem(
                id: id,
                url: canonicalURL,
                format: format,
                title: title,
                pageCount: pageCount,
                coverThumbnail: thumb,
                dateAdded: Date(),
                fileSizeBytes: size,
                readingMode: nil,
                folderId: folderId,
                pageProgressionDirection: nil
            )
            try await repo.upsert(item)
            results.append(item)
        }
        return results
    }

    private func copyToLocalLibrary(source: URL) throws -> URL {
        let fm = FileManager.default
        let libraryDir = LibraryStorage.libraryDirectory
        try? fm.createDirectory(at: libraryDir, withIntermediateDirectories: true)

        // Reconcile passes files already inside the library directory; treat
        // those as no-ops so reindexing doesn't duplicate or fail.
        if source.standardizedFileURL.deletingLastPathComponent() == libraryDir.standardizedFileURL {
            return source
        }

        var dest = libraryDir.appending(path: source.lastPathComponent)
        var counter = 2
        while fm.fileExists(atPath: dest.path) {
            let stem = (source.lastPathComponent as NSString).deletingPathExtension
            let ext = (source.lastPathComponent as NSString).pathExtension
            let newName = ext.isEmpty ? "\(stem) \(counter)" : "\(stem) \(counter).\(ext)"
            dest = libraryDir.appending(path: newName)
            counter += 1
        }
        try fm.copyItem(at: source, to: dest)
        return dest
    }
}

public enum LibraryStorage {
    /// Canonical on-disk location for imported comic files. Lives under
    /// Application Support so it shares the SwiftData store's lifecycle and
    /// stays out of Files.app.
    public static var libraryDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "Mana Library")
    }

    /// Pre-`Mana Library` location under Documents. Kept only for migration
    /// at app startup.
    public static var legacyLibraryDirectory: URL {
        URL.documentsDirectory.appending(path: "Mana Library")
    }
}
