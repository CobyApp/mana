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
        await store.send(.defaultModeChanged(.scroll(direction: .rtl))) {
            $0.defaultMode = .scroll(direction: .rtl)
        }
    }

    @Test func taskLoadsPersistedMode() async {
        let defaults = InMemoryUserDefaults()
        defaults.set("scroll-ttb", forKey: SettingsFeature.modeKey)
        let store = await TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.userDefaults = defaults
        }
        await store.send(.task) {
            $0.defaultMode = .scroll(direction: .ttb)
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

    @Test func tapZonesToggledPersists() async {
        let defaults = InMemoryUserDefaults()
        let store = await TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.userDefaults = defaults
        }
        await store.send(.tapZonesToggled(false)) {
            $0.tapZonesEnabled = false
        }
        #expect(defaults.string(forKey: SettingsFeature.tapZonesKey) == "false")
    }

    @Test func swipeToggledPersists() async {
        let defaults = InMemoryUserDefaults()
        let store = await TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.userDefaults = defaults
        }
        await store.send(.swipeToggled(false)) {
            $0.swipeEnabled = false
        }
        #expect(defaults.string(forKey: SettingsFeature.swipeKey) == "false")
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
        #expect(defaults.string(forKey: "AppleLanguages") == "[\"ko\"]")
    }
}
