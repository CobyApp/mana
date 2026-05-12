import Foundation
import SwiftData
import Domain

public actor ProgressRepositoryLive: ProgressRepository {
    private let stack: SwiftDataStack
    private var _context: ModelContext?

    public init(stack: SwiftDataStack) {
        self.stack = stack
    }

    /// Reuse a single ModelContext per actor so writes are immediately
    /// visible to subsequent reads. Building a fresh context each call was
    /// allowing the new context to load a stale snapshot in some cases —
    /// the library would fetch right after the reader saved and still see
    /// the pre-save state.
    private func ctx() -> ModelContext {
        if let _context { return _context }
        let context = ModelContext(stack.container)
        _context = context
        return context
    }

    public func all() async -> [ReadingProgress] {
        let context = ctx()
        let descriptor = FetchDescriptor<ReadingProgressEntity>()
        return ((try? context.fetch(descriptor)) ?? []).map { $0.toModel() }
    }

    public func load(comicId: UUID) async -> ReadingProgress? {
        let context = ctx()
        let descriptor = FetchDescriptor<ReadingProgressEntity>(predicate: #Predicate { $0.comicId == comicId })
        return (try? context.fetch(descriptor))?.first?.toModel()
    }

    public func save(_ progress: ReadingProgress) async throws {
        let context = ctx()
        let id = progress.comicId
        let descriptor = FetchDescriptor<ReadingProgressEntity>(predicate: #Predicate { $0.comicId == id })
        if let existing = try context.fetch(descriptor).first {
            existing.lastPageIndex = progress.lastPageIndex
            existing.totalPages = progress.totalPages
            existing.updatedAt = progress.updatedAt
        } else {
            context.insert(ReadingProgressEntity(
                comicId: progress.comicId,
                lastPageIndex: progress.lastPageIndex,
                totalPages: progress.totalPages,
                updatedAt: progress.updatedAt
            ))
        }
        try context.save()
    }
}
