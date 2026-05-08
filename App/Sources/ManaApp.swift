import SwiftUI
import ComposableArchitecture
import AppFeature

@main
struct ManaApp: App {
    init() {
        LiveDependencies.register()
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: Store(initialState: AppFeature.State()) {
                AppFeature()
            })
        }
    }
}
