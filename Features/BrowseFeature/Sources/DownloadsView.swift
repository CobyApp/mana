import SwiftUI
import ComposableArchitecture
import Domain
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

public struct DownloadsView: View {
    @Bindable public var store: StoreOf<DownloadsFeature>
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss

    public init(store: StoreOf<DownloadsFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            BrowseChromeHeader(onBack: { dismiss() }) {
                if !store.entries.isEmpty {
                    Button { store.send(.togglePause) } label: {
                        MangaIconBadge(systemName: store.paused ? "play.fill" : "pause.fill", isAccent: store.paused)
                    }
                    .buttonStyle(MangaPressStyle(haptic: .tick))
                    Button { store.send(.cancelAll) } label: {
                        MangaTextBadge(text: Text(verbatim: localized("downloads.cancel_all")))
                    }
                    .buttonStyle(MangaPressStyle())
                }
            }
            BrowseChromeTitle(
                title: localized("downloads.title"),
                subtitle: store.paused ? localized("downloads.paused") : "\(store.entries.count)"
            )
            if store.entries.isEmpty {
                BrowseCenterHint(text: localized("downloads.empty"))
            } else {
                ScrollView {
                    LazyVStack(spacing: Tokens.Spacing.s) {
                        ForEach(store.entries) { entry in
                            row(entry)
                        }
                    }
                    .padding(Tokens.Spacing.m)
                }
            }
        }
        .browseScreenChrome()
        .task { await store.send(.task).finish() }
    }

    private func row(_ entry: DownloadEntry) -> some View {
        HStack(spacing: Tokens.Spacing.m) {
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: entry.seriesTitle)
                    .font(Tokens.Typography.caption)
                    .foregroundStyle(Tokens.Colors.accent)
                    .lineLimit(1)
                Text(verbatim: entry.chapterName)
                    .font(Tokens.Typography.title)
                    .foregroundStyle(Tokens.Colors.ink)
                    .lineLimit(1)
                Spacer().frame(height: 6)
                status(entry.status)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button { store.send(.cancel(entry.chapterURL)) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Tokens.Colors.ink)
                    .frame(width: 36, height: 36)
                    .background(Tokens.Colors.paper)
                    .overlay(Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: 1.5))
                    .contentShape(Rectangle())
            }
            .buttonStyle(MangaPressStyle())
        }
        .padding(Tokens.Spacing.m)
        .background(Tokens.Colors.paper)
        .overlay(Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: Tokens.Stroke.regular))
    }

    @ViewBuilder
    private func status(_ status: ChapterDownloadStatus) -> some View {
        switch status {
        case .queued:
            statusText(localized("downloads.queued"), color: Tokens.Colors.ink.opacity(0.6))
        case let .running(done, total):
            DownloadProgressBar(fraction: total > 0 ? Double(done) / Double(total) : nil)
            Spacer().frame(height: 4)
            statusText(
                total > 0 ? "\(done) / \(total)" : localized("downloads.preparing"),
                color: Tokens.Colors.ink.opacity(0.7)
            )
        case .failed:
            statusText(localized("downloads.failed"), color: Tokens.Colors.accent)
        }
    }

    private func statusText(_ text: String, color: Color) -> some View {
        Text(verbatim: text)
            .font(Tokens.Typography.mono)
            .foregroundStyle(color)
    }

    private func localized(_ key: String) -> String { Bundle.module.localized(key, for: locale) }
}

/// 8pt bar: 18% ink track, accent fill. `nil` fraction = indeterminate (static 30% like Android).
struct DownloadProgressBar: View {
    let fraction: Double?

    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(Tokens.Colors.accent)
                .frame(width: geo.size.width * CGFloat(fraction.map { min(1, max(0.02, $0)) } ?? 0.3))
        }
        .frame(height: 8)
        .frame(maxWidth: .infinity)
        .background(Tokens.Colors.ink.opacity(0.18))
    }
}
