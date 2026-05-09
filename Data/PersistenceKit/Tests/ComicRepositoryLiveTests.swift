import Testing
import Foundation
import SwiftData
@testable import PersistenceKit
import Domain

@Suite struct ComicRepositoryLiveTests {

    private func makeStack() throws -> SwiftDataStack {
        try SwiftDataStack.inMemory()
    }

    @Test func upsertAndAll() async throws {
        let stack = try makeStack()
        let repo = ComicRepositoryLive(stack: stack)
        let item = ComicItem(
            id: UUID(),
            url: URL(fileURLWithPath: "/tmp/a.cbz"),
            format: .cbz,
            title: "A",
            pageCount: 10,
            coverThumbnail: nil,
            dateAdded: Date(timeIntervalSince1970: 0),
            fileSizeBytes: 1
        )
        try await repo.upsert(item)
        let all = await repo.all()
        #expect(all.count == 1)
        #expect(all.first?.title == "A")
    }

    @Test func upsertOverwritesById() async throws {
        let stack = try makeStack()
        let repo = ComicRepositoryLive(stack: stack)
        let id = UUID()
        let v1 = ComicItem(id: id, url: URL(fileURLWithPath: "/tmp/a.cbz"), format: .cbz, title: "A", pageCount: 1, coverThumbnail: nil, dateAdded: .init(timeIntervalSince1970: 0), fileSizeBytes: 1)
        let v2 = ComicItem(id: id, url: URL(fileURLWithPath: "/tmp/a.cbz"), format: .cbz, title: "A2", pageCount: 1, coverThumbnail: nil, dateAdded: .init(timeIntervalSince1970: 0), fileSizeBytes: 1)
        try await repo.upsert(v1)
        try await repo.upsert(v2)
        let all = await repo.all()
        #expect(all.count == 1)
        #expect(all.first?.title == "A2")
    }

    @Test func deleteById() async throws {
        let stack = try makeStack()
        let repo = ComicRepositoryLive(stack: stack)
        let item = ComicItem(id: UUID(), url: URL(fileURLWithPath: "/tmp/x"), format: .cbz, title: "X", pageCount: nil, coverThumbnail: nil, dateAdded: .init(timeIntervalSince1970: 0), fileSizeBytes: 0)
        try await repo.upsert(item)
        try await repo.delete(item.id)
        let all = await repo.all()
        #expect(all.isEmpty)
    }

    @Test func roundTripsReadingMode() async throws {
        let stack = try makeStack()
        let repo = ComicRepositoryLive(stack: stack)
        let id = UUID()
        let item = ComicItem(
            id: id,
            url: URL(fileURLWithPath: "/tmp/y.cbz"),
            format: .cbz,
            title: "Y",
            pageCount: 5,
            coverThumbnail: nil,
            dateAdded: .init(timeIntervalSince1970: 0),
            fileSizeBytes: 1,
            readingMode: .scroll(direction: .rtl)
        )
        try await repo.upsert(item)
        let loaded = await repo.all()
        #expect(loaded.first?.readingMode == .scroll(direction: .rtl))
    }

    @Test func updatesReadingModeOnSecondUpsert() async throws {
        let stack = try makeStack()
        let repo = ComicRepositoryLive(stack: stack)
        let id = UUID()
        let v1 = ComicItem(id: id, url: URL(fileURLWithPath: "/tmp/z.cbz"), format: .cbz, title: "Z",
                           pageCount: 5, coverThumbnail: nil, dateAdded: .init(timeIntervalSince1970: 0),
                           fileSizeBytes: 1, readingMode: .single)
        try await repo.upsert(v1)
        let v2 = ComicItem(id: id, url: v1.url, format: .cbz, title: "Z",
                           pageCount: 5, coverThumbnail: nil, dateAdded: v1.dateAdded,
                           fileSizeBytes: 1, readingMode: .dual)
        try await repo.upsert(v2)
        let loaded = await repo.all()
        #expect(loaded.first?.readingMode == .dual)
    }

    @Test func roundTripsBookmarkData() async throws {
        let stack = try makeStack()
        let repo = ComicRepositoryLive(stack: stack)
        let id = UUID()
        let bookmark = Data([0x42, 0x43, 0x44])
        let item = ComicItem(
            id: id,
            url: URL(fileURLWithPath: "/tmp/q.cbz"),
            format: .cbz,
            title: "Q",
            pageCount: 5,
            coverThumbnail: nil,
            dateAdded: .init(timeIntervalSince1970: 0),
            fileSizeBytes: 1,
            readingMode: nil,
            urlBookmarkData: bookmark
        )
        try await repo.upsert(item)
        let loaded = await repo.all()
        #expect(loaded.first?.urlBookmarkData == bookmark)
    }
}
