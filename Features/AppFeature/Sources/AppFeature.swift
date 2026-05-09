import Foundation
import ComposableArchitecture
import Domain
import LibraryFeature
import ReaderFeature
import SettingsFeature

@Reducer
public struct AppFeature {
    public init() {}

    @Reducer
    public enum Path {
        case reader(ReaderFeature)
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

            case .library, .path:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }
}

extension AppFeature.Path.State: Equatable {}
