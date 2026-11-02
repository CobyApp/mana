import Foundation
import SwiftData
import Domain

public actor FolderRepositoryLive: FolderRepository {
    private let stack: SwiftDataStack

    public init(stack: SwiftDataStack) {
        self.stack = stack
    }

    private func ctx() -> ModelContext { ModelContext(stack.container) }

    public func all() async -> [Folder] {
        let context = ctx()
        let descriptor = FetchDescriptor<FolderEntity>(sortBy: [SortDescriptor(\.dateAdded, order: .reverse)])
        return ((try? context.fetch(descriptor)) ?? []).map { $0.toModel() }
    }

    public func upsert(_ folder: Folder) async throws {
        let context = ctx()
        let id = folder.id
        let descriptor = FetchDescriptor<FolderEntity>(predicate: #Predicate { $0.id == id })
        if let existing = try context.fetch(descriptor).first {
            existing.name = folder.name
            existing.dateAdded = folder.dateAdded
            existing.sourceURL = folder.sourceURL
            existing.coverImage = folder.coverImage
        } else {
            context.insert(FolderEntity.from(folder))
        }
        try context.save()
    }

    /// Deletes the folder only: its comics are detached back to the library root (Android
    /// `FolderRepositoryImpl.delete` → `detachComics` + `deleteById`).
    public func delete(_ id: UUID) async throws {
        let context = ctx()
        let optionalId: UUID? = id
        let comics = FetchDescriptor<ComicEntity>(predicate: #Predicate { $0.folderId == optionalId })
        for comic in try context.fetch(comics) {
            comic.folderId = nil
        }
        let descriptor = FetchDescriptor<FolderEntity>(predicate: #Predicate { $0.id == id })
        for entity in try context.fetch(descriptor) {
            context.delete(entity)
        }
        try context.save()
    }

    public func setCover(folderId: UUID, image: Data?) async throws {
        let context = ctx()
        let descriptor = FetchDescriptor<FolderEntity>(predicate: #Predicate { $0.id == folderId })
        guard let entity = try context.fetch(descriptor).first else { return }
        entity.coverImage = image
        try context.save()
    }
}
