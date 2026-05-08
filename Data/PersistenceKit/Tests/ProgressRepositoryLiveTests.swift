import Testing
import Foundation
@testable import PersistenceKit
import Domain

@Suite struct ProgressRepositoryLiveTests {

    @Test func saveAndLoad() async throws {
        let stack = try SwiftDataStack.inMemory()
        let repo = ProgressRepositoryLive(stack: stack)
        let progress = ReadingProgress(comicId: UUID(), lastPageIndex: 7, totalPages: 30, updatedAt: Date(timeIntervalSince1970: 100))
        try await repo.save(progress)
        let loaded = await repo.load(comicId: progress.comicId)
        #expect(loaded == progress)
    }

    @Test func saveOverwrites() async throws {
        let stack = try SwiftDataStack.inMemory()
        let repo = ProgressRepositoryLive(stack: stack)
        let id = UUID()
        try await repo.save(ReadingProgress(comicId: id, lastPageIndex: 1, totalPages: 10, updatedAt: .init(timeIntervalSince1970: 1)))
        try await repo.save(ReadingProgress(comicId: id, lastPageIndex: 5, totalPages: 10, updatedAt: .init(timeIntervalSince1970: 2)))
        let loaded = await repo.load(comicId: id)
        #expect(loaded?.lastPageIndex == 5)
    }
}
