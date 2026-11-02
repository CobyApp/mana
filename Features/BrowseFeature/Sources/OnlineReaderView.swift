import SwiftUI
import UIKit
import ComposableArchitecture
import Domain
import DesignSystem
import ReaderFeature

public struct OnlineReaderView: View {
    @Bindable public var store: StoreOf<OnlineReaderFeature>
    @Environment(\.dismiss) private var dismiss

    public init(store: StoreOf<OnlineReaderFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if store.pageCount > 0, !store.loading, !store.error {
                renderer.ignoresSafeArea()
                chrome
            } else {
                // Loader / failure (with Retry) — the back button is always reachable.
                ReaderStatusView(
                    phase: store.error && !store.loading ? .failed : .loading,
                    onRetry: { store.send(.retry) },
                    onBack: { dismiss() }
                )
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .readerKeepsScreenAwake()
        .task { await store.send(.task).finish() }
        .onLongPressGesture(minimumDuration: 0.4) {
            MangaHaptic.longPress.play()
            store.send(.toggleControls)
        }
    }

    /// Same chrome as the local reader (bars, page jump, options popover, speed lines, haptic).
    private var chrome: some View {
        let mode = store.mode
        let offset = store.pageOffset
        let pageCount = store.pageCount
        return ReaderChrome(
            title: store.title,
            isControlsVisible: store.isControlsVisible,
            position: ReaderSpreads.position(ofPage: store.pageIndex, mode: mode, pageOffset: offset),
            count: ReaderSpreads.count(pageCount: pageCount, mode: mode, pageOffset: offset),
            mode: mode,
            direction: store.direction,
            pageOffset: offset,
            onSeek: { position in
                store.send(.pageChanged(ReaderSpreads.firstPage(
                    ofPosition: position, pageCount: pageCount, mode: mode, pageOffset: offset
                )))
            },
            onBack: { dismiss() },
            onModeChange: { store.send(.modeChanged($0)) },
            onDirectionChange: { store.send(.directionChanged($0)) },
            onPageOffsetChange: { store.send(.pageOffsetChanged($0)) }
        )
    }

    @ViewBuilder
    private var renderer: some View {
        let headers = store.imageHeaders
        let urls = store.pageURLs
        let provider: (Int) async -> UIImage? = { idx in
            guard idx >= 0, idx < urls.count else { return nil }
            for _ in 0..<3 {
                if let img = await RemoteImageLoader.shared.load(urls[idx], headers: headers) { return img }
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
            return nil
        }
        let binding = Binding<Int>(get: { store.pageIndex }, set: { store.send(.pageChanged($0)) })
        // Warm the next few pages so page turns are instant.
        let hint: (Int) -> Void = { idx in
            let upcoming = urls.indices.filter { $0 > idx && $0 <= idx + 4 }.map { urls[$0] }
            RemoteImageLoader.shared.prefetch(upcoming, headers: headers)
        }
        let centerTap: () -> Void = { store.send(.toggleControls) }

        switch store.mode {
        case .single:
            SinglePageRenderer(totalPages: store.pageCount, current: binding, pageImage: provider,
                               onPrefetchHint: hint, progressionDirection: store.direction,
                               tapZonesEnabled: true, swipeEnabled: true, onCenterTap: centerTap,
                               pageOffset: store.pageOffset, pageOverlay: nil)
        case .dual:
            DualPageRenderer(totalPages: store.pageCount, current: binding, pageImage: provider,
                             onPrefetchHint: hint, progressionDirection: store.direction,
                             tapZonesEnabled: true, swipeEnabled: true, onCenterTap: centerTap,
                             pageOffset: store.pageOffset, pageOverlay: nil)
        case .webtoon:
            WebtoonRenderer(totalPages: store.pageCount, current: binding, pageImage: provider,
                            onPrefetchHint: hint, onCenterTap: centerTap, pageOverlay: nil)
        }
    }
}
