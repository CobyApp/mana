import SwiftUI
import UIKit
import ImageCacheKit
import SharedUI

public struct SinglePageRenderer: View, PageRenderer {
    let totalPages: Int
    @Binding var current: Int
    let cache: ImageCache
    let onPrefetchHint: (Int) -> Void

    @State private var image: UIImage?
    @State private var loadingIndex: Int?

    @Environment(\.comicId) private var environmentComicId

    public init(
        totalPages: Int,
        current: Binding<Int>,
        cache: ImageCache,
        onPrefetchHint: @escaping (Int) -> Void
    ) {
        self.totalPages = totalPages
        self._current = current
        self.cache = cache
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
        let key = PageKey(comicId: environmentComicId, pageIndex: index)
        for _ in 0..<60 {
            if let data = await cache.data(for: key), let img = UIImage(data: data) {
                if loadingIndex == index { image = img }
                return
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }
}

private struct ComicIdKey: EnvironmentKey {
    static let defaultValue: UUID = UUID()
}

extension EnvironmentValues {
    public var comicId: UUID {
        get { self[ComicIdKey.self] }
        set { self[ComicIdKey.self] = newValue }
    }
}
