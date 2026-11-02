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
        onCenterTap: @escaping () -> Void,
        pageOffset: Bool,
        pageOverlay: ((Int) -> AnyView)?,
        endPage: AnyView?
    )
}

/// Hosts a renderer's trailing "end page" (e.g. the next-chapter card) with the same left/right
/// third tap zones as a real page (the renderer's own swipe gesture still applies), so it can be
/// paged back out of. `content` should keep its background non-hit-testable.
struct EndPageContainer: View {
    let content: AnyView
    let onLeftTap: () -> Void
    let onRightTap: () -> Void

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                Color.clear.contentShape(Rectangle()).onTapGesture(perform: onLeftTap)
                Color.clear
                Color.clear.contentShape(Rectangle()).onTapGesture(perform: onRightTap)
            }
            content
        }
    }
}
