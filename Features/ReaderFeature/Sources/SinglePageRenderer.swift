import SwiftUI
import UIKit
import Domain
import SharedUI
import DesignSystem

public struct SinglePageRenderer: View, PageRenderer {
    let totalPages: Int
    @Binding var current: Int
    let pageImage: (Int) async -> UIImage?
    let onPrefetchHint: (Int) -> Void
    let progressionDirection: PageProgressionDirection
    let tapZonesEnabled: Bool
    let swipeEnabled: Bool
    let onCenterTap: () -> Void
    let pageOverlay: ((Int) -> AnyView)?
    /// Optional extra page shown after the last one (e.g. the "next chapter" card). It is
    /// purely visual: `current` stays on the last real page while it's showing.
    let endPage: AnyView?

    @State private var image: UIImage?
    @State private var loadingIndex: Int?
    @State private var showingEnd = false

    public init(
        totalPages: Int,
        current: Binding<Int>,
        pageImage: @escaping (Int) async -> UIImage?,
        onPrefetchHint: @escaping (Int) -> Void,
        progressionDirection: PageProgressionDirection = .leftToRight,
        tapZonesEnabled: Bool = true,
        swipeEnabled: Bool = true,
        onCenterTap: @escaping () -> Void = {},
        pageOffset: Bool = false,
        pageOverlay: ((Int) -> AnyView)? = nil,
        endPage: AnyView? = nil
    ) {
        self.totalPages = totalPages
        self._current = current
        self.pageImage = pageImage
        self.onPrefetchHint = onPrefetchHint
        self.progressionDirection = progressionDirection
        self.tapZonesEnabled = tapZonesEnabled
        self.swipeEnabled = swipeEnabled
        self.onCenterTap = onCenterTap
        _ = pageOffset
        self.pageOverlay = pageOverlay
        self.endPage = endPage
    }

    public var body: some View {
        ZStack {
            if showingEnd, let endPage {
                EndPageContainer(
                    content: endPage,
                    onLeftTap: { handleLeftTap() },
                    onRightTap: { handleRightTap() }
                )
            } else if let image {
                ZoomableImageView(
                    image: image,
                    onLeftTap: tapZonesEnabled ? { handleLeftTap() } : nil,
                    onCenterTap: tapZonesEnabled ? { onCenterTap() } : nil,
                    onRightTap: tapZonesEnabled ? { handleRightTap() } : nil,
                    overlayContent: pageOverlay.map { AnyView($0(current)) }
                )
            } else {
                ProgressView()
            }
        }
        .gesture(swipeEnabled ? swipeGesture : nil)
        .task(id: current) {
            await load(current)
        }
        .onChange(of: current) { _, _ in showingEnd = false }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 30, coordinateSpace: .local)
            .onEnded { value in
                if value.translation.width < -50 { handleRightTap() }
                else if value.translation.width > 50 { handleLeftTap() }
            }
    }

    private func handleLeftTap() {
        // LTR: left = previous; RTL: left = next
        let delta = (progressionDirection == .leftToRight) ? -1 : +1
        applyDelta(delta)
    }

    private func handleRightTap() {
        let delta = (progressionDirection == .leftToRight) ? +1 : -1
        applyDelta(delta)
    }

    private func applyDelta(_ delta: Int) {
        if showingEnd {
            if delta < 0 { showingEnd = false; MangaHaptic.tick.play() }
            return
        }
        let target = current + delta
        if target == totalPages, endPage != nil {
            showingEnd = true
            MangaHaptic.tick.play()
            return
        }
        guard target >= 0, target < totalPages else { return }
        current = target
    }

    private func load(_ index: Int) async {
        loadingIndex = index
        onPrefetchHint(index)
        for _ in 0..<30 {
            if let img = await pageImage(index) {
                if loadingIndex == index { image = img }
                return
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }
}
