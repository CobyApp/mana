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

public struct BrowseView: View {
    @Bindable public var store: StoreOf<BrowseFeature>
    @Environment(\.locale) private var locale

    public init(store: StoreOf<BrowseFeature>) {
        self.store = store
    }

    private let columns = [GridItem(.adaptive(minimum: 110, maximum: 160), spacing: 12)]

    public var body: some View {
        ZStack {
            Tokens.Colors.paper.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                if store.searchQuery != nil {
                    searchResults
                } else {
                    switch store.tab {
                    case .latest: grid(items: store.items, isSearch: false)
                    case .genres: genresTab
                    }
                }
            }
        }
        .navigationTitle(Text(verbatim: localized("browse.title")))
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.send(.task).finish() }
    }

    @ViewBuilder
    private var header: some View {
        if store.searchQuery != nil {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Tokens.Colors.ink.opacity(0.5))
                TextField(
                    localized("browse.search.placeholder"),
                    text: Binding(get: { store.searchQuery ?? "" }, set: { store.send(.setQuery($0)) })
                )
                .autocorrectionDisabled()
                .submitLabel(.search)
                Button { store.send(.closeSearch) } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Tokens.Colors.ink.opacity(0.5))
                }
            }
            .padding(10)
            .background(Tokens.Colors.paper)
            .overlay(Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: 1.5))
            .padding(.horizontal, 16).padding(.vertical, 8)
        } else {
            HStack(spacing: 10) {
                tabButton(.latest, localized("browse.latest"))
                tabButton(.genres, localized("browse.genres"))
                Spacer()
                Button { store.send(.openSearch) } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Tokens.Colors.paper)
                        .frame(width: 38, height: 38)
                        .background(Tokens.Colors.ink)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
        }
    }

    private func tabButton(_ tab: BrowseTab, _ title: String) -> some View {
        Button { store.send(.selectTab(tab)) } label: {
            Text(verbatim: title)
                .font(Tokens.Typography.subtitle)
                .foregroundStyle(store.tab == tab ? Tokens.Colors.paper : Tokens.Colors.ink)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(store.tab == tab ? Tokens.Colors.ink : Tokens.Colors.paper)
                .overlay(Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var genresTab: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.genres) { genre in
                        Button { store.send(.selectGenre(genre)) } label: {
                            Text(verbatim: genre.name)
                                .font(Tokens.Typography.caption)
                                .foregroundStyle(store.selectedGenre?.slug == genre.slug ? Tokens.Colors.paper : Tokens.Colors.ink)
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(store.selectedGenre?.slug == genre.slug ? Tokens.Colors.accent : Tokens.Colors.paper)
                                .overlay(Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: 1.2))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
            }
            grid(items: store.items, isSearch: false)
        }
    }

    @ViewBuilder
    private var searchResults: some View {
        if store.searching && store.searchItems.isEmpty {
            loadingState
        } else if store.searchItems.isEmpty, !(store.searchQuery ?? "").isEmpty {
            emptyState
        } else {
            grid(items: store.searchItems, isSearch: true)
        }
    }

    @ViewBuilder
    private func grid(items: [SourceManga], isSearch: Bool) -> some View {
        if store.loading && items.isEmpty && !isSearch {
            loadingState
        } else if store.error && items.isEmpty {
            errorState
        } else if items.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(items) { manga in
                        cell(manga)
                            .onAppear {
                                if manga.url == items.last?.url {
                                    store.send(isSearch ? .loadMoreSearch : .loadMore)
                                }
                            }
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                if (isSearch ? store.searching : store.loadingMore) && !items.isEmpty {
                    ProgressView().tint(Tokens.Colors.accent).padding(.bottom, 16)
                }
            }
        }
    }

    private func cell(_ manga: SourceManga) -> some View {
        Button { store.send(.mangaTapped(manga)) } label: {
            VStack(alignment: .leading, spacing: 6) {
                SourceImage(url: manga.coverURL, headers: store.imageHeaders)
                    .aspectRatio(2.0 / 3.0, contentMode: .fit)
                    .overlay(Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: 1.5))
                Text(verbatim: manga.title)
                    .font(Tokens.Typography.caption)
                    .foregroundStyle(Tokens.Colors.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }

    private var loadingState: some View {
        VStack { Spacer(); ProgressView().tint(Tokens.Colors.accent); Spacer() }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "tray").font(.system(size: 40, weight: .bold)).foregroundStyle(Tokens.Colors.ink.opacity(0.3))
            Text(verbatim: localized("browse.empty")).font(Tokens.Typography.subtitle).foregroundStyle(Tokens.Colors.ink.opacity(0.6))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var errorState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "wifi.exclamationmark").font(.system(size: 40, weight: .bold)).foregroundStyle(Tokens.Colors.accent)
            Text(verbatim: localized("browse.error")).font(Tokens.Typography.subtitle).foregroundStyle(Tokens.Colors.ink.opacity(0.7))
            Button { store.send(.retry) } label: {
                Text(verbatim: localized("browse.retry"))
                    .font(Tokens.Typography.subtitle).foregroundStyle(Tokens.Colors.paper)
                    .padding(.horizontal, 20).padding(.vertical, 10).background(Tokens.Colors.ink)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func localized(_ key: String) -> String { Bundle.module.localized(key, for: locale) }
}
