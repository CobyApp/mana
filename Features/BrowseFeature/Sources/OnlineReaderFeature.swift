import Foundation
import ComposableArchitecture
import Domain
import SettingsFeature

/// Streams an online chapter's pages. Reading progress is in-memory only; reading options start
/// from the user's defaults and can be changed for the session. Ported from Android
/// `OnlineReaderViewModel`.
@Reducer
public struct OnlineReaderFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        public let chapterURL: String
        public let title: String
        public var pageURLs: [String] = []
        public var pageCount: Int = 0
        public var pageIndex: Int = 0
        public var mode: ReadingMode = .single
        public var direction: PageProgressionDirection = .leftToRight
        public var pageOffset: Bool = false
        public var loading: Bool = true
        public var error: Bool = false
        public var isControlsVisible: Bool = true
        public var imageHeaders: [String: String] = [:]

        public init(chapterURL: String, title: String) {
            self.chapterURL = chapterURL
            self.title = title
        }
    }

    public enum Action {
        case task
        case loaded(pages: [String], headers: [String: String])
        case loadFailed
        case retry
        case pageChanged(Int)
        case toggleControls
        case modeChanged(ReadingMode)
        case directionChanged(PageProgressionDirection)
        case pageOffsetChanged(Bool)
    }

    @Dependency(\.sourceRegistry) var registry
    @Dependency(\.readChapterRepository) var readChapters
    @Dependency(\.userDefaults) var userDefaults

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                // Apply user defaults for the session.
                if let raw = userDefaults.string(forKey: SettingsFeature.modeKey), let m = ReadingMode(rawString: raw) { state.mode = m }
                if let raw = userDefaults.string(forKey: SettingsFeature.directionKey), let d = PageProgressionDirection(rawValue: raw) { state.direction = d }
                if let raw = userDefaults.string(forKey: SettingsFeature.pageOffsetKey) { state.pageOffset = (raw == "true") }
                return load(state.chapterURL)

            case .retry:
                state.error = false
                state.loading = true
                return load(state.chapterURL)

            case let .loaded(pages, headers):
                state.loading = false
                state.pageURLs = pages
                state.pageCount = pages.count
                state.imageHeaders = headers
                state.error = pages.isEmpty
                return .none

            case .loadFailed:
                state.loading = false
                state.error = true
                return .none

            case let .pageChanged(index):
                guard index >= 0, index < state.pageCount else { return .none }
                state.pageIndex = index
                return .none

            case .toggleControls:
                state.isControlsVisible.toggle()
                return .none

            case let .modeChanged(mode):
                state.mode = mode
                return .none

            case let .directionChanged(direction):
                state.direction = direction
                return .none

            case let .pageOffsetChanged(offset):
                state.pageOffset = offset
                return .none
            }
        }
    }

    private func load(_ chapterURL: String) -> Effect<Action> {
        let registry = self.registry
        let readChapters = self.readChapters
        return .run { send in
            await readChapters.markRead(chapterURL: chapterURL)
            let source = registry.active()
            let headers = source.imageHeaders()
            var urls: [String] = []
            for attempt in 0..<3 {
                urls = (try? await source.pages(chapterURL: chapterURL)) ?? []
                if !urls.isEmpty { break }
                try? await Task.sleep(nanoseconds: 700_000_000 * UInt64(attempt + 1))
            }
            if urls.isEmpty {
                await send(.loadFailed)
            } else {
                await send(.loaded(pages: urls, headers: headers))
            }
        }
    }
}
