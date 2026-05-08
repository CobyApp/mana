import SwiftUI
import UIKit
import SharedUI

public struct DualPageRenderer: View, PageRenderer {
    let totalPages: Int
    @Binding var current: Int
    let pageImage: (Int) async -> UIImage?
    let onPrefetchHint: (Int) -> Void

    @State private var leftImage: UIImage?
    @State private var rightImage: UIImage?

    public init(
        totalPages: Int,
        current: Binding<Int>,
        pageImage: @escaping (Int) async -> UIImage?,
        onPrefetchHint: @escaping (Int) -> Void
    ) {
        self.totalPages = totalPages
        self._current = current
        self.pageImage = pageImage
        self.onPrefetchHint = onPrefetchHint
    }

    public var body: some View {
        HStack(spacing: 0) {
            pane(image: leftImage)
            pane(image: rightImage)
        }
        .gesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .onEnded { value in
                    if value.translation.width < -50, current + 2 < totalPages {
                        current += 2
                    } else if value.translation.width > 50, current >= 2 {
                        current -= 2
                    }
                }
        )
        .task(id: current) {
            await loadPair()
        }
    }

    @ViewBuilder
    private func pane(image: UIImage?) -> some View {
        if let image {
            ZoomableImageView(image: image)
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
