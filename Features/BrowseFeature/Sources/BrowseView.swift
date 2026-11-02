import SwiftUI
import UIKit
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
    @Environment(\.dismiss) private var dismiss
    @FocusState private var searchFocused: Bool

    public init(store: StoreOf<BrowseFeature>) {
        self.store = store
    }

    /// Fixed 3 columns, 8pt horizontal gap (Android `GridCells.Fixed(3)`), rows top-aligned.
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8, alignment: .top), count: 3)

    public var body: some View {
        VStack(spacing: 0) {
            BrowseChromeHeader(onBack: { dismiss() }) {
                if store.searchQuery == nil {
                    Button { store.send(.openSearch) } label: {
                        MangaIconBadge(systemName: "magnifyingglass")
                    }
                    .buttonStyle(MangaPressStyle())
                }
            }
            if store.searchQuery != nil {
                searchField
                searchContent
            } else {
                BrowseChromeTitle(title: localized("browse.title"))
                tabRow
                if store.tab == .genres { genreChips }
                mainContent
            }
        }
        .browseScreenChrome()
        .task { await store.send(.task).finish() }
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Tokens.Colors.ink)
            TextField(
                "",
                text: Binding(get: { store.searchQuery ?? "" }, set: { store.send(.setQuery($0)) }),
                prompt: Text(verbatim: localized("browse.search.placeholder"))
                    .foregroundStyle(Tokens.Colors.ink.opacity(0.45))
            )
            .font(Tokens.Typography.body)
            .foregroundStyle(Tokens.Colors.ink)
            .tint(Tokens.Colors.accent)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .submitLabel(.search)
            .focused($searchFocused)
            Button { store.send(.closeSearch) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Tokens.Colors.ink)
                    .padding(4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(MangaPressStyle())
        }
        .padding(.horizontal, Tokens.Spacing.m)
        .padding(.vertical, Tokens.Spacing.s)
        .background(Tokens.Colors.paper)
        .overlay(Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: Tokens.Stroke.bold))
        .padding(.horizontal, Tokens.Spacing.m)
        .padding(.top, Tokens.Spacing.xs)
        .padding(.bottom, Tokens.Spacing.s)
        .task { searchFocused = true }
    }

    @ViewBuilder
    private var searchContent: some View {
        let query = (store.searchQuery ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if store.searching && store.searchItems.isEmpty {
            loader
        } else if query.isEmpty {
            BrowseCenterHint(text: localized("browse.search_hint"))
        } else if store.searchItems.isEmpty {
            BrowseCenterHint(text: localized("browse.empty"))
        } else {
            grid(items: store.searchItems, isSearch: true, resetKey: "search:\(query)")
        }
    }

    // MARK: - Tabs / genres

    private var tabRow: some View {
        HStack(spacing: Tokens.Spacing.s) {
            tabChip(.latest, localized("browse.latest"))
            tabChip(.genres, localized("browse.genres"))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Tokens.Spacing.m)
        .padding(.vertical, Tokens.Spacing.s)
    }

    private func tabChip(_ tab: BrowseTab, _ title: String) -> some View {
        let selected = store.tab == tab
        return Button { store.send(.selectTab(tab)) } label: {
            Text(verbatim: title)
                .font(Tokens.Typography.title)
                .foregroundStyle(selected ? Tokens.Colors.paper : Tokens.Colors.ink)
                .padding(.horizontal, Tokens.Spacing.m)
                .padding(.vertical, Tokens.Spacing.xs)
                .background(selected ? Tokens.Colors.accent : Tokens.Colors.paper)
                .overlay(Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: Tokens.Stroke.regular))
                .contentShape(Rectangle())
        }
        .buttonStyle(MangaPressStyle())
    }

    private var genreChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Tokens.Spacing.s) {
                ForEach(store.genres) { genre in
                    let selected = store.selectedGenre?.slug == genre.slug
                    Button { store.send(.selectGenre(genre)) } label: {
                        Text(verbatim: genre.name)
                            .font(Tokens.Typography.caption)
                            .foregroundStyle(selected ? Tokens.Colors.paper : Tokens.Colors.ink)
                            .padding(.horizontal, Tokens.Spacing.s)
                            .padding(.vertical, 6)
                            .background(selected ? Tokens.Colors.accent : Tokens.Colors.paper)
                            .overlay(Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: Tokens.Stroke.regular))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(MangaPressStyle())
                }
            }
            .padding(.horizontal, Tokens.Spacing.m)
            .padding(.vertical, 2)
        }
        .padding(.bottom, Tokens.Spacing.s)
    }

    // MARK: - Content

    @ViewBuilder
    private var mainContent: some View {
        if store.loading {
            loader
        } else if store.error {
            BrowseRetryBlock(title: localized("browse.error"), retryTitle: localized("browse.retry")) {
                store.send(.retry)
            }
        } else if store.tab == .genres && store.selectedGenre == nil {
            BrowseCenterHint(text: localized("browse.pick_genre"))
        } else if store.items.isEmpty {
            BrowseCenterHint(text: localized("browse.empty"))
        } else {
            grid(items: store.items, isSearch: false, resetKey: store.selectedGenre?.slug ?? "latest")
        }
    }

    private var loader: some View {
        ManaLoader()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func grid(items: [SourceManga], isSearch: Bool, resetKey: String) -> some View {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(Array(items.enumerated()), id: \.element.url) { index, manga in
                    cell(manga)
                        .onAppear {
                            // Paginate once an item within 4 of the end comes on screen.
                            if index >= items.count - 4 {
                                store.send(isSearch ? .loadMoreSearch : .loadMore)
                            }
                        }
                }
            }
            .padding(Tokens.Spacing.m)
            if (isSearch ? store.searching : store.loadingMore) {
                ManaLoader(caption: nil, panelSize: 12)
                    .padding(.bottom, Tokens.Spacing.l)
            }
        }
        // A new list identity (genre switch / new query) starts back at the top.
        .id(resetKey)
    }

    private func cell(_ manga: SourceManga) -> some View {
        Button { store.send(.mangaTapped(manga)) } label: {
            VStack(alignment: .leading, spacing: 6) {
                // Library-style panel: per-item tilt, panel stroke, hard offset shadow.
                MangaPanel(surface: .paper, tiltIndex: stableTiltIndex(manga.url), strokeWidth: Tokens.Stroke.panel) {
                    // Fixed 0.7 frame; the cover fills it and is cropped so wide art can't overflow.
                    Color.clear
                        .aspectRatio(0.7, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .overlay { SourceImage(url: manga.coverURL, headers: store.imageHeaders) }
                        .clipped()
                }
                Text(verbatim: manga.title)
                    .font(Tokens.Typography.caption)
                    .foregroundStyle(Tokens.Colors.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.trailing, 4)   // breathing room for the offset ink shadow
            .padding(.bottom, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(MangaPressStyle())
    }

    /// Deterministic (launch-stable) hash so a cover keeps its tilt across reloads.
    private func stableTiltIndex(_ url: String) -> Int {
        var h: UInt32 = 5381
        for b in url.utf8 { h = (h &* 33) &+ UInt32(b) }
        return Int(h % 1024)
    }

    private func localized(_ key: String) -> String { Bundle.module.localized(key, for: locale) }
}

// MARK: - Shared Browse chrome (used by Browse / Detail / Downloads)

/// Android `ManaHeaderBar`: 48pt row at the 16pt gutter, back badge on the left, trailing controls right.
struct BrowseChromeHeader<Trailing: View>: View {
    let onBack: () -> Void
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: Tokens.Spacing.s) {
            Button(action: onBack) {
                MangaIconBadge(systemName: "chevron.left")
            }
            .buttonStyle(MangaPressStyle())
            Spacer(minLength: 0)
            trailing()
        }
        .frame(height: 48)
        .padding(.horizontal, Tokens.Spacing.m)
    }
}

/// Android `ManaTitle`: big tilted sound-effect title plus optional mono subtitle.
struct BrowseChromeTitle: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SoundEffectText(
                title.uppercased(),
                font: Tokens.Typography.displayL,
                fill: Tokens.Colors.accent,
                stroke: Tokens.Colors.ink,
                strokeWidth: 5,
                tilt: -3,
                shadowOffset: .init(width: 4, height: 5)
            )
            if let subtitle {
                Text(verbatim: subtitle)
                    .font(Tokens.Typography.mono)
                    .foregroundStyle(Tokens.Colors.ink.opacity(0.7))
                    .padding(.leading, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Tokens.Spacing.m)
        .padding(.top, Tokens.Spacing.xs)
        .padding(.bottom, Tokens.Spacing.s)
    }
}

