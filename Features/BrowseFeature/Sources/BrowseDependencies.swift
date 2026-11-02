import Foundation
import ComposableArchitecture
import Domain

// TCA dependency seams for the online stack. Live implementations live in the App target and are
// injected in DependenciesLive; these Noop defaults keep previews/tests from touching the network.

private struct NoopDownloadManager: DownloadManager {
    var active: [DownloadEntry] { [] }
    func activeStream() -> AsyncStream<[DownloadEntry]> { AsyncStream { $0.finish() } }
    var pendingResume: [DownloadEntry] { [] }
    func enqueue(chapterURL: String, seriesURL: String, seriesTitle: String, chapterName: String, seriesCoverURL: String?) {}
    func restore() async {}
    func resumePending() {}
    func dismissPending() {}
    var paused: Bool { false }
    func pausedStream() -> AsyncStream<Bool> { AsyncStream { $0.finish() } }
    func pause() {}
    func resume() {}
    func cancel(chapterURL: String) {}
    func cancelAll() {}
}

private struct NoopReadChapterRepository: ReadChapterRepository {
    func readURLs() async -> Set<String> { [] }
    func observeReadURLs() -> AsyncStream<Set<String>> { AsyncStream { $0.finish() } }
    func markRead(chapterURL: String) async {}
}

private enum DownloadManagerKey: DependencyKey {
    static let liveValue: any DownloadManager = NoopDownloadManager()
}

private enum ReadChapterRepositoryKey: DependencyKey {
    static let liveValue: any ReadChapterRepository = NoopReadChapterRepository()
}

extension DependencyValues {
    public var downloadManager: any DownloadManager {
        get { self[DownloadManagerKey.self] }
        set { self[DownloadManagerKey.self] = newValue }
    }
    public var readChapterRepository: any ReadChapterRepository {
        get { self[ReadChapterRepositoryKey.self] }
        set { self[ReadChapterRepositoryKey.self] = newValue }
    }
}
