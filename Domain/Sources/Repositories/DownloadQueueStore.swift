import Foundation

/// Durable record of pending chapter downloads (queued + running). Entries are added on enqueue and
/// removed only when a download reaches a terminal state (done, cancelled, or failed), so whatever
/// remains on next launch is exactly what was interrupted and should resume.
public protocol DownloadQueueStore: Sendable {
    func add(_ download: PersistedDownload) async
    func remove(chapterURL: String) async
    func clear() async
    /// Pending downloads in enqueue order, for resuming after a restart.
    func all() async -> [PersistedDownload]
}
