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

    @Test func deleteDetachesComicsToRoot() async throws {
        let stack = try SwiftDataStack.inMemory()
        let repo = FolderRepositoryLive(stack: stack)
        let comics = ComicRepositoryLive(stack: stack)
        let folder = Folder(id: UUID(), name: "X", dateAdded: .init(timeIntervalSince1970: 0))
        try await repo.upsert(folder)
        let comic = ComicItem(id: UUID(), url: URL(fileURLWithPath: "/tmp/x.cbz"), format: .cbz, title: "C",
                              pageCount: 1, coverThumbnail: nil, dateAdded: .init(timeIntervalSince1970: 0),
                              fileSizeBytes: 0, folderId: folder.id)
        try await comics.upsert(comic)
        try await repo.delete(folder.id)
        let stored = await comics.all()
        #expect(stored.count == 1)
        #expect(stored.first?.folderId == nil)
    }

    @Test func coverRoundTripsAndSurvivesRename() async throws {
        let stack = try SwiftDataStack.inMemory()
        let repo = FolderRepositoryLive(stack: stack)
        let folder = Folder(id: UUID(), name: "X", dateAdded: .init(timeIntervalSince1970: 0), sourceURL: "s")
        try await repo.upsert(folder)
        try await repo.setCover(folderId: folder.id, image: Data([9, 8, 7]))
        let withCover = try #require(await repo.all().first)
        #expect(withCover.coverImage == Data([9, 8, 7]))
        try await repo.upsert(withCover.renamed("Y"))
        let renamed = try #require(await repo.all().first)
        #expect(renamed.name == "Y")
        #expect(renamed.sourceURL == "s")
        #expect(renamed.coverImage == Data([9, 8, 7]))
        try await repo.setCover(folderId: folder.id, image: nil)
        #expect(await repo.all().first?.coverImage == nil)
    }
}
