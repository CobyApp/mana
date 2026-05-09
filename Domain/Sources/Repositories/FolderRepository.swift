import Foundation

public protocol FolderRepository: Sendable {
    func all() async -> [Folder]
    func upsert(_ folder: Folder) async throws
    func delete(_ id: UUID) async throws
}
