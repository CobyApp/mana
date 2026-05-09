import SwiftUI
import UIKit
import Domain

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

    @State private var leftImage: UIImage?
    @State private var rightImage: UIImage?

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
    /// nil means blank pane.
    ///
    /// Offset mode:
    ///   current == 0: cover alone → LTR: (nil, 0)  RTL: (0, nil)
    ///   current >= 1 (odd): show (current, current+1)
    ///
    /// Normal mode:
    ///   current always even: show (current, current+1)
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
        let pair = logicalPair()
        let hasLeft = pair.0 != nil
        let hasRight = pair.1 != nil

        return ZStack {
            HStack(spacing: 0) {
                pane(
                    image: leftImage,
                    alignmentInPane: progressionDirection == .leftToRight ? .trailing : .leading
                )
                .opacity(hasLeft ? 1 : 0)
                pane(
                    image: rightImage,
                    alignmentInPane: progressionDirection == .leftToRight ? .leading : .trailing
                )
                .opacity(hasRight ? 1 : 0)
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
            // 0 → 1, then 1 → 3, 3 → 5, ...
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

    @ViewBuilder
    private func pane(image: UIImage?, alignmentInPane: Alignment) -> some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignmentInPane)
        } else {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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

        leftImage = leftImg
        rightImage = rightImg
    }

    private func wait(for index: Int) async -> UIImage? {
        for _ in 0..<30 {
            if let img = await pageImage(index) { return img }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        return nil
    }

    /// Stable identifier for `.task(id:)` so it re-runs when current OR offset changes.
    private struct TaskKey: Hashable {
        let current: Int
        let offset: Bool
    }
}
