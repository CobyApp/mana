import Testing
import Foundation
import UIKit
@testable import Mana
import Domain
import ArchiveKit
import PersistenceKit
import ImageCacheKit
import ThumbnailKit
import LibraryFeature
import ReaderFeature
import ComposableArchitecture
import SettingsFeature

@Suite struct IntegrationFlowTests {
    private final class BundleAnchor {}

    @Test func importThenReadFirstPageEndToEnd() async throws {
        // Wire real components except SwiftData (in-memory).
        let stack = try SwiftDataStack.inMemory()
        let comicRepo = ComicRepositoryLive(stack: stack)
        let router = DefaultArchiveReaderRouter()
        let cache = ImageCache.inMemoryOnly()
        let thumbDir = FileManager.default.temporaryDirectory.appending(path: "thumbs-\(UUID())")
        let thumbnails = ThumbnailProviderLive(cacheDir: thumbDir)
        let importer = LibraryImporterLive(
            repo: comicRepo, router: router, cache: cache, thumbnails: thumbnails
        )

        let fixture = try #require(Bundle(for: BundleAnchor.self).url(forResource: "sample", withExtension: "cbz"))

        // Import
        let imported = try await importer.importFiles([fixture], folderId: nil)
        #expect(imported.count == 1)
        let comic = imported[0]
        #expect(comic.format == .cbz)
        #expect(comic.pageCount == 3)
        // sample.cbz first page is "PAGE1" (5 raw bytes, not a real image),
        // so downsampling fails and the thumbnail stays nil. That's expected.
        #expect(comic.coverThumbnail == nil)
        #expect(comic.readingMode == nil)
        #expect(comic.folderId == nil)

        // Verify in repo
        let stored = await comicRepo.all()
        #expect(stored.count == 1)
        #expect(stored.first?.id == comic.id)

        // Open via router and read first page
        let reader = router.reader(for: comic.format)
        let handle = try await reader.openArchive(at: comic.url)
        let firstPage = try await reader.pageData(handle, index: 0)
        #expect(String(data: firstPage, encoding: .utf8) == "PAGE1")
        await reader.closeArchive(handle)

        try? FileManager.default.removeItem(at: thumbDir)
    }

}

private func makePlaceholderPNG() -> Data {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10))
    let img = renderer.image { ctx in
        UIColor.white.setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
    }
    return img.pngData()!
}

private struct NoopArchiveReaderRouter: ArchiveReaderRouter {
    func reader(for format: ComicFormat) -> any ArchiveReader { NoopArchiveReader() }
}

private struct NoopArchiveReader: ArchiveReader {
    func openArchive(at url: URL) async throws -> ArchiveHandle { ArchiveHandle() }
    func pageCount(_ handle: ArchiveHandle) async -> Int { 0 }
    func pageData(_ handle: ArchiveHandle, index: Int) async throws -> Data { Data() }
    func closeArchive(_ handle: ArchiveHandle) async {}
}
