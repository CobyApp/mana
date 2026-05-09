import Testing
import Foundation
@testable import PersistenceKit
import Domain

@Suite struct FolderRepositoryLiveTests {

    @Test func upsertAndAll() async throws {
        let stack = try SwiftDataStack.inMemory()
        let repo = FolderRepositoryLive(stack: stack)
        let folder = Folder(id: UUID(), name: "Manga", dateAdded: Date(timeIntervalSince1970: 0))
        try await repo.upsert(folder)
        let all = await repo.all()
        #expect(all.count == 1)
        #expect(all.first?.name == "Manga")
    }

    @Test func upsertOverwritesById() async throws {
        let stack = try SwiftDataStack.inMemory()
        let repo = FolderRepositoryLive(stack: stack)
        let id = UUID()
        try await repo.upsert(Folder(id: id, name: "A", dateAdded: .init(timeIntervalSince1970: 0)))
        try await repo.upsert(Folder(id: id, name: "B", dateAdded: .init(timeIntervalSince1970: 0)))
        let all = await repo.all()
        #expect(all.count == 1)
        #expect(all.first?.name == "B")
    }

    @Test func deleteById() async throws {
        let stack = try SwiftDataStack.inMemory()
        let repo = FolderRepositoryLive(stack: stack)
        let folder = Folder(id: UUID(), name: "X", dateAdded: .init(timeIntervalSince1970: 0))
        try await repo.upsert(folder)
        try await repo.delete(folder.id)
        let all = await repo.all()
        #expect(all.isEmpty)
    }
}
