import Foundation
import ComposableArchitecture
import Domain

@Reducer
public struct SettingsFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        public var defaultMode: ReadingMode
        public var defaultPageProgressionDirection: PageProgressionDirection
        public var appLanguage: AppLanguage
        @Presents public var resetAlert: AlertState<Action.ResetAlert>?

        public init(
            defaultMode: ReadingMode = .single,
            defaultPageProgressionDirection: PageProgressionDirection = .leftToRight,
            appLanguage: AppLanguage = .system
        ) {
            self.defaultMode = defaultMode
            self.defaultPageProgressionDirection = defaultPageProgressionDirection
            self.appLanguage = appLanguage
        }
    }

    public enum Action {
        case task
        case defaultModeChanged(ReadingMode)
        case defaultDirectionChanged(PageProgressionDirection)
        case appLanguageChanged(AppLanguage)
        case resetLibraryRequested
        case resetAlert(PresentationAction<ResetAlert>)
        case resetLibraryCompleted

        public enum ResetAlert: Equatable, Sendable {
            case confirm
        }
    }

    @Dependency(\.userDefaults) var defaults
    @Dependency(\.libraryResetService) var libraryResetService

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                if let raw = defaults.string(forKey: Self.modeKey),
                   let mode = ReadingMode(rawString: raw) {
                    state.defaultMode = mode
                }
                if let raw = defaults.string(forKey: Self.directionKey),
                   let dir = PageProgressionDirection(rawValue: raw) {
                    state.defaultPageProgressionDirection = dir
                }
                if let raw = defaults.string(forKey: Self.languageKey),
                   let lang = AppLanguage(rawValue: raw) {
                    state.appLanguage = lang
                }
                return .none

            case let .defaultModeChanged(mode):
                state.defaultMode = mode
                defaults.set(mode.rawString, forKey: Self.modeKey)
                return .none

            case let .defaultDirectionChanged(dir):
                state.defaultPageProgressionDirection = dir
                defaults.set(dir.rawValue, forKey: Self.directionKey)
                return .none

            case let .appLanguageChanged(lang):
                state.appLanguage = lang
                defaults.set(lang.rawValue, forKey: Self.languageKey)
                if lang == .system {
                    defaults.removeObject(forKey: "AppleLanguages")
                } else {
                    defaults.setStringArray([lang.rawValue], forKey: "AppleLanguages")
                }
                return .none

            case .resetLibraryRequested:
                state.resetAlert = AlertState {
                    TextState("settings.reset_title", bundle: .module)
                } actions: {
                    ButtonState(role: .destructive, action: .confirm) {
                        TextState("settings.reset_confirm", bundle: .module)
                    }
                    ButtonState(role: .cancel) {
                        TextState("settings.cancel", bundle: .module)
                    }
                } message: {
                    TextState("settings.reset_message", bundle: .module)
                }
                return .none

            case .resetAlert(.presented(.confirm)):
                let resetService = self.libraryResetService
                return .run { send in
                    try? await resetService.resetAll()
                    await send(.resetLibraryCompleted)
                }

            case .resetAlert:
                return .none

            case .resetLibraryCompleted:
                return .none
            }
        }
        .ifLet(\.$resetAlert, action: \.resetAlert)
    }

    public static let modeKey = "mana.defaultReadingMode"
    public static let directionKey = "mana.defaultPageProgressionDirection"
    public static let languageKey = "mana.appLanguage"
}

public enum AppLanguage: String, Sendable, Equatable, CaseIterable {
    case system
    case en
    case ko
    case ja
}

public protocol UserDefaultsClient: Sendable {
    func string(forKey key: String) -> String?
    func set(_ value: String, forKey key: String)
    func double(forKey key: String) -> Double
    func removeObject(forKey key: String)
    func setStringArray(_ value: [String], forKey key: String)
}

public struct LiveUserDefaultsClient: UserDefaultsClient {
    public init() {}
    public func string(forKey key: String) -> String? {
        UserDefaults.standard.string(forKey: key)
    }
    public func set(_ value: String, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
    public func double(forKey key: String) -> Double {
        UserDefaults.standard.double(forKey: key)
    }
    public func removeObject(forKey key: String) {
        UserDefaults.standard.removeObject(forKey: key)
    }
    public func setStringArray(_ value: [String], forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
}

public final class InMemoryUserDefaults: UserDefaultsClient, @unchecked Sendable {
    private var values: [String: String] = [:]
    private let lock = NSLock()
    public init() {}
    public func string(forKey key: String) -> String? {
        lock.lock(); defer { lock.unlock() }
        return values[key]
    }
    public func set(_ value: String, forKey key: String) {
        lock.lock(); defer { lock.unlock() }
        values[key] = value
    }
    public func double(forKey key: String) -> Double {
        lock.lock(); defer { lock.unlock() }
        return values[key].flatMap(Double.init) ?? 0
    }
    public func removeObject(forKey key: String) {
        lock.lock(); defer { lock.unlock() }
        values.removeValue(forKey: key)
    }
    public func setStringArray(_ value: [String], forKey key: String) {
        lock.lock(); defer { lock.unlock() }
        values[key] = value.joined(separator: ",")
    }
}

private enum UserDefaultsKey: DependencyKey {
    static let liveValue: any UserDefaultsClient = LiveUserDefaultsClient()
    static let testValue: any UserDefaultsClient = InMemoryUserDefaults()
}

extension DependencyValues {
    public var userDefaults: any UserDefaultsClient {
        get { self[UserDefaultsKey.self] }
        set { self[UserDefaultsKey.self] = newValue }
    }
}

private struct NoopLibraryResetService: LibraryResetService {
    func resetAll() async throws {}
}

private enum LibraryResetServiceKey: DependencyKey {
    static let liveValue: any LibraryResetService = NoopLibraryResetService()
}

extension DependencyValues {
    public var libraryResetService: any LibraryResetService {
        get { self[LibraryResetServiceKey.self] }
        set { self[LibraryResetServiceKey.self] = newValue }
    }
}
