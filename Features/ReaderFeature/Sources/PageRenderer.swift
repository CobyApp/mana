import SwiftUI
import ImageCacheKit

public protocol PageRenderer: View {
    init(
        totalPages: Int,
        current: Binding<Int>,
        cache: ImageCache,
        onPrefetchHint: @escaping (Int) -> Void
    )
}
