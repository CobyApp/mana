import Foundation
import SwiftData
import Domain

public actor ComicRepositoryLive: ComicRepository {
    private let stack: SwiftDataStack

    public init(stack: SwiftDataStack) {
        self.stack = stack
    }

    private func ctx() -> ModelContext { ModelContext(stack.container) }

    public func all() async -> [ComicItem] {
        let context = ctx()
        let descriptor = FetchDescriptor<ComicEntity>(sortBy: [SortDescriptor(\.dateAdded, order: .reverse)])
        let results = (try? context.fetch(descriptor)) ?? []
        return results.map { $0.toModel() }
    }

    public func comic(id: UUID) async -> ComicItem? {
        let context = ctx()
        let descriptor = FetchDescriptor<ComicEntity>(predicate: #Predicate { $0.id == id })
        let results = (try? context.fetch(descriptor)) ?? []
        return results.first?.toModel()
    }

    public func upsert(_ item: ComicItem) async throws {
        let context = ctx()
        let id = item.id
        let descriptor = FetchDescriptor<ComicEntity>(predicate: #Predicate { $0.id == id })
        if let existing = try context.fetch(descriptor).first {
            existing.urlString = item.url.absoluteString
            existing.formatRaw = item.format.rawValue
            existing.title = item.title
            existing.pageCount = item.pageCount
            existing.coverThumbnail = item.coverThumbnail
            existing.dateAdded = item.dateAdded
            existing.fileSizeBytes = item.fileSizeBytes
        } else {
            context.insert(ComicEntity.from(item))
        }
        try context.save()
    }

    public func delete(_ id: UUID) async throws {
        let context = ctx()
        let descriptor = FetchDescriptor<ComicEntity>(predicate: #Predicate { $0.id == id })
        for entity in try context.fetch(descriptor) {
            context.delete(entity)
        }
        try context.save()
    }
}
