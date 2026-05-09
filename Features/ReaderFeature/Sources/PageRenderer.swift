import SwiftUI
import UIKit
import Domain

public protocol PageRenderer: View {
    init(
        totalPages: Int,
        current: Binding<Int>,
        pageImage: @escaping (Int) async -> UIImage?,
        onPrefetchHint: @escaping (Int) -> Void,
        progressionDirection: PageProgressionDirection,
        tapZonesEnabled: Bool,
        swipeEnabled: Bool,
        onCenterTap: @escaping () -> Void
    )
}
