import Testing
import Foundation
@testable import Mana
import Domain
import ArchiveKit
import PersistenceKit
import ImageCacheKit
import LibraryFeature

@Suite struct IntegrationFlowTests {
    private final class BundleAnchor {}

    @Test func importThenReadFirstPageEndToEnd() async throws {
        // Wire real components except SwiftData (in-memory).
        let stack = try SwiftDataStack.inMemory()
        let comicRepo = ComicRepositoryLive(stack: stack)
        let router = DefaultArchiveReaderRouter()
        let cache = ImageCache.inMemoryOnly()
        let importer = LibraryImporterLive(repo: comicRepo, router: router, cache: cache)

        let fixture = try #require(Bundle(for: BundleAnchor.self).url(forResource: "sample", withExtension: "cbz"))

        // Import
        let imported = try await importer.importFiles([fixture])
        #expect(imported.count == 1)
        let comic = imported[0]
        #expect(comic.format == .cbz)
        #expect(comic.pageCount == 3)
        #expect(comic.coverThumbnail != nil)

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
    }
}
