import Foundation
import Domain
import ArchiveKit
import ImageCacheKit
import LibraryFeature

public struct LibraryImporterLive: LibraryImporter {
    let repo: any ComicRepository
    let router: any ArchiveReaderRouter
    let cache: ImageCache

    public init(repo: any ComicRepository, router: any ArchiveReaderRouter, cache: ImageCache) {
        self.repo = repo
        self.router = router
        self.cache = cache
    }

    public func importFiles(_ urls: [URL]) async throws -> [ComicItem] {
        var results: [ComicItem] = []
        for url in urls {
            let needsStop = url.startAccessingSecurityScopedResource()
            defer { if needsStop { url.stopAccessingSecurityScopedResource() } }

            let format = ComicFormat(fileExtension: url.pathExtension) ?? .zip
            let reader = router.reader(for: format)
            let handle = try await reader.openArchive(at: url)
            let pageCount = await reader.pageCount(handle)

            var thumb: Data?
            if pageCount > 0 {
                thumb = try? await reader.pageData(handle, index: 0)
            }
            await reader.closeArchive(handle)

            let id = UUID()
            let title = url.deletingPathExtension().lastPathComponent
            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0

            let item = ComicItem(
                id: id,
                url: url,
                format: format,
                title: title,
                pageCount: pageCount,
                coverThumbnail: thumb,
                dateAdded: Date(),
                fileSizeBytes: size
            )
            try await repo.upsert(item)
            results.append(item)
        }
        return results
    }
}
