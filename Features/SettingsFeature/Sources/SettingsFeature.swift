import Foundation
import ComposableArchitecture
import Domain

@Reducer
public struct SettingsFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        public var defaultMode: ReadingMode

        public init(defaultMode: ReadingMode = .single) {
            self.defaultMode = defaultMode
        }
    }

    public enum Action {
        case task
        case defaultModeChanged(ReadingMode)
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
                return .none

            case let .defaultModeChanged(mode):
                state.defaultMode = mode
                defaults.set(mode.rawString, forKey: Self.modeKey)
                return .none
            }
        }
    }

    public static let modeKey = "mana.defaultReadingMode"
}

public protocol UserDefaultsClient: Sendable {
    func string(forKey key: String) -> String?
    func set(_ value: String, forKey key: String)
}

public struct LiveUserDefaultsClient: UserDefaultsClient {
    public init() {}
    public func string(forKey key: String) -> String? {
        UserDefaults.standard.string(forKey: key)
    }
    public func set(_ value: String, forKey key: String) {
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
