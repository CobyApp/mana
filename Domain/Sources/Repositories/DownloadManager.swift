import Foundation

/// App-scoped download coordinator: queues chapter downloads, runs them one at a time so they
/// survive leaving the detail screen, drives a completion notification, and exposes the live queue
/// (running first, then queued) for the downloads screen.
///
/// The live queue and paused flag are exposed as `AsyncStream`s plus a synchronous snapshot so the
/// TCA reducer can both read the current value and observe changes.
public protocol DownloadManager: Sendable {
    /// The current queue snapshot (running first, then queued).
    var active: [DownloadEntry] { get }
    /// A stream of queue snapshots, emitting the current value immediately on subscribe.
    func activeStream() -> AsyncStream<[DownloadEntry]>

    /// Downloads left pending by a previous process (interrupted by an app kill), surfaced for a
    /// "resume downloads?" prompt. Populated by `restore()`; cleared by `resumePending()`/`dismissPending()`.
    var pendingResume: [DownloadEntry] { get }

    func enqueue(
        chapterURL: String,
        seriesURL: String,
        seriesTitle: String,
        chapterName: String,
        seriesCoverURL: String?
    )

    /// Load interrupted downloads from storage into `pendingResume` (call once at launch). Does
    /// NOT start them — the UI asks the user first.
    func restore() async

    /// Start the interrupted downloads from `pendingResume` and clear the prompt.
    func resumePending()

    /// Discard the interrupted downloads without starting them.
    func dismissPending()

    /// Whether the queue is paused: the running chapter finishes, then the queue halts.
    var paused: Bool { get }
    func pausedStream() -> AsyncStream<Bool>

    /// Temporarily halt the queue after the current chapter; queued items wait.
    func pause()

    /// Resume a paused queue.
    func resume()

    /// Cancel a queued or in-flight download.
    func cancel(chapterURL: String)

    /// Cancel everything queued and in-flight.
    func cancelAll()
}
