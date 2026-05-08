import Foundation
import SwiftData
import Domain

public actor BookmarkRepositoryLive: BookmarkRepository {
    private let stack: SwiftDataStack

    public init(stack: SwiftDataStack) {
        self.stack = stack
    }

    private func ctx() -> ModelContext { ModelContext(stack.container) }

    public func bookmarks(comicId: UUID) async -> [Bookmark] {
        let context = ctx()
        let descriptor = FetchDescriptor<BookmarkEntity>(
            predicate: #Predicate { $0.comicId == comicId },
            sortBy: [SortDescriptor(\.pageIndex)]
        )
        return ((try? context.fetch(descriptor)) ?? []).map { $0.toModel() }
    }

    public func add(_ bookmark: Bookmark) async throws {
        let context = ctx()
        context.insert(BookmarkEntity(
            id: bookmark.id,
            comicId: bookmark.comicId,
            pageIndex: bookmark.pageIndex,
            note: bookmark.note,
            createdAt: bookmark.createdAt
        ))
        try context.save()
    }

    public func remove(id: UUID) async throws {
        let context = ctx()
        let descriptor = FetchDescriptor<BookmarkEntity>(predicate: #Predicate { $0.id == id })
        for entity in try context.fetch(descriptor) {
            context.delete(entity)
        }
        try context.save()
    }
}
