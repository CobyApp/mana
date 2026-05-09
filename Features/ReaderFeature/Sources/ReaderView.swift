import SwiftUI
import ComposableArchitecture
import Domain
import ImageCacheKit
import DesignSystem
import SharedUI
import SettingsFeature

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
            } else {
                ProgressView().tint(.white)
            }

            if store.isControlsVisible {
                controlsOverlay
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: store.isControlsVisible)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .background(SwipeBackBlocker())
        .task { await store.send(.task).finish() }
        .onLongPressGesture(minimumDuration: 0.4) {
            store.send(.toggleControls)
        }
        .onDisappear { store.send(.onDisappear) }
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

        switch store.mode {
        case .single:
            SinglePageRenderer(
                totalPages: store.pageCount,
                current: binding,
                pageImage: provider,
                onPrefetchHint: hint,
                progressionDirection: direction,
                tapZonesEnabled: tapZonesEnabledFromDefaults,
                swipeEnabled: swipeEnabledFromDefaults
            )
        case .dual:
            DualPageRenderer(
                totalPages: store.pageCount,
                current: binding,
                pageImage: provider,
                onPrefetchHint: hint,
                progressionDirection: direction,
                tapZonesEnabled: tapZonesEnabledFromDefaults,
                swipeEnabled: swipeEnabledFromDefaults
            )
        case .scroll(let scrollDirection):
            ScrollPageRenderer(
                totalPages: store.pageCount,
                current: binding,
                pageImage: provider,
                onPrefetchHint: hint,
                direction: scrollDirection
            )
        }
    }

    @ViewBuilder
    private var controlsOverlay: some View {
        VStack {
            // TOP overlay
            HStack(spacing: Tokens.Spacing.m) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left").font(.title3)
                }
                Spacer()
                VStack(spacing: 0) {
                    Text(store.comic.title).font(.headline).lineLimit(1)
                    Text("\(store.pageIndex + 1) / \(store.pageCount)")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Button { store.send(.bookmarksTapped(comicId: store.comic.id)) } label: {
                    Image(systemName: "bookmark").font(.title3)
                }
            }
            .padding(.horizontal, Tokens.Spacing.l)
            .padding(.vertical, Tokens.Spacing.m)
            .background(.ultraThinMaterial)
            .glassEffect(in: .rect(cornerRadius: Tokens.Radius.card))
            .padding(Tokens.Spacing.m)

            Spacer()

            // BOTTOM overlay
            HStack(spacing: Tokens.Spacing.m) {
                Slider(
                    value: Binding(
                        get: { Double(store.pageIndex) },
                        set: { store.send(.pageChanged(Int($0.rounded()))) }
                    ),
                    in: 0...Double(max(0, store.pageCount - 1)),
                    step: 1,
                    onEditingChanged: { editing in
                        store.send(editing ? .sliderDragStart : .sliderDragEnd)
                    }
                )
                .tint(Tokens.Colors.accent)

                Menu {
                    Picker(selection: Binding(
                        get: { store.mode },
                        set: { store.send(.modeChanged($0)) }
                    ), label: Text("reader.controls.mode", bundle: .module)) {
                        Text("mode.single", bundle: .module).tag(ReadingMode.single)
                        Text("mode.dual", bundle: .module).tag(ReadingMode.dual)
                        Text("mode.scroll.ltr", bundle: .module).tag(ReadingMode.scroll(direction: .ltr))
                        Text("mode.scroll.rtl", bundle: .module).tag(ReadingMode.scroll(direction: .rtl))
                        Text("mode.scroll.ttb", bundle: .module).tag(ReadingMode.scroll(direction: .ttb))
                    }
                    Picker(selection: Binding(
                        get: { store.pageProgressionDirection },
                        set: { store.send(.progressionDirectionChanged($0)) }
                    ), label: Text("reader.controls.direction", bundle: .module)) {
                        Text("direction.ltr", bundle: .module).tag(PageProgressionDirection.leftToRight)
                        Text("direction.rtl", bundle: .module).tag(PageProgressionDirection.rightToLeft)
                    }
                } label: {
                    Image(systemName: "rectangle.split.2x1").font(.title3)
                }
            }
            .padding(.horizontal, Tokens.Spacing.l)
            .padding(.vertical, Tokens.Spacing.m)
            .background(.ultraThinMaterial)
            .glassEffect(in: .rect(cornerRadius: Tokens.Radius.card))
            .padding(Tokens.Spacing.m)
        }
        .foregroundStyle(.white)
    }

    private var tapZonesEnabledFromDefaults: Bool {
        @Dependency(\.userDefaults) var defaults
        let stored = defaults.string(forKey: SettingsFeature.tapZonesKey)
        return stored != "false"   // default ON
    }

    private var swipeEnabledFromDefaults: Bool {
        @Dependency(\.userDefaults) var defaults
        let stored = defaults.string(forKey: SettingsFeature.swipeKey)
        return stored != "false"   // default ON
    }
}