/// Centered body-text hint / empty message.
struct BrowseCenterHint: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(Tokens.Typography.body)
            .foregroundStyle(Tokens.Colors.ink.opacity(0.7))
            .multilineTextAlignment(.center)
            .padding(.horizontal, Tokens.Spacing.m)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Android `RetryBlock`: big "COULDN'T LOAD." sound effect + bold-stroked accent Retry.
struct BrowseRetryBlock: View {
    let title: String
    let retryTitle: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            SoundEffectText(
                title.uppercased(),
                font: Tokens.Typography.displayM,
                fill: Tokens.Colors.accent,
                stroke: Tokens.Colors.ink,
                strokeWidth: 4,
                tilt: -3
            )
            .multilineTextAlignment(.center)
            Button(action: onRetry) {
                Text(verbatim: retryTitle)
                    .font(Tokens.Typography.title)
                    .foregroundStyle(Tokens.Colors.paper)
                    .padding(.horizontal, Tokens.Spacing.l)
                    .padding(.vertical, Tokens.Spacing.s)
                    .background(Tokens.Colors.accent)
                    .overlay(Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: Tokens.Stroke.bold))
                    .contentShape(Rectangle())
            }
            .buttonStyle(MangaPressStyle(haptic: .confirm))
        }
        .padding(.horizontal, Tokens.Spacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension View {
    /// Paper + halftone backdrop, system nav bar hidden (custom header instead), swipe-back kept alive.
    func browseScreenChrome() -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background {
                ZStack {
                    Tokens.Colors.paper
                    HalftoneBackground().opacity(0.7)
                }
                .ignoresSafeArea()
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarBackButtonHidden(true)
            .background(BrowseSwipeBackEnabler().frame(width: 0, height: 0))
    }
}

/// Hiding the nav bar / back button makes UIKit's default pop-gesture delegate refuse to begin.
/// While the hosting screen is visible, swap in a delegate that allows the edge swipe whenever
/// there's something to pop; the previous delegate is restored when the screen goes away.
struct BrowseSwipeBackEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Holder { Holder() }
    func updateUIViewController(_: Holder, context: Context) {}

    final class Holder: UIViewController {
        private weak var previousDelegate: (any UIGestureRecognizerDelegate)?
        private var installed = false

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard let nav = navigationController, let recognizer = nav.interactivePopGestureRecognizer else { return }
            if !(recognizer.delegate is BrowsePopGestureDelegate) {
                previousDelegate = recognizer.delegate
            }
            BrowsePopGestureDelegate.shared.navigationController = nav
            recognizer.delegate = BrowsePopGestureDelegate.shared
            installed = true
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            guard installed, let recognizer = navigationController?.interactivePopGestureRecognizer else { return }
            if recognizer.delegate === BrowsePopGestureDelegate.shared {
                recognizer.delegate = previousDelegate
            }
            installed = false
        }
    }
}

@MainActor
final class BrowsePopGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    static let shared = BrowsePopGestureDelegate()
    weak var navigationController: UINavigationController?

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        (navigationController?.viewControllers.count ?? 0) > 1
    }
}
