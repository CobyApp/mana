import Testing
import Foundation
@testable import CloudSyncKit
import Domain

@Suite struct FileSyncServiceLiveTests {

    private func makeFakeContainer() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appending(path: "ubi-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test func ingestCopiesFileIntoContainer() async throws {
        let container = try makeFakeContainer()
        let service = FileSyncServiceLive(containerURLProvider: { container })

        let source = FileManager.default.temporaryDirectory.appending(path: "src-\(UUID()).cbz")
        try Data("zip-bytes".utf8).write(to: source)

        let dest = try await service.ingest(localURL: source)

        #expect(dest.deletingLastPathComponent().standardizedFileURL == container.standardizedFileURL)
        #expect(dest.lastPathComponent == source.lastPathComponent)
        #expect(FileManager.default.fileExists(atPath: dest.path))

        try? FileManager.default.removeItem(at: container)
        try? FileManager.default.removeItem(at: source)
    }

    @Test func ingestRenamesOnConflict() async throws {
        let container = try makeFakeContainer()
        let service = FileSyncServiceLive(containerURLProvider: { container })

        let existing = container.appending(path: "book.cbz")
        try Data("v1".utf8).write(to: existing)

        let source = FileManager.default.temporaryDirectory.appending(path: "book.cbz")
        try? FileManager.default.removeItem(at: source)
        try Data("v2".utf8).write(to: source)

        let dest = try await service.ingest(localURL: source)

        #expect(dest.lastPathComponent != "book.cbz")
        #expect(dest.lastPathComponent.hasPrefix("book"))
        #expect(dest.lastPathComponent.hasSuffix(".cbz"))

        try? FileManager.default.removeItem(at: container)
        try? FileManager.default.removeItem(at: source)
    }

    @Test func unavailableServiceThrowsOnIngest() async throws {
        let service = FileSyncServiceLive(containerURLProvider: { nil })
        let source = FileManager.default.temporaryDirectory.appending(path: "x.cbz")
        try? Data("x".utf8).write(to: source)
        await #expect(throws: SyncError.iCloudUnavailable) {
            _ = try await service.ingest(localURL: source)
        }
        try? FileManager.default.removeItem(at: source)
    }

    @Test func ensureLocalNoOpsForLocalFile() async throws {
        let container = try makeFakeContainer()
        let service = FileSyncServiceLive(containerURLProvider: { container })

        let file = container.appending(path: "local.cbz")
        try Data("ok".utf8).write(to: file)

        try await service.ensureLocal(url: file)
        #expect(FileManager.default.fileExists(atPath: file.path))

        try? FileManager.default.removeItem(at: container)
    }
}
