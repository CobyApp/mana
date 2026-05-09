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

    @Test func appLanguageChangedSetsAppleLanguages() async {
        let defaults = InMemoryUserDefaults()
        let store = await TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.userDefaults = defaults
        }
        // Default is .ko; switch to .ja so the state actually changes.
        await store.send(.appLanguageChanged(.ja)) {
            $0.appLanguage = .ja
        }
        #expect(defaults.string(forKey: SettingsFeature.languageKey) == "ja")
        // InMemory stores [String] as a comma-joined string; verify the value is non-nil
        // (Live variant writes a real [String] array that iOS reads correctly).
        #expect(defaults.string(forKey: "AppleLanguages") != nil)
    }

}
