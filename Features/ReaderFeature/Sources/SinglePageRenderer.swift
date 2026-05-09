import SwiftUI
import UIKit
import Domain
import SharedUI

public struct SinglePageRenderer: View, PageRenderer {
    let totalPages: Int
    @Binding var current: Int
    let pageImage: (Int) async -> UIImage?
    let onPrefetchHint: (Int) -> Void
    let progressionDirection: PageProgressionDirection
    let tapZonesEnabled: Bool
    let swipeEnabled: Bool
    let onCenterTap: () -> Void

    @State private var image: UIImage?
    @State private var loadingIndex: Int?

    public init(
        totalPages: Int,
        current: Binding<Int>,
        pageImage: @escaping (Int) async -> UIImage?,
        onPrefetchHint: @escaping (Int) -> Void,
        progressionDirection: PageProgressionDirection = .leftToRight,
        tapZonesEnabled: Bool = true,
        swipeEnabled: Bool = true,
        onCenterTap: @escaping () -> Void = {}
    ) {
        self.totalPages = totalPages
        self._current = current
        self.pageImage = pageImage
        self.onPrefetchHint = onPrefetchHint
        self.progressionDirection = progressionDirection
        self.tapZonesEnabled = tapZonesEnabled
        self.swipeEnabled = swipeEnabled
        self.onCenterTap = onCenterTap
    }

    public var body: some View {
        ZStack {
            if let image {
                ZoomableImageView(image: image)
            } else {
                ProgressView()
            }
            if tapZonesEnabled {
                TapZoneOverlay(
                    onLeftTap: { handleLeftTap() },
                    onCenterTap: { onCenterTap() },
                    onRightTap: { handleRightTap() }
                )
            }
        }
        .gesture(swipeEnabled ? swipeGesture : nil)
        .task(id: current) {
            await load(current)
        }
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
        let target = current + delta
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
