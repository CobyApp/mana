import Testing
import Foundation
import ComposableArchitecture
@testable import BookmarksFeature
import Domain

@MainActor
@Suite struct BookmarksFeatureTests {

    @Test func taskLoadsBookmarks() async {
        let comicId = UUID()
        let bm = Bookmark(id: UUID(), comicId: comicId, pageIndex: 4, note: "good", createdAt: .init(timeIntervalSince1970: 0))
        let repo = StubBookmarkRepo(initial: [bm])

        let store = await TestStore(initialState: BookmarksFeature.State(comicId: comicId)) {
            BookmarksFeature()
        } withDependencies: {
            $0.bookmarkRepository = repo
        }

        await store.send(.task)
        await store.receive(\.refreshed) {
            $0.bookmarks = IdentifiedArray(uniqueElements: [bm])
        }
    }

    @Test func addRequestedInsertsBookmark() async {
        let comicId = UUID()
        let repo = StubBookmarkRepo(initial: [])
        let fixedDate = Date(timeIntervalSince1970: 100)
        let fixedUUID = UUID()

        let store = await TestStore(initialState: BookmarksFeature.State(comicId: comicId)) {
            BookmarksFeature()
        } withDependencies: {
            $0.bookmarkRepository = repo
            $0.uuid = .constant(fixedUUID)
            $0.date.now = fixedDate
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        let expected = Bookmark(id: fixedUUID, comicId: comicId, pageIndex: 7, note: "bm1", createdAt: fixedDate)

        await store.send(.addRequested(pageIndex: 7, note: "bm1")) {
            $0.bookmarks.append(expected)
        }
    }
}

actor StubBookmarkRepo: BookmarkRepository {
    private var items: [Bookmark]
    init(initial: [Bookmark]) { self.items = initial }
    func bookmarks(comicId: UUID) async -> [Bookmark] {
        items.filter { $0.comicId == comicId }.sorted { $0.pageIndex < $1.pageIndex }
    }
    func add(_ b: Bookmark) async throws { items.append(b) }
    func remove(id: UUID) async throws { items.removeAll { $0.id == id } }
}
