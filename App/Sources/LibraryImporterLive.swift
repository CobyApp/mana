import Foundation
import Domain
import ArchiveKit
import ImageCacheKit
import ThumbnailKit
import CloudSyncKit
import LibraryFeature

public struct LibraryImporterLive: LibraryImporter {
    let repo: any ComicRepository
    let router: any ArchiveReaderRouter
    let cache: ImageCache
    let thumbnails: ThumbnailProviderLive
    let fileSync: any FileSyncService

    public init(
        repo: any ComicRepository,
        router: any ArchiveReaderRouter,
        cache: ImageCache,
        thumbnails: ThumbnailProviderLive,
        fileSync: any FileSyncService
    ) {
        self.repo = repo
        self.router = router
        self.cache = cache
        self.thumbnails = thumbnails
        self.fileSync = fileSync
    }

    public func importFiles(_ urls: [URL]) async throws -> [ComicItem] {
        var results: [ComicItem] = []
        for url in urls {
            let needsStop = url.startAccessingSecurityScopedResource()
            defer { if needsStop { url.stopAccessingSecurityScopedResource() } }

            guard let format = ComicFormat(fileExtension: url.pathExtension) else {
                throw ArchiveError.unsupportedFormat(url.pathExtension)
            }

            // If iCloud is available, copy file into ubiquity container.
            // Otherwise keep the picked URL and store its bookmark for re-resolution.
            let canonicalURL: URL
            let bookmark: Data?
            if await fileSync.isAvailable {
                canonicalURL = try await fileSync.ingest(localURL: url)
                bookmark = nil
            } else {
                canonicalURL = url
                bookmark = try? BookmarkURLResolver.bookmarkData(for: url)
            }

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
                urlBookmarkData: bookmark
            )
            try await repo.upsert(item)
            results.append(item)
        }
        return results
    }
}
