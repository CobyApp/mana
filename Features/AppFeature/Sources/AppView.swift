import SwiftUI
import ComposableArchitecture
import BrowseFeature
import LibraryFeature
import ReaderFeature
import SettingsFeature
import DesignSystem

private extension Bundle {
    func localized(_ key: String, for locale: Locale) -> String {
        let langCode = locale.language.languageCode?.identifier ?? "en"
        if let path = path(forResource: langCode, ofType: "lproj"), let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: key, value: nil, table: nil)
        }
        return localizedString(forKey: key, value: nil, table: nil)
    }
}

public struct AppView: View {
    @Bindable public var store: StoreOf<AppFeature>

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            LibraryView(store: store.scope(state: \.library, action: \.library))
        } destination: { store in
            switch store.case {
            case let .reader(readerStore):
                ReaderView(store: readerStore)
            case let .settings(settingsStore):
                SettingsView(store: settingsStore)
            case let .browse(browseStore):
                BrowseView(store: browseStore)
            case let .mangaDetail(detailStore):
                MangaDetailView(store: detailStore)
            case let .downloads(downloadsStore):
                DownloadsView(store: downloadsStore)
            case let .onlineReader(onlineStore):
                OnlineReaderView(store: onlineStore)
            }
        }
        .overlay { resumeDownloadsDialog }
        .environment(\.locale, locale(for: store.appLanguage))
        .task { await store.send(.task).finish() }
        .onOpenURL { store.send(.openURL($0)) }
    }

    /// "Resume downloads?" — interrupted downloads wait for the user instead of auto-restarting.
    private var resumeDownloadsDialog: some View {
        let locale = locale(for: store.appLanguage)
        let text: (String) -> String = { Bundle.module.localized($0, for: locale) }
        return MangaDialogHost(
            isPresented: store.pendingResumeCount > 0,
            onDismiss: {}
        ) {
            MangaDialogPanel(
                title: text("resume_downloads.title"),
                message: String(format: text("resume_downloads.message"), store.pendingResumeCount),
                cancelTitle: text("resume_downloads.dismiss"),
                confirmTitle: text("resume_downloads.confirm"),
                onCancel: { store.send(.resumeDownloadsDismissed) },
                onConfirm: { store.send(.resumeDownloadsConfirmed) }
            )
        }
    }

    private func locale(for language: AppLanguage) -> Locale {
        switch language {
        case .system: return .autoupdatingCurrent
        case .ko, .ja, .en: return Locale(identifier: language.rawValue)
        }
    }
}
