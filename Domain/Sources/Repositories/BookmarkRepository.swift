import Foundation

public protocol BookmarkRepository: Sendable {
    func bookmarks(comicId: UUID) async -> [Bookmark]
    func add(_ bookmark: Bookmark) async throws
    func remove(id: UUID) async throws
}
