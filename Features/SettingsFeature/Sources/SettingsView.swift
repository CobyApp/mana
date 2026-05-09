import SwiftUI
import ComposableArchitecture
import Domain

public struct SettingsView: View {
    @Bindable public var store: StoreOf<SettingsFeature>
    @State private var showingRestartAlert = false

    public init(store: StoreOf<SettingsFeature>) { self.store = store }

    public var body: some View {
        Form {
            Section(LocalizedStringKey("settings.general")) {
                Picker(LocalizedStringKey("settings.default_mode"), selection: Binding(
                    get: { store.defaultMode },
                    set: { store.send(.defaultModeChanged($0)) }
                )) {
                    Text(LocalizedStringKey("mode.single")).tag(ReadingMode.single)
                    Text(LocalizedStringKey("mode.dual")).tag(ReadingMode.dual)
                    Text(LocalizedStringKey("mode.scroll.ltr")).tag(ReadingMode.scroll(direction: .ltr))
                    Text(LocalizedStringKey("mode.scroll.rtl")).tag(ReadingMode.scroll(direction: .rtl))
                    Text(LocalizedStringKey("mode.scroll.ttb")).tag(ReadingMode.scroll(direction: .ttb))
                }
                Picker(LocalizedStringKey("settings.default_direction"), selection: Binding(
                    get: { store.defaultPageProgressionDirection },
                    set: { store.send(.defaultDirectionChanged($0)) }
                )) {
                    Text(LocalizedStringKey("direction.ltr")).tag(PageProgressionDirection.leftToRight)
                    Text(LocalizedStringKey("direction.rtl")).tag(PageProgressionDirection.rightToLeft)
                }
                Picker(LocalizedStringKey("settings.app_language"), selection: Binding(
                    get: { store.appLanguage },
                    set: {
                        store.send(.appLanguageChanged($0))
                        showingRestartAlert = true
                    }
                )) {
                    Text(LocalizedStringKey("language.system")).tag(AppLanguage.system)
                    Text(LocalizedStringKey("language.en")).tag(AppLanguage.en)
                    Text(LocalizedStringKey("language.ko")).tag(AppLanguage.ko)
                    Text(LocalizedStringKey("language.ja")).tag(AppLanguage.ja)
                }
            }

            Section(LocalizedStringKey("settings.gestures")) {
                Toggle(LocalizedStringKey("settings.tap_zones"), isOn: Binding(
                    get: { store.tapZonesEnabled },
                    set: { store.send(.tapZonesToggled($0)) }
                ))
                Toggle(LocalizedStringKey("settings.swipe"), isOn: Binding(
                    get: { store.swipeEnabled },
                    set: { store.send(.swipeToggled($0)) }
                ))
                Picker(LocalizedStringKey("settings.auto_hide"), selection: Binding(
                    get: { store.controlsAutoHideSeconds },
                    set: { store.send(.controlsAutoHideChanged($0)) }
                )) {
                    Text(LocalizedStringKey("settings.auto_hide.3")).tag(3.0 as Double)
                    Text(LocalizedStringKey("settings.auto_hide.5")).tag(5.0 as Double)
                    Text(LocalizedStringKey("settings.auto_hide.off")).tag(0.0 as Double)
                }
            }
        }
        .navigationTitle(Text("settings.title", bundle: .module))
        .task { await store.send(.task).finish() }
        .alert(LocalizedStringKey("settings.restart_title"), isPresented: $showingRestartAlert) {
            Button(LocalizedStringKey("settings.ok"), role: .cancel) {}
        } message: {
            Text(LocalizedStringKey("settings.restart_required"))
        }
    }
}
