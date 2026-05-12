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
        ZStack {
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
        }
        .overlay { popoverDim }
        .overlay(alignment: .bottomTrailing) { controlsPopoverOverlay }
        .animation(.easeOut(duration: 0.12), value: showControlsPopover)
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
    private var popoverDim: some View {
        if showControlsPopover {
            Color.black.opacity(0.0001)
                .ignoresSafeArea()
                .onTapGesture { showControlsPopover = false }
        }
    }

    @ViewBuilder
    private var controlsPopoverOverlay: some View {
        if showControlsPopover {
            controlsPopover
                .padding(.trailing, Tokens.Spacing.m)
                .padding(.bottom, 130)
                .transition(.opacity)
        }
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
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(localized("reader.controls.mode"))
            optionRow(localized("mode.single"),
                      isSelected: store.mode == .single) {
                store.send(.modeChanged(.single))
            }
            divider
            optionRow(localized("mode.dual"),
                      isSelected: store.mode == .dual) {
                store.send(.modeChanged(.dual))
            }

            sectionDivider
            sectionHeader(localized("reader.controls.direction"))
            optionRow(localized("direction.ltr"),
                      isSelected: store.pageProgressionDirection == .leftToRight) {
                store.send(.progressionDirectionChanged(.leftToRight))
            }
            divider
            optionRow(localized("direction.rtl"),
                      isSelected: store.pageProgressionDirection == .rightToLeft) {
                store.send(.progressionDirectionChanged(.rightToLeft))
            }

            sectionDivider
            sectionHeader(localized("reader.controls.page_offset"))
            optionRow(localized("reader.controls.page_offset.off"),
                      isSelected: !store.pageOffset) {
                store.send(.pageOffsetChanged(false))
            }
            divider
            optionRow(localized("reader.controls.page_offset.on"),
                      isSelected: store.pageOffset) {
                store.send(.pageOffsetChanged(true))
            }
        }
        .frame(width: 260)
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

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(verbatim: title)
            .font(Tokens.Typography.caption)
            .foregroundStyle(Tokens.Colors.ink.opacity(0.55))
            .textCase(.uppercase)
            .padding(.horizontal, Tokens.Spacing.m)
            .padding(.top, 10)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func optionRow(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            HStack(spacing: Tokens.Spacing.s) {
                Text(verbatim: title)
                    .font(Tokens.Typography.subtitle)
                    .foregroundStyle(isSelected ? Tokens.Colors.paper : Tokens.Colors.ink)
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Tokens.Colors.paper)
                }
            }
            .padding(.horizontal, Tokens.Spacing.m)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Tokens.Colors.accent : Tokens.Colors.paper)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var divider: some View {
        Rectangle()
            .fill(Tokens.Colors.ink.opacity(0.15))
            .frame(height: 1)
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(Tokens.Colors.ink)
            .frame(height: 1)
    }

    private func localized(_ key: String) -> String {
        Bundle.module.localized(key, for: locale)
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

