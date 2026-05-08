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
}
