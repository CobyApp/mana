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

            // Title stays fixed under the header (Android keeps it outside the scroll area).
            header
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Tokens.Spacing.l)

            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Spacing.l) {
                    section(title: localized("settings.general")) {
                    settingRow(title: localized("settings.default_mode")) {
                        MangaToggle(
                            selection: Binding(
                                get: { store.defaultMode },
                                set: { store.send(.defaultModeChanged($0)) }
                            ),
                            options: [
                                (ReadingMode.single,  Text(verbatim: localized("mode.single"))),
                                (ReadingMode.dual,    Text(verbatim: localized("mode.dual"))),
                                (ReadingMode.webtoon, Text(verbatim: localized("mode.webtoon")))
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

                section(title: localized("settings.display")) {
                    settingRow(
                        title: localized("settings.lite_mode"),
                        footer: localized("settings.lite_mode.description")
                    ) {
                        MangaToggle(
                            selection: Binding(
                                get: { store.liteMode },
                                set: { store.send(.liteModeChanged($0)) }
                            ),
                            options: [
                                (false, Text(verbatim: localized("settings.off"))),
                                (true,  Text(verbatim: localized("settings.on")))
                            ]
                        )
                    }
                }

                section(title: localized("settings.about")) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(verbatim: localized("settings.version"))
                            .font(Tokens.Typography.caption)
                            .foregroundStyle(Tokens.Colors.ink.opacity(0.7))
                            .textCase(.uppercase)
                        Spacer()
                        Text(verbatim: Self.appVersion)
                            .font(Tokens.Typography.title)
                            .foregroundStyle(Tokens.Colors.ink)
                    }
                }

                section(title: localized("settings.danger_zone"), accent: Tokens.Colors.accent) {
                    settingRow(
                        title: localized("settings.reset_library"),
                        footer: localized("settings.reset_footer")
                    ) {
                        Button {
                            store.send(.resetLibraryRequested)
                        } label: {
                            HStack(spacing: Tokens.Spacing.s) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text(verbatim: localized("settings.reset_confirm"))
                                    .font(Tokens.Typography.title)
                            }
                            .foregroundStyle(Tokens.Colors.paper)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Tokens.Colors.accent)
                            .overlay(Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: Tokens.Stroke.bold))
                            .background(Rectangle().fill(Tokens.Colors.ink).offset(x: 4, y: 5))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(MangaPressStyle(haptic: .longPress))
                    }
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
        .overlay {
            MangaDialogHost(
                isPresented: store.isResetConfirmPresented,
                onDismiss: { store.send(.resetConfirmDismissed) }
            ) {
                MangaDialogPanel(
                    title: localized("settings.reset_title"),
                    message: localized("settings.reset_message"),
                    cancelTitle: localized("settings.cancel"),
                    confirmTitle: localized("settings.reset_confirm"),
                    onCancel: { store.send(.resetConfirmDismissed) },
                    onConfirm: { store.send(.resetConfirmed) }
                )
            }
        }
    }

    static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String
        return build.map { "\(version) (\($0))" } ?? version
    }

    private var backHeader: some View {
        HStack(spacing: Tokens.Spacing.s) {
            Button { dismiss() } label: {
                MangaIconBadge(systemName: "chevron.left")
            }
            .buttonStyle(MangaPressStyle())
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
