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

// MARK: - Shared reader building blocks (used by the local and the online reader)

/// Looks up ReaderFeature's own strings, so other modules (the online reader) can reuse the
/// reader's localized copy without duplicating it.
public enum ReaderStrings {
    public static func string(_ key: String, locale: Locale) -> String {
        Bundle.module.localized(key, for: locale)
    }
}

/// Fixed reader-canvas colours. The reader always draws on black, so text/effects that sit
/// directly on the canvas use the Android reader's fixed paper/ink rather than the
/// light/dark-flipping tokens.
enum ReaderPalette {
    static let paper = Color(red: 0.949, green: 0.922, blue: 0.863)
    static let ink = Color(red: 0.039, green: 0.031, blue: 0.071)
}

/// Page ↔ spread mapping matching `DualPageRenderer`'s pairing, so the readout, slider and page
/// jump count spreads in dual mode (Android `state.spreads`). Identity in single/webtoon.
public enum ReaderSpreads {
    public static func count(pageCount: Int, mode: ReadingMode, pageOffset: Bool) -> Int {
        guard mode == .dual, pageCount > 0 else { return pageCount }
        // Offset: cover alone, then pairs. Otherwise: plain pairs.
        return pageOffset ? 1 + pageCount / 2 : (pageCount + 1) / 2
    }

    public static func position(ofPage page: Int, mode: ReadingMode, pageOffset: Bool) -> Int {
        guard mode == .dual else { return page }
        if pageOffset { return page == 0 ? 0 : (page + 1) / 2 }
        return page / 2
    }

    public static func firstPage(ofPosition position: Int, pageCount: Int, mode: ReadingMode, pageOffset: Bool) -> Int {
        let page: Int
        if mode == .dual {
            page = pageOffset ? (position == 0 ? 0 : position * 2 - 1) : position * 2
        } else {
            page = position
        }
        return min(max(0, page), max(0, pageCount - 1))
    }
}

public extension View {
    /// Keeps the screen awake while this view is on screen (Android `FLAG_KEEP_SCREEN_ON`).
    func readerKeepsScreenAwake() -> some View {
        onAppear { UIApplication.shared.isIdleTimerDisabled = true }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}

/// Square ink back button with an inner paper stroke, as used in the reader's top bar.
public struct ReaderBackButton: View {
    private let action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        ReaderIconButton(systemName: "chevron.left", action: action)
    }
}

struct ReaderIconButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Tokens.Colors.paper)
                .frame(width: 36, height: 36)
                .background(Tokens.Colors.ink)
                .overlay(Rectangle().strokeBorder(Tokens.Colors.paper, lineWidth: 1.5).padding(2))
                .contentShape(Rectangle())
        }
        .buttonStyle(MangaPressStyle(haptic: .tap))
    }
}

/// Shown while a chapter has no pages yet: the on-brand loader, or — after a failed open — a
/// message with an accent Retry. The back button is always visible top-left so the reader is
/// never a dead end. (Android `ReaderContent` empty-spreads branch.)
public struct ReaderStatusView: View {
    public enum Phase: Equatable { case loading, failed }

    private let phase: Phase
    private let onRetry: () -> Void
    private let onBack: () -> Void
    @Environment(\.locale) private var locale

