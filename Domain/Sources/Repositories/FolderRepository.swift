import Foundation

public protocol FolderRepository: Sendable {
    func all() async -> [Folder]
    func upsert(_ folder: Folder) async throws
    /// Deletes the folder. Implementations must not delete the comics inside; they go back to root.
    func delete(_ id: UUID) async throws
    /// Sets (or with nil clears) the folder's custom cover image.
    func setCover(folderId: UUID, image: Data?) async throws
}

public extension FolderRepository {
    /// Default: read-modify-write through `upsert`, so existing mocks/no-ops keep compiling.
    func setCover(folderId: UUID, image: Data?) async throws {
        guard let folder = await all().first(where: { $0.id == folderId }) else { return }
        try await upsert(folder.withCover(image))
    }
}
