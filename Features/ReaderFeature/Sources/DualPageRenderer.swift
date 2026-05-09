import SwiftUI
import UIKit
import Domain
import SharedUI

public struct DualPageRenderer: View, PageRenderer {
    let totalPages: Int
    @Binding var current: Int
    let pageImage: (Int) async -> UIImage?
    let onPrefetchHint: (Int) -> Void
    let progressionDirection: PageProgressionDirection
    let tapZonesEnabled: Bool
    let swipeEnabled: Bool

    @State private var leftImage: UIImage?
    @State private var rightImage: UIImage?

    public init(
        totalPages: Int,
        current: Binding<Int>,
        pageImage: @escaping (Int) async -> UIImage?,
        onPrefetchHint: @escaping (Int) -> Void,
        progressionDirection: PageProgressionDirection = .leftToRight,
        tapZonesEnabled: Bool = true,
        swipeEnabled: Bool = true
    ) {
        self.totalPages = totalPages
        self._current = current
        self.pageImage = pageImage
        self.onPrefetchHint = onPrefetchHint
        self.progressionDirection = progressionDirection
        self.tapZonesEnabled = tapZonesEnabled
        self.swipeEnabled = swipeEnabled
    }

    public var body: some View {
        ZStack {
            HStack(spacing: 0) {
                pane(image: progressionDirection == .leftToRight ? leftImage : rightImage)
                pane(image: progressionDirection == .leftToRight ? rightImage : leftImage)
            }
            if tapZonesEnabled {
                TapZoneOverlay(
                    onLeftTap: { applyDelta((progressionDirection == .leftToRight) ? -2 : +2) },
                    onRightTap: { applyDelta((progressionDirection == .leftToRight) ? +2 : -2) }
                )
            }
        }
        .gesture(swipeEnabled ? swipeGesture : nil)
        .task(id: current) {
            await loadPair()
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 30, coordinateSpace: .local)
            .onEnded { value in
                if value.translation.width < -50 {
                    applyDelta((progressionDirection == .leftToRight) ? +2 : -2)
                } else if value.translation.width > 50 {
                    applyDelta((progressionDirection == .leftToRight) ? -2 : +2)
                }
            }
    }

    private func applyDelta(_ delta: Int) {
        let target = current + delta
        guard target >= 0, target < totalPages else { return }
        current = target
    }

    @ViewBuilder
    private func pane(image: UIImage?) -> some View {
        if let image {
            ZoomableImageView(image: image)
        } else {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func loadPair() async {
        let left = current
        let right = current + 1
        onPrefetchHint(left)
        if right < totalPages { onPrefetchHint(right) }
        async let leftImg = wait(for: left)
        async let rightImg: UIImage? = right < totalPages ? wait(for: right) : nil
        let (l, r) = await (leftImg, rightImg)
        if current == left {
            leftImage = l
            rightImage = r
        }
    }

    private func wait(for index: Int) async -> UIImage? {
        for _ in 0..<30 {
            if let img = await pageImage(index) { return img }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        return nil
    }
}