    public init(phase: Phase, onRetry: @escaping () -> Void, onBack: @escaping () -> Void) {
        self.phase = phase
        self.onRetry = onRetry
        self.onBack = onBack
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            Group {
                switch phase {
                case .loading:
                    // Dark scheme so the loader's ink caption reads on the black canvas.
                    ManaLoader().environment(\.colorScheme, .dark)
                case .failed:
                    VStack(spacing: 14) {
                        Text(verbatim: ReaderStrings.string("reader.load_failed", locale: locale))
                            .font(Tokens.Typography.body)
                            .foregroundStyle(ReaderPalette.paper)
                            .multilineTextAlignment(.center)
                        Button(action: onRetry) {
                            Text(verbatim: ReaderStrings.string("reader.retry", locale: locale))
                                .font(Tokens.Typography.title)
                                .foregroundStyle(ReaderPalette.ink)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .background(Tokens.Colors.accent)
                                .overlay(Rectangle().strokeBorder(ReaderPalette.paper, lineWidth: Tokens.Stroke.bold))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(MangaPressStyle(haptic: .confirm))
                    }
                    .padding(Tokens.Spacing.l)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            ReaderBackButton(action: onBack)
                .padding(16)
        }
    }
}

/// End-of-chapter page offering to continue into the next chapter. Rendered as a real extra
/// page after the last spread (paged) or a full-height last item (webtoon).
/// (Android `NextChapterCard`.)
public struct NextChapterPage: View {
    private let title: String
    private let onOpenNext: () -> Void
    private let onBack: () -> Void
    @Environment(\.locale) private var locale

    public init(title: String, onOpenNext: @escaping () -> Void, onBack: @escaping () -> Void) {
        self.title = title
        self.onOpenNext = onOpenNext
        self.onBack = onBack
    }

    public var body: some View {
        VStack(spacing: 16) {
            Text(verbatim: ReaderStrings.string("reader.next_chapter", locale: locale))
                .font(Tokens.Typography.caption)
                .foregroundStyle(Tokens.Colors.accent)
            Text(verbatim: title)
                .font(Tokens.Typography.title)
                .foregroundStyle(ReaderPalette.paper)
                .multilineTextAlignment(.center)
            Button(action: onOpenNext) {
                Text(verbatim: ReaderStrings.string("reader.read_next", locale: locale))
                    .font(Tokens.Typography.title)
                    .foregroundStyle(ReaderPalette.ink)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(ReaderPalette.paper)
                    .overlay(Rectangle().strokeBorder(ReaderPalette.ink, lineWidth: Tokens.Stroke.bold))
                    .background(Rectangle().fill(Tokens.Colors.accent).offset(x: 4, y: 5))
                    .contentShape(Rectangle())
            }
            .buttonStyle(MangaPressStyle(haptic: .confirm))
            Button(action: onBack) {
                Text(verbatim: ReaderStrings.string("reader.back_to_library", locale: locale))
                    .font(Tokens.Typography.subtitle)
                    .foregroundStyle(ReaderPalette.paper)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(ReaderPalette.ink)
                    .overlay(Rectangle().strokeBorder(ReaderPalette.paper.opacity(0.6), lineWidth: 1.5))
                    .contentShape(Rectangle())
            }
            .buttonStyle(MangaPressStyle(haptic: .tap))
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Non-hit-testable so the renderer's left/right tap zones still work around the column.
        .background(ReaderPalette.ink.allowsHitTesting(false))
    }
}

/// "Go to page" dialog: paper card, bold ink stroke, accent offset shadow; digits-only number
/// field prefilled with the current page. Values are clamped to `1...total`.
/// Host it in a `MangaDialogHost`. (Android `PageJumpDialog`.)
public struct PageJumpDialog: View {
    private let total: Int
    private let onGo: (Int) -> Void
    private let onCancel: () -> Void
    @State private var text: String
    @FocusState private var focused: Bool
    @Environment(\.locale) private var locale

    /// - Parameters:
    ///   - total: number of pages (or spreads) the user can jump to.
    ///   - current: 1-based current page, used to prefill the field.
    ///   - onGo: receives the clamped 1-based target.
    public init(total: Int, current: Int, onGo: @escaping (Int) -> Void, onCancel: @escaping () -> Void) {
        self.total = total
        self.onGo = onGo
        self.onCancel = onCancel
        self._text = State(initialValue: String(current))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(verbatim: ReaderStrings.string("reader.go_to_page", locale: locale))
                .font(Tokens.Typography.title)
                .foregroundStyle(Tokens.Colors.ink)
            Text(verbatim: "1 – \(total)")
                .font(Tokens.Typography.mono)
                .foregroundStyle(Tokens.Colors.ink.opacity(0.6))
            TextField("", text: $text)
                .keyboardType(.numberPad)
                .submitLabel(.go)
                .onSubmit(submit)
                .focused($focused)
                .font(Tokens.Typography.monoLarge)
                .foregroundStyle(Tokens.Colors.ink)
                .tint(Tokens.Colors.accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Tokens.Colors.paper)
                .overlay(Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: Tokens.Stroke.regular))
                .background(Rectangle().fill(Tokens.Colors.ink).offset(x: 4, y: 5))
                .onChange(of: text) { _, new in
                    let digits = String(new.filter(\.isNumber).prefix(6))
                    if digits != new { text = digits }
                }
            HStack(spacing: 10) {
                MangaDialogButton(
                    title: ReaderStrings.string("reader.jump.cancel", locale: locale),
                    isAccent: false,
                    action: onCancel
                )
                MangaDialogButton(
                    title: ReaderStrings.string("reader.jump.go", locale: locale),
                    isAccent: true,
                    action: submit
                )
            }
        }
        .padding(20)
        .frame(maxWidth: 360)
        .background(Tokens.Colors.paper)
        .overlay(Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: Tokens.Stroke.bold))
        .background(Rectangle().fill(Tokens.Colors.accent).offset(x: 5, y: 6))
        .onAppear { focused = true }
    }

