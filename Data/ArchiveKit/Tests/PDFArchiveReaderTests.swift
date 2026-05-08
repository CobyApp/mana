import Testing
import Foundation
@testable import ArchiveKit
import Domain

@Suite struct PDFArchiveReaderTests {
    private final class BundleAnchor {}

    private func fixtureURL() throws -> URL {
        let url = Bundle(for: BundleAnchor.self).url(forResource: "sample", withExtension: "pdf")
        try #require(url != nil)
        return url!
    }

    @Test func opensPdfAndReportsThreePages() async throws {
        let reader = PDFArchiveReader()
        let handle = try await reader.openArchive(at: fixtureURL())
        #expect(await reader.pageCount(handle) == 3)
        await reader.closeArchive(handle)
    }

    @Test func readsPageAsPNGData() async throws {
        let reader = PDFArchiveReader()
        let handle = try await reader.openArchive(at: fixtureURL())
        let data = try await reader.pageData(handle, index: 0)
        // First bytes of PNG: 0x89 0x50 0x4E 0x47
        #expect(data.prefix(4) == Data([0x89, 0x50, 0x4E, 0x47]))
        await reader.closeArchive(handle)
    }

    @Test func indexOutOfBoundsThrows() async throws {
        let reader = PDFArchiveReader()
        let handle = try await reader.openArchive(at: fixtureURL())
        await #expect(throws: ArchiveError.indexOutOfBounds(99)) {
            _ = try await reader.pageData(handle, index: 99)
        }
        await reader.closeArchive(handle)
    }
}
