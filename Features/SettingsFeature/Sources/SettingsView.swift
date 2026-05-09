import SwiftUI
import ComposableArchitecture
import Domain

public struct SettingsView: View {
    @Bindable public var store: StoreOf<SettingsFeature>
    @State private var showingRestartAlert = false

    public init(store: StoreOf<SettingsFeature>) { self.store = store }

    public var body: some View {
        Form {
            Section("General") {
                Picker("Default Reading Mode", selection: Binding(
                    get: { store.defaultMode },
                    set: { store.send(.defaultModeChanged($0)) }
                )) {
                    Text("Single").tag(ReadingMode.single)
                    Text("Dual").tag(ReadingMode.dual)
                    Text("Scroll LTR").tag(ReadingMode.scroll(direction: .ltr))
                    Text("Scroll RTL").tag(ReadingMode.scroll(direction: .rtl))
                    Text("Webtoon (TTB)").tag(ReadingMode.scroll(direction: .ttb))
                }
                Picker("Default Page Direction", selection: Binding(
                    get: { store.defaultPageProgressionDirection },
                    set: { store.send(.defaultDirectionChanged($0)) }
                )) {
                    Text("Left to Right").tag(PageProgressionDirection.leftToRight)
                    Text("Right to Left").tag(PageProgressionDirection.rightToLeft)
                }
                Picker("App Language", selection: Binding(
                    get: { store.appLanguage },
                    set: {
                        store.send(.appLanguageChanged($0))
                        showingRestartAlert = true
                    }
                )) {
                    Text("System").tag(AppLanguage.system)
                    Text("English").tag(AppLanguage.en)
                    Text("한국어").tag(AppLanguage.ko)
                    Text("日本語").tag(AppLanguage.ja)
                }
            }

            Section("Reader Gestures") {
                Toggle("Tap Zones to Turn Pages", isOn: Binding(
                    get: { store.tapZonesEnabled },
                    set: { store.send(.tapZonesToggled($0)) }
                ))
                Toggle("Swipe to Turn Pages", isOn: Binding(
                    get: { store.swipeEnabled },
                    set: { store.send(.swipeToggled($0)) }
                ))
                Picker("Auto-hide Controls", selection: Binding(
                    get: { store.controlsAutoHideSeconds },
                    set: { store.send(.controlsAutoHideChanged($0)) }
                )) {
                    Text("3 seconds").tag(3.0 as Double)
                    Text("5 seconds").tag(5.0 as Double)
                    Text("Off").tag(0.0 as Double)
                }
            }
        }
        .navigationTitle("Settings")
        .task { await store.send(.task).finish() }
        .alert("Restart Mana", isPresented: $showingRestartAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Restart Mana to apply this change.")
        }
    }
}
