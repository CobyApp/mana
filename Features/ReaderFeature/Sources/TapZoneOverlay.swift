import SwiftUI

/// Three transparent vertical zones; tapping each calls the corresponding handler.
/// Left 25% | Center 50% | Right 25%
public struct TapZoneOverlay: View {
    var onLeftTap: () -> Void
    var onCenterTap: () -> Void
    var onRightTap: () -> Void

    public init(
        onLeftTap: @escaping () -> Void,
        onCenterTap: @escaping () -> Void,
        onRightTap: @escaping () -> Void
    ) {
        self.onLeftTap = onLeftTap
        self.onCenterTap = onCenterTap
        self.onRightTap = onRightTap
    }

    public var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                Color.clear
                    .frame(width: geo.size.width * 0.25, height: geo.size.height)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 1, perform: onLeftTap)
                Color.clear
                    .frame(width: geo.size.width * 0.50, height: geo.size.height)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 1, perform: onCenterTap)
                Color.clear
                    .frame(width: geo.size.width * 0.25, height: geo.size.height)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 1, perform: onRightTap)
            }
        }
    }
}
