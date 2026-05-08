import Foundation
import ComposableArchitecture
import Domain
import LibraryFeature
import ReaderFeature
import BookmarksFeature
import SettingsFeature

@Reducer
public struct AppFeature {
    public init() {}

    @Reducer
    public enum Path {
        case reader(ReaderFeature)
        case bookmarks(BookmarksFeature)
        case settings(SettingsFeature)
    }

    @ObservableState
    public struct State: Equatable {
        public var library: LibraryFeature.State
        public var path: StackState<Path.State>

        public init(
            library: LibraryFeature.State = LibraryFeature.State(),
            path: StackState<Path.State> = StackState()
        ) {
            self.library = library
            self.path = path
        }
    }

    public enum Action {
        case library(LibraryFeature.Action)
        case path(StackActionOf<Path>)
    }

    public var body: some ReducerOf<Self> {
        Scope(state: \.library, action: \.library) {
            LibraryFeature()
        }

        Reduce { state, action in
            switch action {
            case let .library(.comicTapped(comic)):
                state.path.append(.reader(ReaderFeature.State(comic: comic)))
                return .none

            case .library(.settingsTapped):
                state.path.append(.settings(SettingsFeature.State()))
                return .none

            case let .path(.element(id: _, action: .reader(.bookmarksTapped(comicId, pageIndex)))):
                state.path.append(.bookmarks(BookmarksFeature.State(comicId: comicId, currentPageIndex: pageIndex)))
                return .none

            case let .path(.element(id: _, action: .bookmarks(.tapped(bookmark)))):
                state.path.removeLast()
                if let lastId = state.path.ids.last,
                   case var .reader(readerState) = state.path[id: lastId],
                   readerState.comic.id == bookmark.comicId {
                    readerState.pageIndex = bookmark.pageIndex
                    state.path[id: lastId] = .reader(readerState)
                }
                return .none

            case .library, .path:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }
}

extension AppFeature.Path.State: Equatable {}
