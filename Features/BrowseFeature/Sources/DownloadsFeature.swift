import Foundation
import ComposableArchitecture
import Domain

@Reducer
public struct DownloadsFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        public var entries: [DownloadEntry] = []
        public var paused: Bool = false
        public init() {}
    }

    public enum Action {
        case task
        case entriesUpdated([DownloadEntry])
        case pausedUpdated(Bool)
        case cancel(String)
        case cancelAll
        case togglePause
    }

    @Dependency(\.downloadManager) var downloads

    private enum CancelID: Hashable { case active, paused }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                let downloads = self.downloads
                return .merge(
                    .run { send in
                        for await entries in downloads.activeStream() { await send(.entriesUpdated(entries)) }
                    }.cancellable(id: CancelID.active, cancelInFlight: true),
                    .run { send in
                        for await p in downloads.pausedStream() { await send(.pausedUpdated(p)) }
                    }.cancellable(id: CancelID.paused, cancelInFlight: true)
                )

            case let .entriesUpdated(entries):
                state.entries = entries
                return .none

            case let .pausedUpdated(p):
                state.paused = p
                return .none

            case let .cancel(url):
                downloads.cancel(chapterURL: url)
                return .none

            case .cancelAll:
                downloads.cancelAll()
                return .none

            case .togglePause:
                if state.paused { downloads.resume() } else { downloads.pause() }
                return .none
            }
        }
    }
}
