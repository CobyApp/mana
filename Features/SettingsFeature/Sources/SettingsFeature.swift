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
        public var controlsAutoHideSeconds: Double
        public var tapZonesEnabled: Bool
        public var swipeEnabled: Bool
        public var appLanguage: AppLanguage

        public init(
            defaultMode: ReadingMode = .single,
            defaultPageProgressionDirection: PageProgressionDirection = .leftToRight,
            controlsAutoHideSeconds: Double = 3.0,
            tapZonesEnabled: Bool = true,
            swipeEnabled: Bool = true,
            appLanguage: AppLanguage = .system
        ) {
            self.defaultMode = defaultMode
            self.defaultPageProgressionDirection = defaultPageProgressionDirection
            self.controlsAutoHideSeconds = controlsAutoHideSeconds
            self.tapZonesEnabled = tapZonesEnabled
            self.swipeEnabled = swipeEnabled
            self.appLanguage = appLanguage
        }
    }

    public enum Action {
        case task
        case defaultModeChanged(ReadingMode)
        case defaultDirectionChanged(PageProgressionDirection)
        case controlsAutoHideChanged(Double)
        case tapZonesToggled(Bool)
        case swipeToggled(Bool)
        case appLanguageChanged(AppLanguage)
    }

    @Dependency(\.userDefaults) var defaults

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
                if let raw = defaults.string(forKey: Self.autoHideKey),
                   let val = Double(raw) {
                    state.controlsAutoHideSeconds = val
                }
                if let raw = defaults.string(forKey: Self.tapZonesKey) {
                    state.tapZonesEnabled = raw != "false"
                }
                if let raw = defaults.string(forKey: Self.swipeKey) {
                    state.swipeEnabled = raw != "false"
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

            case let .controlsAutoHideChanged(val):
                state.controlsAutoHideSeconds = val
                defaults.set(String(val), forKey: Self.autoHideKey)
                return .none

            case let .tapZonesToggled(enabled):
                state.tapZonesEnabled = enabled
                defaults.set(enabled ? "true" : "false", forKey: Self.tapZonesKey)
                return .none

            case let .swipeToggled(enabled):
                state.swipeEnabled = enabled
                defaults.set(enabled ? "true" : "false", forKey: Self.swipeKey)
                return .none

            case let .appLanguageChanged(lang):
                state.appLanguage = lang
                defaults.set(lang.rawValue, forKey: Self.languageKey)
                let arrayString = (lang == .system) ? "[]" : "[\"\(lang.rawValue)\"]"
                defaults.set(arrayString, forKey: "AppleLanguages")
                return .none
            }
        }
    }

    public static let modeKey = "mana.defaultReadingMode"
    public static let directionKey = "mana.defaultPageProgressionDirection"
    public static let autoHideKey = "mana.controlsAutoHideSeconds"
    public static let tapZonesKey = "mana.tapZonesEnabled"
    public static let swipeKey = "mana.swipeEnabled"
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
