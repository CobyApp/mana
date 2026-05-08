import SwiftUI
import UIKit

public protocol PageRenderer: View {
    init(
        totalPages: Int,
        current: Binding<Int>,
        pageImage: @escaping (Int) async -> UIImage?,
        onPrefetchHint: @escaping (Int) -> Void
    )
}
