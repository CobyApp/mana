import Testing
import Foundation
import ComposableArchitecture
@testable import SettingsFeature
import Domain

@MainActor
@Suite struct SettingsFeatureTests {

    @Test func defaultsToSingleMode() async {
        let store = await TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.userDefaults = InMemoryUserDefaults()
        }
        await store.send(.task)
        #expect(store.state.defaultMode == .single)
    }

    @Test func setDefaultModeUpdatesState() async {
        let store = await TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.userDefaults = InMemoryUserDefaults()
        }
        await store.send(.defaultModeChanged(.dual)) {
            $0.defaultMode = .dual
        }
    }

    @Test func taskLoadsPersistedMode() async {
        let defaults = InMemoryUserDefaults()
        defaults.set("dual", forKey: SettingsFeature.modeKey)
        let store = await TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.userDefaults = defaults
        }
        await store.send(.task) {
            $0.defaultMode = .dual
        }
    }

    @Test func defaultDirectionChangedPersists() async {
        let defaults = InMemoryUserDefaults()
        let store = await TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.userDefaults = defaults
        }
        await store.send(.defaultDirectionChanged(.rightToLeft)) {
            $0.defaultPageProgressionDirection = .rightToLeft
        }
        #expect(defaults.string(forKey: SettingsFeature.directionKey) == "rightToLeft")
    }

    @Test func controlsAutoHideChangedPersists() async {
        let defaults = InMemoryUserDefaults()
        let store = await TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.userDefaults = defaults
        }
        await store.send(.controlsAutoHideChanged(5.0)) {
            $0.controlsAutoHideSeconds = 5.0
        }
        // Stored as a string for the same getter API used elsewhere
        #expect(defaults.string(forKey: SettingsFeature.autoHideKey) == "5.0")
    }

    @Test func appLanguageChangedSetsAppleLanguages() async {
        let defaults = InMemoryUserDefaults()
        let store = await TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.userDefaults = defaults
        }
        await store.send(.appLanguageChanged(.ko)) {
            $0.appLanguage = .ko
        }
        #expect(defaults.string(forKey: SettingsFeature.languageKey) == "ko")
        // InMemory stores [String] as a comma-joined string; verify the value is non-nil
        // (Live variant writes a real [String] array that iOS reads correctly).
        #expect(defaults.string(forKey: "AppleLanguages") != nil)
    }

    @Test func appLanguageSystemRemovesAppleLanguagesKey() async {
        let defaults = InMemoryUserDefaults()
        // Pre-populate a language override so we can verify it gets removed.
        defaults.setStringArray(["ko"], forKey: "AppleLanguages")
        let store = await TestStore(initialState: SettingsFeature.State(appLanguage: .ko)) {
            SettingsFeature()
        } withDependencies: {
            $0.userDefaults = defaults
        }
        await store.send(.appLanguageChanged(.system)) {
            $0.appLanguage = .system
        }
        #expect(defaults.string(forKey: SettingsFeature.languageKey) == "system")
        // The key must be absent so iOS uses its default fallback chain.
        #expect(defaults.string(forKey: "AppleLanguages") == nil)
    }
}
