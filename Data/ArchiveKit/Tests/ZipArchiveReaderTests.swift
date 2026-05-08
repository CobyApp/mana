import Testing
import Foundation
@testable import ArchiveKit
import Domain

@Suite struct ZipArchiveReaderTests {
    private final class BundleAnchor {}

    private func fixtureURL() throws -> URL {
        let url = Bundle(for: BundleAnchor.self).url(forResource: "sample", withExtension: "cbz")
        try #require(url != nil)
        return url!
    }

    @Test func opensCbzAndReportsThreePages() async throws {
        let reader = ZipArchiveReader()
        let handle = try await reader.openArchive(at: fixtureURL())
        #expect(await reader.pageCount(handle) == 3)
        await reader.closeArchive(handle)
    }

    @Test func readsFirstPageBytes() async throws {
        let reader = ZipArchiveReader()
        let handle = try await reader.openArchive(at: fixtureURL())
        let data = try await reader.pageData(handle, index: 0)
        #expect(String(data: data, encoding: .utf8) == "PAGE1")
        await reader.closeArchive(handle)
    }

    @Test func indexOutOfBoundsThrows() async throws {
        let reader = ZipArchiveReader()
        let handle = try await reader.openArchive(at: fixtureURL())
        await #expect(throws: ArchiveError.indexOutOfBounds(99)) {
            _ = try await reader.pageData(handle, index: 99)
        }
        await reader.closeArchive(handle)
    }

    @Test func pagesAreSortedByName() async throws {
        let reader = ZipArchiveReader()
        let handle = try await reader.openArchive(at: fixtureURL())
        let p0 = try await reader.pageData(handle, index: 0)
        let p1 = try await reader.pageData(handle, index: 1)
        let p2 = try await reader.pageData(handle, index: 2)
        #expect(String(data: p0, encoding: .utf8) == "PAGE1")
        #expect(String(data: p1, encoding: .utf8) == "PAGE2-CONTENTS")
        #expect(String(data: p2, encoding: .utf8) == "PAGE3-MORE-CONTENTS")
        await reader.closeArchive(handle)
    }

    @Test func routerReturnsZipReaderForCbz() {
        let router = DefaultArchiveReaderRouter(zip: ZipArchiveReader())
        let r = router.reader(for: .cbz)
        #expect(r is ZipArchiveReader)
    }
}
