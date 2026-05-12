import Foundation
import SwiftData
import Domain

public actor ProgressRepositoryLive: ProgressRepository {
    private let stack: SwiftDataStack

    public init(stack: SwiftDataStack) {
        self.stack = stack
    }

    private func ctx() -> ModelContext { ModelContext(stack.container) }

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
