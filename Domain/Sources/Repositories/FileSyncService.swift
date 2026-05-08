import Foundation

public enum FileSyncEvent: Sendable, Equatable {
    case added(URL)
    case removed(URL)
    case updated(URL)
}

public enum SyncError: Error, Equatable, Sendable {
    case iCloudUnavailable
    case quotaExceeded
    case downloadFailed(reason: String)
}

public protocol FileSyncService: Sendable {
    var isAvailable: Bool { get async }
    func ingest(localURL: URL) async throws -> URL
    func ensureLocal(url: URL) async throws
    func observeChanges() -> AsyncStream<FileSyncEvent>
}
