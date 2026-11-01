import Foundation
import ComposableArchitecture
import Domain
import SourceKit

public enum BrowseTab: Equatable, Sendable { case latest, genres }

@Reducer
public struct BrowseFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        public var tab: BrowseTab = .latest
        public var items: [SourceManga] = []
        public var genres: [SourceGenre] = []
        public var selectedGenre: SourceGenre?
        public var loading: Bool = true
        public var loadingMore: Bool = false
        public var page: Int = 1
        public var endReached: Bool = false
        public var error: Bool = false
        // Search overlay: non-nil query means search mode is open.
        public var searchQuery: String?
        public var searchItems: [SourceManga] = []
        public var searching: Bool = false
        public var searchPage: Int = 1
        public var searchEndReached: Bool = false
        public var imageHeaders: [String: String] = [:]

        public init() {}
    }

    public enum Action {
        case task
        case selectTab(BrowseTab)
        case selectGenre(SourceGenre)
        case loadMore
        case retry
        case openSearch
        case closeSearch
        case setQuery(String)
        case loadMoreSearch
        case mangaTapped(SourceManga)

        case firstLoaded([SourceManga])
        case loadFailed
        case moreLoaded(page: Int, [SourceManga])
        case genresLoaded([SourceGenre])
        case searchLoaded(page: Int, [SourceManga])
        case searchFailed
    }

    @Dependency(\.sourceRegistry) var registry

    private enum CancelID: Hashable { case load, search }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                state.imageHeaders = registry.active().imageHeaders()
                return .merge(loadFirst(&state), loadGenres())

            case let .selectTab(tab):
                guard state.tab != tab else { return .none }
                state.tab = tab
                if tab == .latest {
                    state.selectedGenre = nil
                    return loadFirst(&state)
                } else if state.selectedGenre == nil {
                    state.items = []
                    state.loading = false
                    return .cancel(id: CancelID.load)
                }
                return .none

            case let .selectGenre(genre):
                state.selectedGenre = genre
                state.tab = .genres
                return loadFirst(&state)

            case .loadMore:
                guard !state.loading, !state.loadingMore, !state.endReached else { return .none }
                state.loadingMore = true
                let next = state.page + 1
                let genre = state.selectedGenre
                let registry = self.registry
                return .run { send in
                    do {
                        let items = try await Self.fetch(registry: registry, genre: genre, page: next)
                        await send(.moreLoaded(page: next, items))
                    } catch {
                        await send(.moreLoaded(page: next, []))
                    }
                }
                .cancellable(id: CancelID.load, cancelInFlight: false)

            case .retry:
                return loadFirst(&state)

            case .openSearch:
                state.searchQuery = ""
                return .none

            case .closeSearch:
                state.searchQuery = nil
                state.searchItems = []
                state.searching = false
                state.searchEndReached = false
                state.searchPage = 1
                return .cancel(id: CancelID.search)

            case let .setQuery(query):
                state.searchQuery = query
                let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    state.searchItems = []
                    state.searching = false
                    state.searchEndReached = false
                    state.searchPage = 1
                    return .cancel(id: CancelID.search)
                }
                state.searching = true
                let registry = self.registry
                return .run { send in
                    try? await Task.sleep(nanoseconds: 300_000_000) // debounce
                    do {
                        let items = try await registry.active().search(query: trimmed, page: 1)
                        await send(.searchLoaded(page: 1, items))
                    } catch {
                        await send(.searchFailed)
                    }
                }
                .cancellable(id: CancelID.search, cancelInFlight: true)

            case .loadMoreSearch:
                guard let query = state.searchQuery?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !query.isEmpty, !state.searching, !state.searchEndReached else { return .none }
                state.searching = true
                let next = state.searchPage + 1
                let registry = self.registry
                return .run { send in
                    do {
                        let items = try await registry.active().search(query: query, page: next)
                        await send(.searchLoaded(page: next, items))
                    } catch {
                        await send(.searchFailed)
                    }
                }
                .cancellable(id: CancelID.search, cancelInFlight: false)

            case let .firstLoaded(items):
                state.loading = false
                state.items = dedup(items)
                state.endReached = items.isEmpty
                return .none

            case .loadFailed:
                state.loading = false
                state.error = true
                return .none

            case let .moreLoaded(page, more):
                state.loadingMore = false
                let merged = dedup(state.items + more)
                let grew = merged.count > state.items.count
                state.items = merged
                state.page = page
                state.endReached = more.isEmpty || !grew
                return .none

            case let .genresLoaded(genres):
                state.genres = genres
                return .none

            case let .searchLoaded(page, items):
                state.searching = false
                if page == 1 {
                    state.searchItems = dedup(items)
                    state.searchPage = 1
                    state.searchEndReached = items.isEmpty
                } else {
                    let merged = dedup(state.searchItems + items)
                    let grew = merged.count > state.searchItems.count
                    state.searchItems = merged
                    state.searchPage = page
                    state.searchEndReached = items.isEmpty || !grew
                }
                return .none

            case .searchFailed:
                state.searching = false
                return .none

            case .mangaTapped:
                return .none  // handled by the parent (AppFeature) to push detail
            }
        }
    }

    private func loadFirst(_ state: inout State) -> Effect<Action> {
        state.loading = true
        state.error = false
        state.page = 1
        state.endReached = false
        state.items = []
        let genre = state.selectedGenre
        let registry = self.registry
        return .run { send in
            do {
                let items = try await Self.fetch(registry: registry, genre: genre, page: 1)
                await send(.firstLoaded(items))
            } catch {
                await send(.loadFailed)
            }
        }
        .cancellable(id: CancelID.load, cancelInFlight: true)
    }

    private func loadGenres() -> Effect<Action> {
        let registry = self.registry
        return .run { send in
            if let genres = try? await registry.active().genres() {
                await send(.genresLoaded(genres))
            }
        }
    }

    private static func fetch(registry: any SourceRegistry, genre: SourceGenre?, page: Int) async throws -> [SourceManga] {
        let source = registry.active()
        if let genre {
            return try await source.byGenre(slug: genre.slug, page: page)
        }
        return try await source.latest(page: page)
    }

    private func dedup(_ items: [SourceManga]) -> [SourceManga] {
        var seen = Set<String>()
        return items.filter { seen.insert($0.url).inserted }
    }
}

// MARK: - Source dependency

private enum SourceRegistryKey: DependencyKey {
    static let liveValue: any SourceRegistry = RawkumaRegistry()
}

extension DependencyValues {
    public var sourceRegistry: any SourceRegistry {
        get { self[SourceRegistryKey.self] }
        set { self[SourceRegistryKey.self] = newValue }
    }
}
