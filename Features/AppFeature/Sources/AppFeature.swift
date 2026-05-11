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
        public var appLanguage: AppLanguage

        public init(
            library: LibraryFeature.State = LibraryFeature.State(),
            path: StackState<Path.State> = StackState(),
            appLanguage: AppLanguage = .systemDefault
        ) {
            self.library = library
            self.path = path
            self.appLanguage = appLanguage
        }
    }

    public enum Action {
        case task
        case library(LibraryFeature.Action)
        case path(StackActionOf<Path>)
    }

    @Dependency(\.userDefaults) var userDefaults

    public var body: some ReducerOf<Self> {
        Scope(state: \.library, action: \.library) {
            LibraryFeature()
        }

        Reduce { state, action in
            switch action {
            case .task:
                if let raw = userDefaults.string(forKey: SettingsFeature.languageKey),
                   let lang = AppLanguage(rawValue: raw) {
                    state.appLanguage = lang
                } else {
                    state.appLanguage = .systemDefault
                }
                return .none

            case let .library(.comicTapped(comic)):
                state.path.append(.reader(ReaderFeature.State(comic: comic)))
                return .none

            case .library(.settingsTapped):
                state.path.append(.settings(SettingsFeature.State(appLanguage: state.appLanguage)))
                return .none

            case let .path(.element(id: _, action: .settings(.appLanguageChanged(lang)))):
                state.appLanguage = lang
                return .none

            case .library, .path:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }
}

extension AppFeature.Path.State: Equatable {}
