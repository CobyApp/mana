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

    public init(store: StoreOf<DownloadsFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            Tokens.Colors.paper.ignoresSafeArea()
            if store.entries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "arrow.down.circle").font(.system(size: 40, weight: .bold)).foregroundStyle(Tokens.Colors.ink.opacity(0.3))
                    Text(verbatim: localized("downloads.empty")).font(Tokens.Typography.subtitle).foregroundStyle(Tokens.Colors.ink.opacity(0.6))
                }
            } else {
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Button { store.send(.togglePause) } label: {
                            pill(localized(store.paused ? "downloads.resume" : "downloads.pause"), accent: true)
                        }.buttonStyle(.plain)
                        Button { store.send(.cancelAll) } label: {
                            pill(localized("downloads.cancel_all"), accent: false)
                        }.buttonStyle(.plain)
                        Spacer()
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(store.entries) { entry in
                                row(entry)
                                Rectangle().fill(Tokens.Colors.ink.opacity(0.1)).frame(height: 1).padding(.horizontal, 16)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(Text(verbatim: localized("downloads.title")))
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.send(.task).finish() }
    }

    private func row(_ entry: DownloadEntry) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: entry.seriesTitle).font(Tokens.Typography.caption).foregroundStyle(Tokens.Colors.ink.opacity(0.6)).lineLimit(1)
                Text(verbatim: entry.chapterName).font(Tokens.Typography.body).foregroundStyle(Tokens.Colors.ink).lineLimit(1)
                Text(verbatim: statusText(entry.status)).font(Tokens.Typography.caption).foregroundStyle(Tokens.Colors.ink.opacity(0.5))
            }
            Spacer()
            Button { store.send(.cancel(entry.chapterURL)) } label: {
                Image(systemName: "xmark.circle").font(.system(size: 20)).foregroundStyle(Tokens.Colors.ink.opacity(0.6))
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private func statusText(_ status: ChapterDownloadStatus) -> String {
        switch status {
        case .queued: return localized("downloads.queued")
        case let .running(done, total): return total > 0 ? "\(done)/\(total)" : "…"
        case .failed: return "⚠︎"
        }
    }

    private func pill(_ text: String, accent: Bool) -> some View {
        Text(verbatim: text)
            .font(Tokens.Typography.caption)
            .foregroundStyle(accent ? Tokens.Colors.paper : Tokens.Colors.ink)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(accent ? Tokens.Colors.ink : Tokens.Colors.paper)
            .overlay(Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: 1.2))
    }

    private func localized(_ key: String) -> String { Bundle.module.localized(key, for: locale) }
}
