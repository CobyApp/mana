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
            Color.clear
                .frame(width: 120, height: 180)
                .overlay { SourceImage(url: store.detail?.coverURL ?? store.preview?.coverURL, headers: store.imageHeaders) }
                .clipped()
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
                actionsBar(chapters)
                // Newest first for browsing convenience.
                ForEach(chapters.reversed()) { chapter in
                    chapterRow(chapter)
                    Rectangle().fill(Tokens.Colors.ink.opacity(0.1)).frame(height: 1).padding(.horizontal, 16)
                }
            }
        }
    }

    @ViewBuilder
    private func actionsBar(_ chapters: [SourceChapter]) -> some View {
        HStack(spacing: 10) {
            Text(verbatim: localized("detail.chapters")).font(Tokens.Typography.subtitle).foregroundStyle(Tokens.Colors.ink)
            Spacer()
            if store.selectionMode {
                Button { store.send(.selectAll) } label: { pill(localized("detail.select_all"), accent: false) }.buttonStyle(.plain)
                Button { store.send(.downloadSelected) } label: { pill(localized("detail.download_selected"), accent: true) }.buttonStyle(.plain)
                Button { store.send(.clearSelection) } label: { pill(localized("detail.cancel"), accent: false) }.buttonStyle(.plain)
            } else {
                let pending = chapters.filter { !store.downloaded.contains($0.url) && store.downloading[$0.url] == nil }.count
                if pending > 0 {
                    Button { store.send(.downloadAll) } label: { pill("\(localized("detail.download_all")) (\(pending))", accent: true) }.buttonStyle(.plain)
                }
                Button { store.send(.enterSelection) } label: { pill(localized("detail.select"), accent: false) }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16).padding(.bottom, 8)
    }

    @ViewBuilder
    private func chapterRow(_ chapter: SourceChapter) -> some View {
        let isDownloaded = store.downloaded.contains(chapter.url)
        let progress = store.downloading[chapter.url]
        let isFailed = store.failed.contains(chapter.url)
        let isRead = store.read.contains(chapter.url)
        let isSelected = store.selected.contains(chapter.url)

        Button {
            if store.selectionMode { store.send(.toggleSelect(chapter)) }
            else { store.send(.chapterTapped(chapter)) }
        } label: {
            HStack(spacing: 10) {
                if store.selectionMode {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .foregroundStyle(isSelected ? Tokens.Colors.accent : Tokens.Colors.ink.opacity(0.4))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: chapter.name)
                        .font(Tokens.Typography.body)
                        .foregroundStyle((isDownloaded || isRead) ? Tokens.Colors.ink.opacity(0.5) : Tokens.Colors.ink)
                    if isRead && !isDownloaded {
                        Text(verbatim: localized("detail.read")).font(Tokens.Typography.caption).foregroundStyle(Tokens.Colors.ink.opacity(0.4))
                    }
                }
                Spacer()
                if !store.selectionMode { trailing(chapter, isDownloaded: isDownloaded, progress: progress, isFailed: isFailed) }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func trailing(_ chapter: SourceChapter, isDownloaded: Bool, progress: ChapterProgress?, isFailed: Bool) -> some View {
        if isDownloaded {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 20)).foregroundStyle(Tokens.Colors.ink)
        } else if let progress {
            Button { store.send(.cancelChapter(chapter)) } label: {
                HStack(spacing: 6) {
                    if progress.total > 0 {
                        Text(verbatim: "\(progress.done)/\(progress.total)").font(Tokens.Typography.caption).foregroundStyle(Tokens.Colors.ink.opacity(0.6))
                    }
                    Image(systemName: "xmark.circle").font(.system(size: 18)).foregroundStyle(Tokens.Colors.ink.opacity(0.6))
                }
            }
            .buttonStyle(.plain)
        } else {
            Button { store.send(.downloadChapter(chapter)) } label: {
                Image(systemName: isFailed ? "exclamationmark.arrow.circlepath" : "arrow.down.circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isFailed ? Tokens.Colors.accent : Tokens.Colors.accent)
            }
            .buttonStyle(.plain)
        }
    }

    private func pill(_ text: String, accent: Bool) -> some View {
        Text(verbatim: text)
            .font(Tokens.Typography.caption)
            .foregroundStyle(accent ? Tokens.Colors.paper : Tokens.Colors.ink)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(accent ? Tokens.Colors.ink : Tokens.Colors.paper)
            .overlay(Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: 1.2))
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
