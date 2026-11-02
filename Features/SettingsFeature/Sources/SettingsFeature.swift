import Foundation
import ComposableArchitecture
import Domain
import DesignSystem

@Reducer
public struct SettingsFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        public var defaultMode: ReadingMode
        public var defaultPageProgressionDirection: PageProgressionDirection
        public var defaultPageOffset: Bool
        public var appLanguage: AppLanguage
        /// Flattens decorative effects (halftone, glitch, speed lines) for performance / e-ink.
        public var liteMode: Bool
        /// Manga-styled reset confirm dialog (Android `ResetConfirmDialog`).
        public var isResetConfirmPresented: Bool = false

        public init(
            defaultMode: ReadingMode = .single,
            defaultPageProgressionDirection: PageProgressionDirection = .leftToRight,
            defaultPageOffset: Bool = false,
            appLanguage: AppLanguage = .system,
            liteMode: Bool = false
        ) {
            self.defaultMode = defaultMode
            self.defaultPageProgressionDirection = defaultPageProgressionDirection
            self.defaultPageOffset = defaultPageOffset
            self.appLanguage = appLanguage
            self.liteMode = liteMode
        }
    }

    public enum Action {
        case task
        case defaultModeChanged(ReadingMode)
        case defaultDirectionChanged(PageProgressionDirection)
        case defaultPageOffsetChanged(Bool)
        case appLanguageChanged(AppLanguage)
        case liteModeChanged(Bool)
        case resetLibraryRequested
        case resetConfirmDismissed
        case resetConfirmed
        case resetLibraryCompleted
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
                if let raw = defaults.string(forKey: Self.pageOffsetKey) {
                    state.defaultPageOffset = (raw == "true")
                }
                state.liteMode = defaults.string(forKey: LiteMode.storageKey) == "true"
                // appLanguage is owned by AppFeature and injected on push;
                // do not overwrite from UserDefaults here.
                return .none

            case let .defaultModeChanged(mode):
                state.defaultMode = mode
                defaults.set(mode.rawString, forKey: Self.modeKey)
                return .none

            case let .defaultDirectionChanged(dir):
                state.defaultPageProgressionDirection = dir
                defaults.set(dir.rawValue, forKey: Self.directionKey)
                return .none

            case let .defaultPageOffsetChanged(offset):
                state.defaultPageOffset = offset
                defaults.set(offset ? "true" : "false", forKey: Self.pageOffsetKey)
                return .none

            case let .appLanguageChanged(lang):
                state.appLanguage = lang
                defaults.set(lang.rawValue, forKey: Self.languageKey)
                // No AppleLanguages override; the live `\.locale` environment in AppView
                // applies the new language immediately without an app restart.
                return .none

            case let .liteModeChanged(enabled):
                state.liteMode = enabled
                defaults.set(enabled ? "true" : "false", forKey: LiteMode.storageKey)
                return .none

            case .resetLibraryRequested:
                state.isResetConfirmPresented = true
                return .none

            case .resetConfirmDismissed:
                state.isResetConfirmPresented = false
                return .none

            case .resetConfirmed:
                state.isResetConfirmPresented = false
                let resetService = self.libraryResetService
                return .run { send in
                    try? await resetService.resetAll()
                    await send(.resetLibraryCompleted)
                }

            case .resetLibraryCompleted:
                return .none
            }
        }
    }

    public static let modeKey = "mana.defaultReadingMode"
    public static let directionKey = "mana.defaultPageProgressionDirection"
    public static let pageOffsetKey = "mana.defaultPageOffset"
    public static let languageKey = "mana.appLanguage"
}

public enum AppLanguage: String, Sendable, Equatable, CaseIterable {
    case system
    case ko
    case ja
    case en
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
