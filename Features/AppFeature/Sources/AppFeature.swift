import Foundation
import ComposableArchitecture
import Domain
import IntelligenceKit
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
        public var isIntelligenceAvailable: Bool

        public init(
            library: LibraryFeature.State = LibraryFeature.State(),
            path: StackState<Path.State> = StackState(),
            appLanguage: AppLanguage = .system,
            isIntelligenceAvailable: Bool = false
        ) {
            self.library = library
            self.path = path
            self.appLanguage = appLanguage
            self.isIntelligenceAvailable = isIntelligenceAvailable
        }
    }

    public enum Action {
        case task
        case library(LibraryFeature.Action)
        case path(StackActionOf<Path>)
    }

    @Dependency(\.userDefaults) var userDefaults
    @Dependency(\.intelligenceAvailability) var intelligenceAvailability

    public var body: some ReducerOf<Self> {
        Scope(state: \.library, action: \.library) {
            LibraryFeature()
        }

        Reduce { state, action in
            switch action {
            case .task:
                state.isIntelligenceAvailable = intelligenceAvailability.isAvailable
                // Pre-`.system` builds auto-saved a concrete language (often "en")
                // when the main bundle had no advertised localizations. Clear that
                // stale value once so users land on `.system` by default.
                let migrationKey = "mana.appLanguage.migrated_to_system_v1"
                if userDefaults.string(forKey: migrationKey) == nil {
                    userDefaults.removeObject(forKey: SettingsFeature.languageKey)
                    userDefaults.set("1", forKey: migrationKey)
                }
                if let raw = userDefaults.string(forKey: SettingsFeature.languageKey),
                   let lang = AppLanguage(rawValue: raw) {
                    state.appLanguage = lang
                } else {
                    state.appLanguage = .system
                }
                return .none

            case let .library(.comicTapped(comic)):
                let target = TargetLanguageResolver.resolve(appLanguageRawValue: state.appLanguage.rawValue)
                let translation = ReaderFeature.TranslationState(
                    isIntelligenceAvailable: state.isIntelligenceAvailable,
                    targetLanguage: target
                )
                state.path.append(.reader(ReaderFeature.State(comic: comic, translation: translation)))
                return .none

            case .library(.settingsTapped):
                state.path.append(
                    .settings(
                        SettingsFeature.State(
                            appLanguage: state.appLanguage,
                            isIntelligenceAvailable: state.isIntelligenceAvailable
                        )
                    )
                )
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

private enum IntelligenceAvailabilityKey: DependencyKey {
    static let liveValue: any IntelligenceAvailability = UnavailableIntelligence()
    static let testValue: any IntelligenceAvailability = UnavailableIntelligence()
}

extension DependencyValues {
    public var intelligenceAvailability: any IntelligenceAvailability {
        get { self[IntelligenceAvailabilityKey.self] }
        set { self[IntelligenceAvailabilityKey.self] = newValue }
    }
}
