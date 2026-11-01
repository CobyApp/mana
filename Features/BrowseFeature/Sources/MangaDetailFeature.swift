import Foundation
import ComposableArchitecture
import Domain

@Reducer
public struct MangaDetailFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        public let mangaURL: String
        public var preview: SourceManga?
        public var detail: SourceDetail?
        public var loading: Bool = true
        public var error: Bool = false
        public var imageHeaders: [String: String] = [:]

        public init(mangaURL: String, preview: SourceManga? = nil) {
            self.mangaURL = mangaURL
            self.preview = preview
        }
    }

    public enum Action {
        case task
        case retry
        case detailLoaded(SourceDetail)
        case loadFailed
        case chapterTapped(SourceChapter)   // read online — handled by parent (Stage 4)
        case downloadChapter(SourceChapter) // enqueue download — handled in Stage 4
    }

    @Dependency(\.sourceRegistry) var registry

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task, .retry:
                state.loading = true
                state.error = false
                state.imageHeaders = registry.active().imageHeaders()
                let url = state.mangaURL
                let registry = self.registry
                return .run { send in
                    do {
                        let detail = try await registry.active().detail(mangaURL: url)
                        await send(.detailLoaded(detail))
                    } catch {
                        await send(.loadFailed)
                    }
                }

            case let .detailLoaded(detail):
                state.loading = false
                state.detail = detail
                return .none

            case .loadFailed:
                state.loading = false
                state.error = true
                return .none

            case .chapterTapped, .downloadChapter:
                return .none
            }
        }
    }
}
