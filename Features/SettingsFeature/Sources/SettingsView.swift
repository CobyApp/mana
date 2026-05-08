import SwiftUI
import ComposableArchitecture
import Domain

public struct SettingsView: View {
    @Bindable public var store: StoreOf<SettingsFeature>

    public init(store: StoreOf<SettingsFeature>) { self.store = store }

    public var body: some View {
        Form {
            Section("Default reading mode") {
                Picker("Mode", selection: Binding(
                    get: { store.defaultMode },
                    set: { store.send(.defaultModeChanged($0)) }
                )) {
                    Text("Single").tag(ReadingMode.single)
                    Text("Dual").tag(ReadingMode.dual)
                    Text("Scroll LTR").tag(ReadingMode.scroll(direction: .ltr))
                    Text("Scroll RTL").tag(ReadingMode.scroll(direction: .rtl))
                    Text("Scroll TTB (Webtoon)").tag(ReadingMode.scroll(direction: .ttb))
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .navigationTitle("Settings")
        .task { await store.send(.task).finish() }
    }
}
