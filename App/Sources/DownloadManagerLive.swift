import Foundation
import Domain

/// App-scoped, sequential download queue. Survives leaving the detail screen, exposes the live
/// queue (running first, then queued) as an `AsyncStream`, and persists the pending queue so an
/// interrupted run resumes on next launch. Ported from Android `DefaultDownloadManager` (one worker
/// instead of three). Completed chapters leave the list — the library folder then reflects
/// "downloaded".
public final class DownloadManagerLive: DownloadManager, @unchecked Sendable {
    private struct Request: Sendable {
        let url: String
        let seriesURL: String
        let series: String
        let chapter: String
        let cover: String?
    }

    private let downloader: any ChapterDownloader
    private let store: any DownloadQueueStore
    private let notifier: DownloadNotifier

    private let lock = NSLock()
    private var order: [String] = []
    private var entries: [String: DownloadEntry] = [:]
    private var requests: [String: Request] = [:]
    private var cancelled: Set<String> = []
    private var runningURL: String?
    private var runningTask: Task<Void, Error>?
    private var workerRunning = false
    private var isPaused = false
    private var pendingRecords: [PersistedDownload] = []
    private var pendingEntries: [DownloadEntry] = []

    private var activeContinuations: [UUID: AsyncStream<[DownloadEntry]>.Continuation] = [:]
    private var pausedContinuations: [UUID: AsyncStream<Bool>.Continuation] = [:]

    public init(downloader: any ChapterDownloader, store: any DownloadQueueStore, notifier: DownloadNotifier) {
        self.downloader = downloader
        self.store = store
        self.notifier = notifier
    }

    // MARK: Snapshots / streams

    public var active: [DownloadEntry] {
        lock.lock(); defer { lock.unlock() }
        return snapshotLocked()
    }

    public var pendingResume: [DownloadEntry] {
        lock.lock(); defer { lock.unlock() }
        return pendingEntries
    }

    public var paused: Bool {
        lock.lock(); defer { lock.unlock() }
        return isPaused
    }

    public func activeStream() -> AsyncStream<[DownloadEntry]> {
        AsyncStream { continuation in
            let id = UUID()
            lock.lock()
            activeContinuations[id] = continuation
            continuation.yield(snapshotLocked())
            lock.unlock()
            continuation.onTermination = { [weak self] _ in
                self?.removeActiveContinuation(id)
            }
        }
    }

