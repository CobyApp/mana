import Testing
import Foundation
@testable import PersistenceKit
import Domain

@Suite struct BookmarkRepositoryLiveTests {

    @Test func addingSamePageTwiceUpdatesInPlace() async throws {
        let stack = try SwiftDataStack.inMemory()
        let repo = BookmarkRepositoryLive(stack: stack)
        let comicId = UUID()
        try await repo.add(Bookmark(id: UUID(), comicId: comicId, pageIndex: 5, note: "first", createdAt: .init(timeIntervalSince1970: 0)))
        try await repo.add(Bookmark(id: UUID(), comicId: comicId, pageIndex: 5, note: "second", createdAt: .init(timeIntervalSince1970: 1)))

        let all = await repo.bookmarks(comicId: comicId)
        #expect(all.count == 1)
        #expect(all.first?.note == "second")
    }

    @Test func differentPagesCoexist() async throws {
        let stack = try SwiftDataStack.inMemory()
        let repo = BookmarkRepositoryLive(stack: stack)
        let comicId = UUID()
        try await repo.add(Bookmark(id: UUID(), comicId: comicId, pageIndex: 1, note: nil, createdAt: .init(timeIntervalSince1970: 0)))
        try await repo.add(Bookmark(id: UUID(), comicId: comicId, pageIndex: 2, note: nil, createdAt: .init(timeIntervalSince1970: 0)))

        let all = await repo.bookmarks(comicId: comicId)
        #expect(all.count == 2)
    }
}
