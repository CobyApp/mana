import SwiftUI
import UIKit
import SharedUI

public struct SinglePageRenderer: View, PageRenderer {
    let totalPages: Int
    @Binding var current: Int
    let pageImage: (Int) async -> UIImage?
    let onPrefetchHint: (Int) -> Void

    @State private var image: UIImage?
    @State private var loadingIndex: Int?

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
        ZStack {
            if let image {
                ZoomableImageView(image: image)
            } else {
                ProgressView()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .onEnded { value in
                    if value.translation.width < -50, current < totalPages - 1 {
                        current += 1
                    } else if value.translation.width > 50, current > 0 {
                        current -= 1
                    }
                }
        )
        .task(id: current) {
            await load(current)
        }
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