    private func submit() {
        guard let n = Int(text), total > 0 else { return }
        onGo(min(max(1, n), total))
    }
}

/// Manga-styled reading options popover: Mode / Direction / First page solo.
public struct ReaderOptionsPopover: View {
    private let mode: ReadingMode
    private let direction: PageProgressionDirection
    private let pageOffset: Bool
    private let onModeChange: (ReadingMode) -> Void
    private let onDirectionChange: (PageProgressionDirection) -> Void
    private let onPageOffsetChange: (Bool) -> Void
    @Environment(\.locale) private var locale

    public init(
        mode: ReadingMode,
        direction: PageProgressionDirection,
        pageOffset: Bool,
        onModeChange: @escaping (ReadingMode) -> Void,
        onDirectionChange: @escaping (PageProgressionDirection) -> Void,
        onPageOffsetChange: @escaping (Bool) -> Void
    ) {
        self.mode = mode
        self.direction = direction
        self.pageOffset = pageOffset
        self.onModeChange = onModeChange
        self.onDirectionChange = onDirectionChange
        self.onPageOffsetChange = onPageOffsetChange
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(localized("reader.controls.mode"))
            optionRow(localized("mode.single"), isSelected: mode == .single) { onModeChange(.single) }
            divider
            optionRow(localized("mode.dual"), isSelected: mode == .dual) { onModeChange(.dual) }
            divider
            optionRow(localized("mode.webtoon"), isSelected: mode == .webtoon) { onModeChange(.webtoon) }

            sectionDivider
            sectionHeader(localized("reader.controls.direction"))
            optionRow(localized("direction.ltr"), isSelected: direction == .leftToRight) {
                onDirectionChange(.leftToRight)
            }
            divider
            optionRow(localized("direction.rtl"), isSelected: direction == .rightToLeft) {
                onDirectionChange(.rightToLeft)
            }

            sectionDivider
            sectionHeader(localized("reader.controls.page_offset"))
            optionRow(localized("reader.controls.page_offset.off"), isSelected: !pageOffset) {
                onPageOffsetChange(false)
            }
            divider
            optionRow(localized("reader.controls.page_offset.on"), isSelected: pageOffset) {
                onPageOffsetChange(true)
            }
        }
        .frame(width: 260)
        .background(Tokens.Colors.paper)
        .overlay(Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: Tokens.Stroke.regular))
        .background(Rectangle().fill(Tokens.Colors.ink).offset(x: 4, y: 5))
    }

    private func localized(_ key: String) -> String {
        ReaderStrings.string(key, locale: locale)
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
        Button(action: action) {
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
        .buttonStyle(MangaPressStyle(haptic: .tick, pressedScale: 1))
    }

    private var divider: some View {
        Rectangle().fill(Tokens.Colors.ink.opacity(0.15)).frame(height: 1)
    }

    private var sectionDivider: some View {
        Rectangle().fill(Tokens.Colors.ink).frame(height: 1)
    }
}

/// The reader's immersive bars: top bar (back + centred boxed title) and bottom bar (tappable
/// page readout, seek slider, Tune button). `position`/`count` are in readout units — spreads
/// in dual mode, pages otherwise.
public struct ReaderControlsOverlay: View {
    private let title: String
    private let position: Int
    private let count: Int
    private let reversed: Bool
    private let onSeek: (Int) -> Void
    private let onBack: () -> Void
    private let onOpenJump: () -> Void
    private let onOpenOptions: () -> Void

    public init(
        title: String,
        position: Int,
        count: Int,
        reversed: Bool,
        onSeek: @escaping (Int) -> Void,
        onBack: @escaping () -> Void,
        onOpenJump: @escaping () -> Void,
        onOpenOptions: @escaping () -> Void
    ) {
        self.title = title
        self.position = position
        self.count = count
        self.reversed = reversed
        self.onSeek = onSeek
        self.onBack = onBack
        self.onOpenJump = onOpenJump
        self.onOpenOptions = onOpenOptions
    }

