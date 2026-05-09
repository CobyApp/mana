import Foundation
import ComposableArchitecture
import Domain

public actor FileSyncServiceLive: FileSyncService {

    private let ubi: UbiquityContainer
    /// Test-only override: when set, bypasses `ubi` for container URL resolution.
    private let containerURLProvider: (@Sendable () -> URL?)?
    private var continuations: [UUID: AsyncStream<FileSyncEvent>.Continuation] = [:]
    private var metadataQuery: NSMetadataQuery?
    private var queryObservers: [NSObjectProtocol] = []

    public init(ubi: UbiquityContainer) {
        self.ubi = ubi
        self.containerURLProvider = nil
    }

    /// Internal test initialiser — injects a closure so tests can supply a temp directory
    /// without needing a real iCloud container.
    internal init(containerURLProvider: @escaping @Sendable () -> URL?) {
        self.ubi = UbiquityContainer(identifier: "test")
        self.containerURLProvider = containerURLProvider
    }

    // MARK: - Availability (re-evaluated on every access)

    private var resolvedContainerURL: URL? {
        if let provider = containerURLProvider { return provider() }
        return ubi.containerURL
    }

    private var resolvedIsAvailable: Bool { resolvedContainerURL != nil }

    public var isAvailable: Bool {
        get async { resolvedIsAvailable }
    }

    public func ingest(localURL: URL) async throws -> URL {
        guard let container = resolvedContainerURL else {
            throw SyncError.iCloudUnavailable
        }
        // Ensure the Documents subdirectory exists
        try? FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
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
        guard resolvedIsAvailable else { throw SyncError.iCloudUnavailable }
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
        if metadataQuery == nil, resolvedIsAvailable {
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
        let updateToken = center.addObserver(forName: .NSMetadataQueryDidUpdate, object: query, queue: .main) { [weak self] note in
            let extracted = Self.extractURLs(note)
            Task { await self?.handleEvents(added: extracted.added, removed: extracted.removed, changed: extracted.changed) }
        }
        let gatherToken = center.addObserver(forName: .NSMetadataQueryDidFinishGathering, object: query, queue: .main) { [weak self] note in
            let extracted = Self.extractURLs(note)
            Task { await self?.handleEvents(added: extracted.added, removed: extracted.removed, changed: extracted.changed) }
        }
        queryObservers = [updateToken, gatherToken]
        query.start()
        metadataQuery = query
    }

    /// Pull Sendable URL arrays out of the Notification on the calling thread,
    /// so we can hop into the actor with only Sendable values.
    private nonisolated static func extractURLs(_ notification: Notification) -> (added: [URL], removed: [URL], changed: [URL]) {
        let added = (notification.userInfo?[NSMetadataQueryUpdateAddedItemsKey] as? [NSMetadataItem])?
            .compactMap { $0.value(forAttribute: NSMetadataItemURLKey) as? URL } ?? []
        let removed = (notification.userInfo?[NSMetadataQueryUpdateRemovedItemsKey] as? [NSMetadataItem])?
            .compactMap { $0.value(forAttribute: NSMetadataItemURLKey) as? URL } ?? []
        let changed = (notification.userInfo?[NSMetadataQueryUpdateChangedItemsKey] as? [NSMetadataItem])?
            .compactMap { $0.value(forAttribute: NSMetadataItemURLKey) as? URL } ?? []
        return (added, removed, changed)
    }

    private func stopMetadataQuery() {
        metadataQuery?.stop()
        metadataQuery = nil
        let center = NotificationCenter.default
        for token in queryObservers {
            center.removeObserver(token)
        }
        queryObservers.removeAll()
    }

    private func handleEvents(added: [URL], removed: [URL], changed: [URL]) {
        for url in added { emit(.added(url)) }
        for url in removed { emit(.removed(url)) }
        for url in changed { emit(.updated(url)) }
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
