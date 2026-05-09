import Foundation

public protocol LibraryResetService: Sendable {
    /// Wipes all comics, folders, bookmarks, progress, and on-disk files.
    /// Idempotent — safe to call when nothing exists.
    func resetAll() async throws
}
