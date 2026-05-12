import SwiftUI
import ComposableArchitecture
import Domain
import DesignSystem

private extension Bundle {
    /// Looks up a localized string for a specific `Locale` by loading the matching
    /// `.lproj` sub-bundle directly. Use this when the SwiftUI environment locale
    /// needs to drive strings resolution but you can't pass a `Text` (e.g. when the
    /// consumer requires a plain `String`).
    func localized(_ key: String, for locale: Locale) -> String {
        let langCode = locale.language.languageCode?.identifier ?? "en"
        if let path = path(forResource: langCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: key, value: nil, table: nil)
        }
        return localizedString(forKey: key, value: nil, table: nil)
    }
}

public struct SettingsView: View {
    @Bindable public var store: StoreOf<SettingsFeature>
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    public init(store: StoreOf<SettingsFeature>) { self.store = store }

    public var body: some View {
        VStack(spacing: 0) {
            backHeader
                .padding(.horizontal, Tokens.Spacing.l)
                .padding(.top, Tokens.Spacing.s)
                .padding(.bottom, Tokens.Spacing.s)

            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Spacing.l) {
                    header

                    section(title: localized("settings.general")) {
                    settingRow(title: localized("settings.default_mode")) {
                        MangaToggle(
                            selection: Binding(
                                get: { store.defaultMode },
                                set: { store.send(.defaultModeChanged($0)) }
                            ),
                            options: [
                                (ReadingMode.single, Text(verbatim: localized("mode.single"))),
                                (ReadingMode.dual,   Text(verbatim: localized("mode.dual")))
                            ]
                        )
                    }

                    settingRow(title: localized("settings.default_direction")) {
                        MangaToggle(
                            selection: Binding(
                                get: { store.defaultPageProgressionDirection },
                                set: { store.send(.defaultDirectionChanged($0)) }
                            ),
                            options: [
                                (PageProgressionDirection.leftToRight, Text(verbatim: localized("direction.ltr"))),
                                (PageProgressionDirection.rightToLeft, Text(verbatim: localized("direction.rtl")))
                            ]
                        )
                    }

                    settingRow(
                        title: localized("settings.first_page_solo"),
                        footer: localized("settings.first_page_solo_footer")
                    ) {
                        MangaToggle(
                            selection: Binding(
                                get: { store.defaultPageOffset },
                                set: { store.send(.defaultPageOffsetChanged($0)) }
                            ),
                            options: [
                                (false, Text(verbatim: localized("settings.first_page_solo.off"))),
                                (true,  Text(verbatim: localized("settings.first_page_solo.on")))
                            ]
                        )
                    }

                    settingRow(title: localized("settings.app_language")) {
                        MangaToggle(
                            selection: Binding(
                                get: { store.appLanguage },
                                set: { store.send(.appLanguageChanged($0)) }
                            ),
                            options: [
                                (AppLanguage.system, Text(verbatim: localized("language.system"))),
                                (AppLanguage.ko, Text(verbatim: localized("language.ko"))),
                                (AppLanguage.ja, Text(verbatim: localized("language.ja"))),
                                (AppLanguage.en, Text(verbatim: localized("language.en")))
                            ]
                        )
                    }
                }

                section(title: localized("settings.danger_zone"), accent: Tokens.Colors.accent) {
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
        }
        .background(
            ZStack {
                Tokens.Colors.paper
                HalftoneBackground().opacity(0.6)
            }
            .ignoresSafeArea()
        )
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .task { await store.send(.task).finish() }
        .alert($store.scope(state: \.resetAlert, action: \.resetAlert))
    }

    private var backHeader: some View {
        HStack(spacing: Tokens.Spacing.s) {
            Button { dismiss() } label: {
                MangaIconBadge(systemName: "chevron.left")
            }
            .buttonStyle(.plain)
            Spacer()
        }
    }

    private var header: some View {
        SoundEffectText(
            Bundle.module.localized("settings.title", for: locale).uppercased(),
            font: Tokens.Typography.displayL,
            fill: Tokens.Colors.accent,
            stroke: Tokens.Colors.ink,
            strokeWidth: 5,
            tilt: -3,
            shadowOffset: .init(width: 4, height: 5)
        )
        .padding(.bottom, Tokens.Spacing.s)
    }

    private func localized(_ key: String) -> String {
        Bundle.module.localized(key, for: locale)
    }

    @ViewBuilder
    private func section<Content: View>(
        title: String,
        accent: Color = Tokens.Colors.ink,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.m) {
            HStack(spacing: Tokens.Spacing.s) {
                Rectangle()
                    .fill(accent)
                    .frame(width: 14, height: 14)
                Text(verbatim: title)
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
        title: String,
        footer: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: title)
                .font(Tokens.Typography.caption)
                .foregroundStyle(Tokens.Colors.ink.opacity(0.7))
                .textCase(.uppercase)
            content()
            if let footer {
                Text(verbatim: footer)
                    .font(Tokens.Typography.caption)
                    .foregroundStyle(Tokens.Colors.ink.opacity(0.6))
                    .padding(.top, 2)
            }
        }
    }
}