    public var body: some View {
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

    private var topBar: some View {
        HStack(spacing: 12) {
            ReaderBackButton(action: onBack)
            Spacer()
            Text(verbatim: title)
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

    private var bottomBar: some View {
        VStack(spacing: 10) {
            HStack {
                Spacer()
                pageReadout
                Spacer()
            }

            HStack(spacing: 12) {
                if count > 1 {
                    MangaProgressBar(
                        value: Binding(
                            get: { Double(position) },
                            set: { onSeek(Int($0.rounded())) }
                        ),
                        in: 0...Double(count - 1),
                        reversed: reversed
                    )
                } else {
                    Spacer()
                }
                ReaderIconButton(systemName: "slider.horizontal.3", action: onOpenOptions)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Tokens.Colors.ink.opacity(0.85))
        .overlay(Rectangle().strokeBorder(Tokens.Colors.paper, lineWidth: Tokens.Stroke.bold))
        .background(Tokens.Colors.accent.offset(x: 4, y: -4))
    }

    /// Tap to type a page number and jump.
    private var pageReadout: some View {
        Button(action: onOpenJump) {
            HStack(spacing: 4) {
                Text(verbatim: "\(position + 1)")
                    .font(Tokens.Typography.monoLarge)
                    .foregroundStyle(Tokens.Colors.accent)
                Text(verbatim: "/")
                    .font(Tokens.Typography.mono)
                    .foregroundStyle(Tokens.Colors.paper.opacity(0.6))
                Text(verbatim: "\(count)")
                    .font(Tokens.Typography.mono)
                    .foregroundStyle(Tokens.Colors.paper)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Tokens.Colors.ink)
            .overlay(Rectangle().strokeBorder(Tokens.Colors.paper.opacity(0.4), lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(MangaPressStyle(haptic: .tap))
    }
}

/// Everything the reader draws over the pages: the page-turn speed-line flash + haptic, the
/// controls bars, the options popover and the page-jump dialog. Shared by the local and the
/// online reader so both have identical chrome. `position`/`count` are in readout units
/// (see `ReaderSpreads`); `onSeek` receives a 0-based position in the same units.
public struct ReaderChrome: View {
    private let title: String
    private let isControlsVisible: Bool
    private let position: Int
    private let count: Int
    private let mode: ReadingMode
    private let direction: PageProgressionDirection
    private let pageOffset: Bool
    private let onSeek: (Int) -> Void
    private let onBack: () -> Void
    private let onModeChange: (ReadingMode) -> Void
    private let onDirectionChange: (PageProgressionDirection) -> Void
    private let onPageOffsetChange: (Bool) -> Void

    @State private var showOptions = false
    @State private var showJump = false
    @State private var flash: Double = 0
    @Environment(\.manaLiteMode) private var liteMode

    public init(
        title: String,
        isControlsVisible: Bool,
        position: Int,
        count: Int,
        mode: ReadingMode,
        direction: PageProgressionDirection,
        pageOffset: Bool,
        onSeek: @escaping (Int) -> Void,
        onBack: @escaping () -> Void,
        onModeChange: @escaping (ReadingMode) -> Void,
        onDirectionChange: @escaping (PageProgressionDirection) -> Void,
        onPageOffsetChange: @escaping (Bool) -> Void
    ) {
        self.title = title
        self.isControlsVisible = isControlsVisible
        self.position = position
        self.count = count
        self.mode = mode
        self.direction = direction
        self.pageOffset = pageOffset
        self.onSeek = onSeek
        self.onBack = onBack
        self.onModeChange = onModeChange
        self.onDirectionChange = onDirectionChange
        self.onPageOffsetChange = onPageOffsetChange
    }

    public var body: some View {
        ZStack {
            // Brief speed-line burst on each page turn (manga action feel); off in lite mode.
            if !liteMode {
                SpeedLines(color: ReaderPalette.paper.opacity(0.22), lineCount: 40)
                    .opacity(flash)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            if isControlsVisible {
                ReaderControlsOverlay(
                    title: title,
                    position: position,
                    count: count,
                    reversed: direction == .rightToLeft,
                    onSeek: { onSeek(min(max(0, $0), max(0, count - 1))) },
                    onBack: onBack,
                    onOpenJump: { showJump = true },
                    onOpenOptions: { showOptions.toggle() }
                )
            }

            if showOptions {
                Color.black.opacity(0.0001)
                    .ignoresSafeArea()
                    .onTapGesture { showOptions = false }
                ReaderOptionsPopover(
                    mode: mode,
                    direction: direction,
                    pageOffset: pageOffset,
                    onModeChange: onModeChange,
                    onDirectionChange: onDirectionChange,
                    onPageOffsetChange: onPageOffsetChange
                )
                .padding(.trailing, Tokens.Spacing.m)
                .padding(.bottom, 130)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .transition(.opacity)
            }

            MangaDialogHost(isPresented: showJump, onDismiss: { showJump = false }) {
                PageJumpDialog(
                    total: count,
                    current: position + 1,
                    onGo: { target in
                        showJump = false
                        onSeek(target - 1)
                    },
                    onCancel: { showJump = false }
                )
            }
        }
        .animation(.easeOut(duration: 0.12), value: showOptions)
        .animation(.spring(duration: 0.35, bounce: 0.15), value: isControlsVisible)
        .onChange(of: position) { _, _ in pageTurned() }
    }

    private func pageTurned() {
        // Selection tick on each page turn in the paged modes (Android `TextHandleMove`).
        if mode != .webtoon { MangaHaptic.tick.play() }
        guard !liteMode else { return }
        var snap = Transaction()
        snap.disablesAnimations = true
        withTransaction(snap) { flash = 1 }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.28)) { flash = 0 }
        }
    }
}

// MARK: - Local reader

public struct ReaderView: View {
    @Bindable public var store: StoreOf<ReaderFeature>
    @Dependency(\.imageCache) private var imageCache
    @Environment(\.dismiss) private var dismiss

    public init(store: StoreOf<ReaderFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if store.pageCount > 0 {
                renderer
                    .ignoresSafeArea()
                chrome
            } else {
                ReaderStatusView(
                    phase: store.loadFailed ? .failed : .loading,
                    onRetry: { store.send(.retry) },
                    onBack: { dismiss() }
                )
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .background(SwipeBackBlocker())
        .readerKeepsScreenAwake()
        .task { await store.send(.task).finish() }
        .onDisappear { store.send(.onDisappear) }
        .onLongPressGesture(minimumDuration: 0.4) {
            MangaHaptic.longPress.play()
            store.send(.toggleControls)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    private var chrome: some View {
        let mode = store.mode
        let offset = store.pageOffset
        let pageCount = store.pageCount
        return ReaderChrome(
            title: store.comic.title,
            isControlsVisible: store.isControlsVisible,
            position: ReaderSpreads.position(ofPage: store.pageIndex, mode: mode, pageOffset: offset),
            count: ReaderSpreads.count(pageCount: pageCount, mode: mode, pageOffset: offset),
            mode: mode,
            direction: store.pageProgressionDirection,
            pageOffset: offset,
            onSeek: { position in
                store.send(.pageChanged(ReaderSpreads.firstPage(
                    ofPosition: position, pageCount: pageCount, mode: mode, pageOffset: offset
                )))
            },
            onBack: { dismiss() },
            onModeChange: { store.send(.modeChanged($0)) },
            onDirectionChange: { store.send(.progressionDirectionChanged($0)) },
            onPageOffsetChange: { store.send(.pageOffsetChanged($0)) }
        )
    }

    /// The trailing "next chapter" page, only when a following chapter exists.
    private var endPage: AnyView? {
        guard let next = store.nextComic else { return nil }
        return AnyView(NextChapterPage(
            title: next.title,
            onOpenNext: { store.send(.openNext) },
            onBack: { dismiss() }
        ))
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
                pageOffset: store.pageOffset,
                pageOverlay: nil,
                endPage: endPage
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
                pageOffset: store.pageOffset,
                pageOverlay: nil,
                endPage: endPage
            )
        case .webtoon:
            WebtoonRenderer(
                totalPages: store.pageCount,
                current: binding,
                pageImage: provider,
                onPrefetchHint: hint,
                onCenterTap: centerTap,
                pageOverlay: nil,
                endPage: endPage
            )
        }
    }
}
