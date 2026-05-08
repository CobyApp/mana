import Testing
import Foundation
@testable import ArchiveKit
import Domain

// The fixture "sample.cbr" is "Test Archive.rar" from UnrarKit's MIT-licensed test data.
// It contains three files: "Test File A.txt", "Test File B.jpg", "Test File C.m4a".
// RarArchiveReader filters to image extensions, so only "Test File B.jpg" is exposed → pageCount == 1.

@Suite struct RarArchiveReaderTests {
    private final class BundleAnchor {}

    private func fixtureURL() throws -> URL {
        let url = Bundle(for: BundleAnchor.self).url(forResource: "sample", withExtension: "cbr")
        try #require(url != nil)
        return url!
    }

    @Test func opensCbrAndReportsOneImagePage() async throws {
        let reader = RarArchiveReader()
        let handle = try await reader.openArchive(at: fixtureURL())
        let count = await reader.pageCount(handle)
        // Archive contains 3 entries total; only "Test File B.jpg" passes the image filter.
        #expect(count == 1)
        await reader.closeArchive(handle)
    }

    @Test func readsFirstPageData() async throws {
        let reader = RarArchiveReader()
        let handle = try await reader.openArchive(at: fixtureURL())
        let data = try await reader.pageData(handle, index: 0)
        #expect(data.count > 0)
        await reader.closeArchive(handle)
    }

    @Test func indexOutOfBoundsThrows() async throws {
        let reader = RarArchiveReader()
        let handle = try await reader.openArchive(at: fixtureURL())
        await #expect(throws: ArchiveError.indexOutOfBounds(99999)) {
            _ = try await reader.pageData(handle, index: 99999)
        }
        await reader.closeArchive(handle)
    }
}
