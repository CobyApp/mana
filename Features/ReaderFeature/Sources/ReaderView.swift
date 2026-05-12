import SwiftUI
import ComposableArchitecture
import Domain
import ImageCacheKit
import DesignSystem
import SharedUI
import UIKit

private extension Bundle {
    /// Looks up a localized string honoring a SwiftUI environment `Locale`,
    /// independent of `Bundle.preferredLocalizations`.
    func localized(_ key: String, for locale: Locale) -> String {
        let langCode = locale.language.languageCode?.identifier ?? "en"
        if let path = path(forResource: langCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: key, value: nil, table: nil)
        }
        return localizedString(forKey: key, value: nil, table: nil)
    }
}

public struct ReaderView: View {
    @Bindable public var store: StoreOf<ReaderFeature>
    @Dependency(\.imageCache) private var imageCache
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    @State private var showControlsPopover: Bool = false

    public init(store: StoreOf<ReaderFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.black.ignoresSafeArea()

            if store.pageCount > 0 {
                renderer
                    .ignoresSafeArea()
            } else {
                ProgressView().tint(Tokens.Colors.accent)
            }

            if store.isControlsVisible {
                controlsOverlay
            }

            if showControlsPopover {
                Color.black.opacity(0.0001)
                    .ignoresSafeArea()
                    .onTapGesture { showControlsPopover = false }

                controlsPopover
                    .frame(width: 320)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, Tokens.Spacing.m)
                    .padding(.bottom, 130)
                    .allowsHitTesting(true)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeOut(duration: 0.18), value: showControlsPopover)
        .animation(.spring(duration: 0.35, bounce: 0.15), value: store.isControlsVisible)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .background(SwipeBackBlocker())
        .task { await store.send(.task).finish() }
        .onLongPressGesture(minimumDuration: 0.4) {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            store.send(.toggleControls)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    @ViewBuilder
    private var renderer: some View {
        let comicId = store.comic.id
        let cache = imageCache
        let provider: (Int) async -> UIImage? = { idx in
            let key = PageKey(comicId: comicId, pageIndex: idx)
            guard let data = await cache.data(for: key) else { return nil }
            return UIImage(data: data)
        }
        let binding = Binding<Int>(
            get: { store.pageIndex },
            set: { store.send(.pageChanged($0)) }
        )
        let hint: (Int) -> Void = { idx in store.send(.prefetchHint(idx)) }
        let direction = store.pageProgressionDirection
        let centerTap: () -> Void = { store.send(.toggleControls) }

        switch store.mode {
        case .single:
            SinglePageRenderer(
                totalPages: store.pageCount,
                current: binding,
                pageImage: provider,
                onPrefetchHint: hint,
                progressionDirection: direction,
                tapZonesEnabled: true,
                swipeEnabled: true,
                onCenterTap: centerTap,
                pageOffset: store.pageOffset
            )
        case .dual:
            DualPageRenderer(
                totalPages: store.pageCount,
                current: binding,
                pageImage: provider,
                onPrefetchHint: hint,
                progressionDirection: direction,
                tapZonesEnabled: true,
                swipeEnabled: true,
                onCenterTap: centerTap,
                pageOffset: store.pageOffset
            )
        }
    }

    @ViewBuilder
    private var controlsOverlay: some View {
        VStack {
            topBar
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity
                ))
            Spacer()
            bottomBar
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity
                ))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .foregroundStyle(Tokens.Colors.paper)
    }

    @ViewBuilder
    private var topBar: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Tokens.Colors.paper)
                    .frame(width: 36, height: 36)
                    .background(Tokens.Colors.ink)
                    .overlay(Rectangle().strokeBorder(Tokens.Colors.paper, lineWidth: 1.5).padding(2))
            }
            Spacer()
            Text(store.comic.title)
                .font(Tokens.Typography.title)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(Tokens.Colors.paper)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Tokens.Colors.ink)
                .overlay(Rectangle().strokeBorder(Tokens.Colors.paper, lineWidth: 1.5).padding(2))
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Tokens.Colors.ink.opacity(0.85))
        .overlay(Rectangle().strokeBorder(Tokens.Colors.paper, lineWidth: Tokens.Stroke.bold))
        .background(Tokens.Colors.accent.offset(x: 4, y: 4))
    }

    @ViewBuilder
    private var bottomBar: some View {
        VStack(spacing: 10) {
            HStack {
                Spacer()
                pageReadout
                Spacer()
            }

            HStack(spacing: 12) {
                if store.pageCount > 1 {
                    MangaProgressBar(
                        value: Binding(
                            get: { Double(store.pageIndex) },
                            set: { store.send(.pageChanged(Int($0.rounded()))) }
                        ),
                        in: 0...Double(store.pageCount - 1),
                        reversed: store.pageProgressionDirection == .rightToLeft
                    )
                } else {
                    Spacer()
                }

                Button { showControlsPopover.toggle() } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(Tokens.Colors.paper)
                        .frame(width: 36, height: 36)
                        .background(Tokens.Colors.ink)
                        .overlay(Rectangle().strokeBorder(Tokens.Colors.paper, lineWidth: 1.5).padding(2))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Tokens.Colors.ink.opacity(0.85))
        .overlay(Rectangle().strokeBorder(Tokens.Colors.paper, lineWidth: Tokens.Stroke.bold))
        .background(Tokens.Colors.accent.offset(x: 4, y: -4))
    }

    private var controlsPopover: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.l) {
            controlSection(title: localized("reader.controls.mode")) {
                MangaToggle(
                    selection: Binding(
                        get: { store.mode },
                        set: { store.send(.modeChanged($0)) }
                    ),
                    options: [
                        (ReadingMode.single, Text(verbatim: localized("mode.single"))),
                        (ReadingMode.dual,   Text(verbatim: localized("mode.dual")))
                    ],
                    showShadow: false
                )
            }

            controlSection(title: localized("reader.controls.direction")) {
                MangaToggle(
                    selection: Binding(
                        get: { store.pageProgressionDirection },
                        set: { store.send(.progressionDirectionChanged($0)) }
                    ),
                    options: [
                        (PageProgressionDirection.leftToRight, Text(verbatim: localized("direction.ltr"))),
                        (PageProgressionDirection.rightToLeft, Text(verbatim: localized("direction.rtl")))
                    ],
                    showShadow: false
                )
            }

            controlSection(title: localized("reader.controls.page_offset")) {
                MangaToggle(
                    selection: Binding(
                        get: { store.pageOffset },
                        set: { store.send(.pageOffsetChanged($0)) }
                    ),
                    options: [
                        (false, Text(verbatim: localized("reader.controls.page_offset.off"))),
                        (true,  Text(verbatim: localized("reader.controls.page_offset.on")))
                    ],
                    showShadow: false
                )
            }
        }
        .padding(Tokens.Spacing.l)
        .background(Tokens.Colors.paper)
        .overlay(
            Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: Tokens.Stroke.regular)
        )
        .background(
            Rectangle()
                .fill(Tokens.Colors.ink)
                .offset(x: 4, y: 5)
        )
    }

    private func localized(_ key: String) -> String {
        Bundle.module.localized(key, for: locale)
    }

    @ViewBuilder
    private func controlSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: title)
                .font(Tokens.Typography.caption)
                .foregroundStyle(Tokens.Colors.ink.opacity(0.7))
                .textCase(.uppercase)
            content()
        }
    }

    private var pageReadout: some View {
        HStack(spacing: 4) {
            Text("\(store.pageIndex + 1)")
                .font(Tokens.Typography.monoLarge)
                .foregroundStyle(Tokens.Colors.accent)
            Text("/")
                .font(Tokens.Typography.mono)
                .foregroundStyle(Tokens.Colors.paper.opacity(0.6))
            Text("\(store.pageCount)")
                .font(Tokens.Typography.mono)
                .foregroundStyle(Tokens.Colors.paper)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Tokens.Colors.ink)
        .overlay(Rectangle().strokeBorder(Tokens.Colors.paper.opacity(0.4), lineWidth: 1))
    }
}
