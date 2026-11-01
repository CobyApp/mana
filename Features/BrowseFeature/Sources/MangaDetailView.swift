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

public struct MangaDetailView: View {
    @Bindable public var store: StoreOf<MangaDetailFeature>
    @Environment(\.locale) private var locale

    public init(store: StoreOf<MangaDetailFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            Tokens.Colors.paper.ignoresSafeArea()
            if store.loading && store.detail == nil {
                ProgressView().tint(Tokens.Colors.accent)
            } else if store.error && store.detail == nil {
                errorState
            } else {
                content
            }
        }
        .navigationTitle(Text(verbatim: store.detail?.title ?? store.preview?.title ?? ""))
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.send(.task).finish() }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if let synopsis = store.detail?.synopsis, !synopsis.isEmpty {
                    Text(verbatim: synopsis)
                        .font(Tokens.Typography.body)
                        .foregroundStyle(Tokens.Colors.ink.opacity(0.85))
                        .padding(.horizontal, 16)
                }
                if let genres = store.detail?.genres, !genres.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(genres) { g in
                                Text(verbatim: g.name)
                                    .font(Tokens.Typography.caption)
                                    .foregroundStyle(Tokens.Colors.ink)
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .overlay(Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: 1.2))
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                chapterList
            }
            .padding(.vertical, 16)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            SourceImage(url: store.detail?.coverURL ?? store.preview?.coverURL, headers: store.imageHeaders)
                .aspectRatio(2.0 / 3.0, contentMode: .fit)
                .frame(width: 120)
                .overlay(Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: 2))
            VStack(alignment: .leading, spacing: 8) {
                Text(verbatim: store.detail?.title ?? store.preview?.title ?? "")
                    .font(Tokens.Typography.title)
                    .foregroundStyle(Tokens.Colors.ink)
                if let count = store.detail?.chapters.count {
                    Text(verbatim: "\(count) " + localized("detail.chapters"))
                        .font(Tokens.Typography.caption)
                        .foregroundStyle(Tokens.Colors.ink.opacity(0.6))
                }
                Spacer()
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var chapterList: some View {
        if let chapters = store.detail?.chapters, !chapters.isEmpty {
            VStack(spacing: 0) {
                HStack {
                    Text(verbatim: localized("detail.chapters")).font(Tokens.Typography.subtitle).foregroundStyle(Tokens.Colors.ink)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.bottom, 6)
                // Newest first for browsing convenience.
                ForEach(chapters.reversed()) { chapter in
                    Button { store.send(.chapterTapped(chapter)) } label: {
                        HStack {
                            Text(verbatim: chapter.name)
                                .font(Tokens.Typography.body)
                                .foregroundStyle(Tokens.Colors.ink)
                            Spacer()
                            Button { store.send(.downloadChapter(chapter)) } label: {
                                Image(systemName: "arrow.down.circle")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(Tokens.Colors.accent)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Rectangle().fill(Tokens.Colors.ink.opacity(0.1)).frame(height: 1).padding(.horizontal, 16)
                }
            }
        }
    }

    private var errorState: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark").font(.system(size: 40, weight: .bold)).foregroundStyle(Tokens.Colors.accent)
            Text(verbatim: localized("detail.error")).font(Tokens.Typography.subtitle).foregroundStyle(Tokens.Colors.ink.opacity(0.7))
            Button { store.send(.retry) } label: {
                Text(verbatim: localized("detail.retry"))
                    .font(Tokens.Typography.subtitle).foregroundStyle(Tokens.Colors.paper)
                    .padding(.horizontal, 20).padding(.vertical, 10).background(Tokens.Colors.ink)
            }
            .buttonStyle(.plain)
        }
    }

    private func localized(_ key: String) -> String { Bundle.module.localized(key, for: locale) }
}
