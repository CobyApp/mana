import Testing
import Foundation
@testable import CloudSyncKit

@Suite struct BookmarkURLResolverTests {

    @Test func encodesAndResolvesLocalFile() throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: "br-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appending(path: "test.txt")
        try Data("hello".utf8).write(to: file)

        let bookmark = try BookmarkURLResolver.bookmarkData(for: file)
        #expect(!bookmark.isEmpty)

        let (resolved, isStale) = try BookmarkURLResolver.resolve(bookmarkData: bookmark)
        #expect(isStale == false)
        #expect(resolved.standardizedFileURL == file.standardizedFileURL)

        try? FileManager.default.removeItem(at: dir)
    }

    @Test func resolvingGarbageThrows() {
        let garbage = Data([0x00, 0x01, 0x02])
        #expect(throws: (any Error).self) {
            _ = try BookmarkURLResolver.resolve(bookmarkData: garbage)
        }
    }
}