    public func pausedStream() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            let id = UUID()
            lock.lock()
            pausedContinuations[id] = continuation
            continuation.yield(isPaused)
            lock.unlock()
            continuation.onTermination = { [weak self] _ in
                self?.removePausedContinuation(id)
            }
        }
    }

    private func removeActiveContinuation(_ id: UUID) { lock.lock(); activeContinuations[id] = nil; lock.unlock() }
    private func removePausedContinuation(_ id: UUID) { lock.lock(); pausedContinuations[id] = nil; lock.unlock() }

    /// Scoped lock usable from async methods (the lock/unlock happen in this non-async frame).
    private func withLockSync<T>(_ body: () -> T) -> T {
        lock.lock(); defer { lock.unlock() }; return body()
    }

    private func snapshotLocked() -> [DownloadEntry] {
        let all = order.compactMap { entries[$0] }
        return all.filter { isRunning($0.status) } + all.filter { !isRunning($0.status) }
    }

    private func isRunning(_ s: ChapterDownloadStatus) -> Bool {
        if case .running = s { return true }; return false
    }

    private func emitActive() {
        lock.lock()
        let snap = snapshotLocked()
        let conts = Array(activeContinuations.values)
        lock.unlock()
        for c in conts { c.yield(snap) }
    }

    private func emitPaused() {
        lock.lock()
        let value = isPaused
        let conts = Array(pausedContinuations.values)
        lock.unlock()
        for c in conts { c.yield(value) }
    }

    // MARK: Queue control

    public func pause() { lock.lock(); isPaused = true; lock.unlock(); emitPaused() }
    public func resume() { lock.lock(); isPaused = false; lock.unlock(); emitPaused() }

    public func enqueue(chapterURL: String, seriesURL: String, seriesTitle: String, chapterName: String, seriesCoverURL: String?) {
        enqueueInternal(chapterURL: chapterURL, seriesURL: seriesURL, seriesTitle: seriesTitle,
                        chapterName: chapterName, seriesCoverURL: seriesCoverURL, persist: true)
    }

    private func enqueueInternal(chapterURL: String, seriesURL: String, seriesTitle: String, chapterName: String, seriesCoverURL: String?, persist: Bool) {
        lock.lock()
        if let status = entries[chapterURL]?.status, isRunning(status) || status == .queued {
            lock.unlock(); return
        }
        cancelled.remove(chapterURL)
        if entries[chapterURL] == nil { order.append(chapterURL) }
        entries[chapterURL] = DownloadEntry(chapterURL: chapterURL, seriesTitle: seriesTitle, chapterName: chapterName, status: .queued)
        requests[chapterURL] = Request(url: chapterURL, seriesURL: seriesURL, series: seriesTitle, chapter: chapterName, cover: seriesCoverURL)
        lock.unlock()
        emitActive()
        if persist {
            let record = PersistedDownload(chapterURL: chapterURL, seriesURL: seriesURL, seriesTitle: seriesTitle,
                                           chapterName: chapterName, seriesCoverURL: seriesCoverURL, enqueuedAt: Date())
            Task { await store.add(record) }
        }
        startWorkerIfNeeded()
    }

    public func cancel(chapterURL: String) {
        lock.lock()
        let isRunningNow = (runningURL == chapterURL)
        let task = runningTask
        entries[chapterURL] = nil
        order.removeAll { $0 == chapterURL }
        requests[chapterURL] = nil
        if !isRunningNow { cancelled.insert(chapterURL) }
        lock.unlock()
        if isRunningNow { task?.cancel() }
        Task { await store.remove(chapterURL: chapterURL) }
        emitActive()
    }

    public func cancelAll() {
        lock.lock()
        let task = runningTask
        for url in order { cancelled.insert(url) }
        order.removeAll()
        entries.removeAll()
        requests.removeAll()
        lock.unlock()
        task?.cancel()
        Task { await store.clear() }
        emitActive()
    }

    // MARK: Resume-after-kill

    public func restore() async {
        let saved = await store.all()
        withLockSync {
            pendingRecords = saved
            pendingEntries = saved.map { DownloadEntry(chapterURL: $0.chapterURL, seriesTitle: $0.seriesTitle, chapterName: $0.chapterName, status: .queued) }
        }
    }

    public func resumePending() {
        lock.lock()
        let toResume = pendingRecords
        pendingRecords = []
        pendingEntries = []
        lock.unlock()
        for d in toResume {
            enqueueInternal(chapterURL: d.chapterURL, seriesURL: d.seriesURL, seriesTitle: d.seriesTitle,
                            chapterName: d.chapterName, seriesCoverURL: d.seriesCoverURL, persist: false)
        }
    }

    public func dismissPending() {
        lock.lock()
        pendingRecords = []
        pendingEntries = []
        lock.unlock()
        Task { await store.clear() }
    }

    // MARK: Worker

    private func startWorkerIfNeeded() {
        lock.lock()
        if workerRunning { lock.unlock(); return }
        workerRunning = true
        lock.unlock()
        Task { await runLoop() }
    }

    private func nextQueued() -> Request? {
        withLockSync {
            for url in order where entries[url]?.status == .queued { return requests[url] }
            return nil
        }
    }

    private func runLoop() async {
        while true {
            // Honour pause between chapters.
            while paused { try? await Task.sleep(nanoseconds: 300_000_000) }
            guard let request = nextQueued() else {
                withLockSync { workerRunning = false }
                return
            }
            await process(request)
        }
    }

    private func process(_ request: Request) async {
        let skip: Bool = withLockSync {
            if cancelled.remove(request.url) != nil {
                entries[request.url] = nil; order.removeAll { $0 == request.url }
                return true
            }
            entries[request.url] = DownloadEntry(chapterURL: request.url, seriesTitle: request.series, chapterName: request.chapter, status: .running(done: 0, total: 0))
            runningURL = request.url
            return false
        }
        if skip {
            emitActive()
            await store.remove(chapterURL: request.url)
            return
        }
        emitActive()

        let task = Task<Void, Error> {
            _ = try await downloader.download(
                chapterURL: request.url, seriesURL: request.seriesURL, seriesTitle: request.series,
                chapterName: request.chapter, seriesCoverURL: request.cover
            ) { [weak self] done, total in
                self?.updateProgress(url: request.url, series: request.series, chapter: request.chapter, done: done, total: total)
            }
        }
        withLockSync { runningTask = task }

        let result = await task.result
        withLockSync {
            runningURL = nil
            runningTask = nil
            let wasCancelled = (entries[request.url] == nil)
            switch result {
            case .success:
                entries[request.url] = nil; order.removeAll { $0 == request.url }
            case .failure(let error):
                if error is CancellationError || wasCancelled {
                    entries[request.url] = nil; order.removeAll { $0 == request.url }
                } else {
                    entries[request.url] = DownloadEntry(chapterURL: request.url, seriesTitle: request.series, chapterName: request.chapter, status: .failed)
                }
            }
        }
        await store.remove(chapterURL: request.url)
        if case .success = result { notifier.notifyCompleted(series: request.series, chapter: request.chapter) }
        emitActive()
    }

    private func updateProgress(url: String, series: String, chapter: String, done: Int, total: Int) {
        let changed: Bool = withLockSync {
            guard entries[url] != nil else { return false }
            entries[url] = DownloadEntry(chapterURL: url, seriesTitle: series, chapterName: chapter, status: .running(done: done, total: total))
            return true
        }
        if changed { emitActive() }
    }
}
