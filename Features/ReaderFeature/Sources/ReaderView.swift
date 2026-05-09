import SwiftUI
import ComposableArchitecture
import Domain
import ImageCacheKit
import DesignSystem
import SharedUI
import SettingsFeature
import UIKit

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
            }
        }
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
        let tapZones = tapZonesEnabledFromDefaults
        let swipe = swipeEnabledFromDefaults
        let centerTap: () -> Void = { store.send(.toggleControls) }

        switch store.mode {
        case .single:
            SinglePageRenderer(
                totalPages: store.pageCount,
                current: binding,
                pageImage: provider,
                onPrefetchHint: hint,
                progressionDirection: direction,
                tapZonesEnabled: tapZones,
                swipeEnabled: swipe,
                onCenterTap: centerTap
            )
        case .dual:
            DualPageRenderer(
                totalPages: store.pageCount,
                current: binding,
                pageImage: provider,
                onPrefetchHint: hint,
                progressionDirection: direction,
                tapZonesEnabled: tapZones,
                swipeEnabled: swipe,
                onCenterTap: centerTap
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
        GlassEffectContainer(spacing: 24) {
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
        }
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private var topBar: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .frame(width: 36, height: 36)
            }
            Spacer()
            Text(store.comic.title)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Button { store.send(.bookmarksTapped(comicId: store.comic.id)) } label: {
                Image(systemName: "bookmark")
                    .font(.title3.weight(.semibold))
                    .frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }

    @ViewBuilder
    private var bottomBar: some View {
        VStack(spacing: 8) {
            // Centered page indicator
            Text("\(store.pageIndex + 1) / \(store.pageCount)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.85))

            HStack(spacing: 12) {
                if store.pageCount > 1 {
                    Slider(
                        value: Binding(
                            get: { Double(store.pageIndex) },
                            set: { store.send(.pageChanged(Int($0.rounded()))) }
                        ),
                        in: 0...Double(store.pageCount - 1),
                        step: 1,
                        onEditingChanged: { editing in
                            store.send(editing ? .sliderDragStart : .sliderDragEnd)
                        }
                    )
                    .tint(Tokens.Colors.accent)
                } else {
                    Spacer()
                }

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
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3.weight(.semibold))
                        .frame(width: 36, height: 36)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
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
