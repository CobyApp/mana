import SwiftUI
import ComposableArchitecture
import AppFeature
import AdKit
import DesignSystem

@main
struct NOIZApp: App {
    init() {
        LiveDependencies.register()
        MobileAdsInitializer.start()
    }

    var body: some Scene {
        WindowGroup {
            RootContainer()
        }
    }
}

private struct RootContainer: View {
    /// Store must be `@State`-stored so it survives RootContainer re-renders
    /// (e.g. when `splashFinished` flips). If we re-create it inline in `body`,
    /// every state change wipes navigation path and feature state.
    @State private var store: StoreOf<AppFeature> = Store(
        initialState: AppFeature.State()
    ) {
        AppFeature()
    }
    @State private var splashFinished: Bool = false
    /// Lite mode is written by Settings as "true"/"false"; observing it here applies it live.
    @AppStorage(LiteMode.storageKey) private var liteModeRaw: String = "false"

    var body: some View {
        ZStack {
            AppView(store: store)

            if !splashFinished {
                NOIZSplash { splashFinished = true }
                    .transition(.opacity)
                    .zIndex(10)
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: splashFinished)
        .environment(\.manaLiteMode, liteModeRaw == "true")
    }
}
