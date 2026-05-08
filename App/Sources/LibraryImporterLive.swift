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

    public func importFiles(_ urls: [URL]) async throws -> [ComicItem] {
        var results: [ComicItem] = []
        for url in urls {
            let needsStop = url.startAccessingSecurityScopedResource()
            defer { if needsStop { url.stopAccessingSecurityScopedResource() } }

            guard let format = ComicFormat(fileExtension: url.pathExtension) else {
                throw ArchiveError.unsupportedFormat(url.pathExtension)
            }

            let reader = router.reader(for: format)
            let handle = try await reader.openArchive(at: url)
            let pageCount = await reader.pageCount(handle)
            let id = UUID()

            var thumb: Data?
            if pageCount > 0, let raw = try? await reader.pageData(handle, index: 0) {
                thumb = try? await thumbnails.storeThumbnail(comicId: id, page: 0, rawPageBytes: raw, maxDim: 256)
            }
            await reader.closeArchive(handle)

            let title = url.deletingPathExtension().lastPathComponent
            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0

            let item = ComicItem(
                id: id,
                url: url,
                format: format,
                title: title,
                pageCount: pageCount,
                coverThumbnail: thumb,           // small (<100KB) JPEG
                dateAdded: Date(),
                fileSizeBytes: size,
                readingMode: nil
            )
            try await repo.upsert(item)
            results.append(item)
        }
        return results
    }
}
