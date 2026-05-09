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
    let onCenterTap: () -> Void
    let pageOffset: Bool

    /// The two pages composited side-by-side into a single image, so they render flush
    /// (no gap) and the whole spread is zoomable as one unit via `ZoomableImageView`.
    @State private var spreadImage: UIImage?

    public init(
        totalPages: Int,
        current: Binding<Int>,
        pageImage: @escaping (Int) async -> UIImage?,
        onPrefetchHint: @escaping (Int) -> Void,
        progressionDirection: PageProgressionDirection = .leftToRight,
        tapZonesEnabled: Bool = true,
        swipeEnabled: Bool = true,
        onCenterTap: @escaping () -> Void = {},
        pageOffset: Bool = false
    ) {
        self.totalPages = totalPages
        self._current = current
        self.pageImage = pageImage
        self.onPrefetchHint = onPrefetchHint
        self.progressionDirection = progressionDirection
        self.tapZonesEnabled = tapZonesEnabled
        self.swipeEnabled = swipeEnabled
        self.onCenterTap = onCenterTap
        self.pageOffset = pageOffset
    }

    /// Returns (leftPageIndex, rightPageIndex) — visual pair.
    /// nil means blank slot in the composite.
    private func logicalPair() -> (Int?, Int?) {
        if pageOffset {
            if current == 0 {
                return progressionDirection == .leftToRight ? (nil, 0) : (0, nil)
            }
            let p1 = current
            let p2 = current + 1
            let validP2: Int? = p2 < totalPages ? p2 : nil
            return progressionDirection == .leftToRight ? (p1, validP2) : (validP2, p1)
        } else {
            let p1 = current
            let p2 = current + 1
            let validP2: Int? = p2 < totalPages ? p2 : nil
            return progressionDirection == .leftToRight ? (p1, validP2) : (validP2, p1)
        }
    }

    public var body: some View {
        ZStack {
            if let spreadImage {
                ZoomableImageView(image: spreadImage)
            } else {
                ProgressView().tint(.white)
            }
            if tapZonesEnabled {
                TapZoneOverlay(
                    onLeftTap: { applyDelta(.left) },
                    onCenterTap: { onCenterTap() },
                    onRightTap: { applyDelta(.right) }
                )
            }
        }
        .gesture(swipeEnabled ? swipeGesture : nil)
        .task(id: TaskKey(current: current, offset: pageOffset)) {
            await loadPair()
        }
    }

    private enum TapDir { case left, right }

    private func applyDelta(_ dir: TapDir) {
        let advance: Bool
        switch (dir, progressionDirection) {
        case (.left, .leftToRight): advance = false
        case (.right, .leftToRight): advance = true
        case (.left, .rightToLeft): advance = true
        case (.right, .rightToLeft): advance = false
        }
        if advance { goNext() } else { goPrev() }
    }

    private func goNext() {
        if pageOffset {
            let next = current == 0 ? 1 : current + 2
            if next < totalPages { current = next }
        } else {
            let next = current + 2
            if next < totalPages { current = next }
        }
    }

    private func goPrev() {
        if pageOffset {
            if current == 0 { return }
            if current == 1 { current = 0; return }
            current -= 2
        } else {
            if current == 0 { return }
            current -= 2
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 30, coordinateSpace: .local)
            .onEnded { value in
                if value.translation.width < -50 { applyDelta(.right) }
                else if value.translation.width > 50 { applyDelta(.left) }
            }
    }

    private func loadPair() async {
        let pair = logicalPair()
        let leftIdx = pair.0
        let rightIdx = pair.1

        if let l = leftIdx { onPrefetchHint(l) }
        if let r = rightIdx { onPrefetchHint(r) }

        let leftImg: UIImage?
        let rightImg: UIImage?
        if let l = leftIdx { leftImg = await wait(for: l) } else { leftImg = nil }
        if let r = rightIdx { rightImg = await wait(for: r) } else { rightImg = nil }

        spreadImage = Self.compose(left: leftImg, right: rightImg)
    }

    private func wait(for index: Int) async -> UIImage? {
        for _ in 0..<30 {
            if let img = await pageImage(index) { return img }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        return nil
    }

    /// Composes two pages into a single side-by-side image. Pages render flush —
    /// the right edge of the left page touches the left edge of the right page.
    /// A nil slot becomes a transparent half (used for cover-alone in offset mode).
    private static func compose(left: UIImage?, right: UIImage?) -> UIImage? {
        guard left != nil || right != nil else { return nil }

        // Use the taller image's height as the canvas height, and use the matching
        // page's natural width for the missing side so cover-alone shows at full
        // half-width without weird scaling.
        let lw = left?.size.width ?? right?.size.width ?? 1
        let lh = left?.size.height ?? right?.size.height ?? 1
        let rw = right?.size.width ?? left?.size.width ?? 1
        let rh = right?.size.height ?? left?.size.height ?? 1

        let height = max(lh, rh)
        let width = lw + rw

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
        return renderer.image { ctx in
            if let left {
                let yOffset = (height - left.size.height) / 2
                left.draw(at: CGPoint(x: 0, y: yOffset))
            }
            if let right {
                let yOffset = (height - right.size.height) / 2
                right.draw(at: CGPoint(x: lw, y: yOffset))
            }
        }
    }

    /// Stable identifier for `.task(id:)` so it re-runs when current OR offset changes.
    private struct TaskKey: Hashable {
        let current: Int
        let offset: Bool
    }
}
