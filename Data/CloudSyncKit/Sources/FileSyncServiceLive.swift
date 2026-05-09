import Foundation
import ComposableArchitecture
import Domain

public actor FileSyncServiceLive: FileSyncService {

    private let containerURL: URL?
    private let _isAvailable: Bool
    private var continuations: [UUID: AsyncStream<FileSyncEvent>.Continuation] = [:]
    private var metadataQuery: NSMetadataQuery?

    public init(containerURL: URL?, isAvailable: Bool) {
        self.containerURL = containerURL
        self._isAvailable = isAvailable && containerURL != nil
    }

    public var isAvailable: Bool { _isAvailable }

    public func ingest(localURL: URL) async throws -> URL {
        guard _isAvailable, let container = containerURL else {
            throw SyncError.iCloudUnavailable
        }
        let fm = FileManager.default
        let target = uniqueDestination(for: localURL.lastPathComponent, in: container)
        do {
            try fm.copyItem(at: localURL, to: target)
            return target
        } catch {
            throw SyncError.downloadFailed(reason: error.localizedDescription)
        }
    }

    public func ensureLocal(url: URL) async throws {
        guard _isAvailable else { throw SyncError.iCloudUnavailable }
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path) {
            return
        }
        do {
            try fm.startDownloadingUbiquitousItem(at: url)
        } catch {
            throw SyncError.downloadFailed(reason: error.localizedDescription)
        }
        for _ in 0..<60 {
            try? await Task.sleep(nanoseconds: 500_000_000)
            let resourceValues = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
            if resourceValues?.ubiquitousItemDownloadingStatus == .current { return }
            if fm.fileExists(atPath: url.path) { return }
        }
        throw SyncError.downloadFailed(reason: "timeout")
    }

    public nonisolated func observeChanges() -> AsyncStream<FileSyncEvent> {
        AsyncStream { continuation in
            Task { await self.startObservation(continuation: continuation) }
        }
    }

    private func startObservation(continuation: AsyncStream<FileSyncEvent>.Continuation) {
        let id = UUID()
        continuations[id] = continuation
        if metadataQuery == nil, _isAvailable {
            startMetadataQuery()
        }
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeContinuation(id: id) }
        }
    }

    private func removeContinuation(id: UUID) {
        continuations.removeValue(forKey: id)
        if continuations.isEmpty {
            stopMetadataQuery()
        }
    }

    private func startMetadataQuery() {
        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(format: "%K LIKE %@", NSMetadataItemFSNameKey, "*")

        let center = NotificationCenter.default
        center.addObserver(forName: .NSMetadataQueryDidUpdate, object: query, queue: .main) { [weak self] note in
            Task { await self?.handleQueryUpdate(note) }
        }
        center.addObserver(forName: .NSMetadataQueryDidFinishGathering, object: query, queue: .main) { [weak self] note in
            Task { await self?.handleQueryUpdate(note) }
        }
        query.start()
        metadataQuery = query
    }

    private func stopMetadataQuery() {
        metadataQuery?.stop()
        metadataQuery = nil
        NotificationCenter.default.removeObserver(self)
    }

    private func handleQueryUpdate(_ notification: Notification) {
        guard let query = notification.object as? NSMetadataQuery else { return }
        query.disableUpdates()
        defer { query.enableUpdates() }

        let added = (notification.userInfo?[NSMetadataQueryUpdateAddedItemsKey] as? [NSMetadataItem]) ?? []
        let removed = (notification.userInfo?[NSMetadataQueryUpdateRemovedItemsKey] as? [NSMetadataItem]) ?? []
        let changed = (notification.userInfo?[NSMetadataQueryUpdateChangedItemsKey] as? [NSMetadataItem]) ?? []

        for item in added {
            if let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL {
                emit(.added(url))
            }
        }
        for item in removed {
            if let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL {
                emit(.removed(url))
            }
        }
        for item in changed {
            if let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL {
                emit(.updated(url))
            }
        }
    }

    private func emit(_ event: FileSyncEvent) {
        for (_, continuation) in continuations {
            continuation.yield(event)
        }
    }

    private func uniqueDestination(for filename: String, in container: URL) -> URL {
        let fm = FileManager.default
        var candidate = container.appending(path: filename)
        var counter = 2
        while fm.fileExists(atPath: candidate.path) {
            let stem = (filename as NSString).deletingPathExtension
            let ext = (filename as NSString).pathExtension
            let newName = ext.isEmpty ? "\(stem) \(counter)" : "\(stem) \(counter).\(ext)"
            candidate = container.appending(path: newName)
            counter += 1
        }
        return candidate
    }
}

// MARK: - TCA Dependency Key

private enum FileSyncServiceKey: DependencyKey {
    static let liveValue: any FileSyncService = NoopFileSyncService()
}

private struct NoopFileSyncService: FileSyncService {
    var isAvailable: Bool { get async { false } }
    func ingest(localURL: URL) async throws -> URL {
        throw SyncError.iCloudUnavailable
    }
    func ensureLocal(url: URL) async throws {
        throw SyncError.iCloudUnavailable
    }
    func observeChanges() -> AsyncStream<FileSyncEvent> {
        AsyncStream { _ in }
    }
}

extension DependencyValues {
    public var fileSyncService: any FileSyncService {
        get { self[FileSyncServiceKey.self] }
        set { self[FileSyncServiceKey.self] = newValue }
    }
}
