import SwiftUI
import ComposableArchitecture
import Domain

public struct SettingsView: View {
    @Bindable public var store: StoreOf<SettingsFeature>
    @State private var showingRestartAlert = false

    public init(store: StoreOf<SettingsFeature>) { self.store = store }

    public var body: some View {
        Form {
            Section {
                Picker(selection: Binding(
                    get: { store.defaultMode },
                    set: { store.send(.defaultModeChanged($0)) }
                )) {
                    Text("mode.single", bundle: .module).tag(ReadingMode.single)
                    Text("mode.dual", bundle: .module).tag(ReadingMode.dual)
                } label: { Text("settings.default_mode", bundle: .module) }
                Picker(selection: Binding(
                    get: { store.defaultPageProgressionDirection },
                    set: { store.send(.defaultDirectionChanged($0)) }
                )) {
                    Text("direction.ltr", bundle: .module).tag(PageProgressionDirection.leftToRight)
                    Text("direction.rtl", bundle: .module).tag(PageProgressionDirection.rightToLeft)
                } label: { Text("settings.default_direction", bundle: .module) }
                Picker(selection: Binding(
                    get: { store.appLanguage },
                    set: {
                        store.send(.appLanguageChanged($0))
                        showingRestartAlert = true
                    }
                )) {
                    Text("language.system", bundle: .module).tag(AppLanguage.system)
                    Text("language.en", bundle: .module).tag(AppLanguage.en)
                    Text("language.ko", bundle: .module).tag(AppLanguage.ko)
                    Text("language.ja", bundle: .module).tag(AppLanguage.ja)
                } label: { Text("settings.app_language", bundle: .module) }
            } header: { Text("settings.general", bundle: .module) }

            Section {
                Button(role: .destructive) {
                    store.send(.resetLibraryRequested)
                } label: {
                    Text("settings.reset_library", bundle: .module)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("settings.danger_zone", bundle: .module)
            } footer: {
                Text("settings.reset_footer", bundle: .module)
            }
        }
        .navigationTitle(Text("settings.title", bundle: .module))
        .task { await store.send(.task).finish() }
        .alert(Text("settings.restart_title", bundle: .module), isPresented: $showingRestartAlert) {
            Button(role: .cancel) {} label: { Text("settings.ok", bundle: .module) }
        } message: {
            Text("settings.restart_required", bundle: .module)
        }
        .alert($store.scope(state: \.resetAlert, action: \.resetAlert))
    }
}
