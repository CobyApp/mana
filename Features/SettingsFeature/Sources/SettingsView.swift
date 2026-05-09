import SwiftUI
import ComposableArchitecture
import Domain
import DesignSystem

public struct SettingsView: View {
    @Bindable public var store: StoreOf<SettingsFeature>
    @State private var showingRestartAlert = false

    public init(store: StoreOf<SettingsFeature>) { self.store = store }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Spacing.l) {
                header

                section(titleKey: "settings.general") {
                    settingRow("settings.default_mode") {
                        MangaToggle(
                            selection: Binding(
                                get: { store.defaultMode },
                                set: { store.send(.defaultModeChanged($0)) }
                            ),
                            options: [
                                (ReadingMode.single, Text("mode.single", bundle: .module)),
                                (ReadingMode.dual,   Text("mode.dual",   bundle: .module))
                            ]
                        )
                    }

                    settingRow("settings.default_direction") {
                        MangaToggle(
                            selection: Binding(
                                get: { store.defaultPageProgressionDirection },
                                set: { store.send(.defaultDirectionChanged($0)) }
                            ),
                            options: [
                                (PageProgressionDirection.leftToRight, Text("direction.ltr", bundle: .module)),
                                (PageProgressionDirection.rightToLeft, Text("direction.rtl", bundle: .module))
                            ]
                        )
                    }

                    settingRow("settings.app_language") {
                        MangaToggle(
                            selection: Binding(
                                get: { store.appLanguage },
                                set: {
                                    store.send(.appLanguageChanged($0))
                                    showingRestartAlert = true
                                }
                            ),
                            options: [
                                (AppLanguage.ko, Text("language.ko", bundle: .module)),
                                (AppLanguage.ja, Text("language.ja", bundle: .module)),
                                (AppLanguage.en, Text("language.en", bundle: .module))
                            ]
                        )
                    }
                }

                section(titleKey: "settings.danger_zone", accent: Tokens.Colors.accent) {
                    Button(role: .destructive) {
                        store.send(.resetLibraryRequested)
                    } label: {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text("settings.reset_library", bundle: .module)
                                .font(Tokens.Typography.title)
                            Spacer()
                        }
                        .foregroundStyle(Tokens.Colors.paper)
                        .padding(.horizontal, Tokens.Spacing.m)
                        .padding(.vertical, Tokens.Spacing.s)
                        .background(Tokens.Colors.accent)
                        .overlay(Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: Tokens.Stroke.bold))
                    }
                    .buttonStyle(.plain)

                    Text("settings.reset_footer", bundle: .module)
                        .font(Tokens.Typography.caption)
                        .foregroundStyle(Tokens.Colors.ink.opacity(0.7))
                }
            }
            .padding(Tokens.Spacing.l)
        }
        .background(
            ZStack {
                Tokens.Colors.paper
                HalftoneBackground().opacity(0.6)
            }
            .ignoresSafeArea()
        )
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Tokens.Colors.paper, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task { await store.send(.task).finish() }
        .alert(Text("settings.restart_title", bundle: .module), isPresented: $showingRestartAlert) {
            Button(role: .cancel) {} label: { Text("settings.ok", bundle: .module) }
        } message: {
            Text("settings.restart_required", bundle: .module)
        }
        .alert($store.scope(state: \.resetAlert, action: \.resetAlert))
    }

    private var header: some View {
        SoundEffectText(
            "SETTINGS",
            font: Tokens.Typography.displayL,
            fill: Tokens.Colors.accent,
            stroke: Tokens.Colors.ink,
            strokeWidth: 5,
            tilt: -3,
            shadowOffset: .init(width: 4, height: 5)
        )
        .padding(.bottom, Tokens.Spacing.s)
    }

    @ViewBuilder
    private func section<Content: View>(
        titleKey: String.LocalizationValue,
        accent: Color = Tokens.Colors.ink,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.m) {
            HStack(spacing: Tokens.Spacing.s) {
                Rectangle()
                    .fill(accent)
                    .frame(width: 14, height: 14)
                Text(String(localized: titleKey, bundle: .module))
                    .font(Tokens.Typography.subtitle)
                    .foregroundStyle(Tokens.Colors.ink)
                    .textCase(.uppercase)
                Rectangle()
                    .fill(Tokens.Colors.ink)
                    .frame(height: 2)
            }

            VStack(alignment: .leading, spacing: Tokens.Spacing.m) {
                content()
            }
            .padding(Tokens.Spacing.m)
            .background(Tokens.Colors.paper)
            .overlay(Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: Tokens.Stroke.regular))
            .background(Tokens.Colors.ink.offset(x: 4, y: 5))
        }
    }

    @ViewBuilder
    private func settingRow<Content: View>(
        _ titleKey: String.LocalizationValue,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: titleKey, bundle: .module))
                .font(Tokens.Typography.caption)
                .foregroundStyle(Tokens.Colors.ink.opacity(0.7))
                .textCase(.uppercase)
            content()
        }
    }
}
