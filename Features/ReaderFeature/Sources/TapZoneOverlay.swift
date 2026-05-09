import SwiftUI

/// Two transparent halves; tapping a half calls the corresponding handler.
public struct TapZoneOverlay: View {
    var onLeftTap: () -> Void
    var onRightTap: () -> Void

    public init(onLeftTap: @escaping () -> Void, onRightTap: @escaping () -> Void) {
        self.onLeftTap = onLeftTap
        self.onRightTap = onRightTap
    }

    public var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                Color.clear
                    .frame(width: geo.size.width / 2, height: geo.size.height)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 1, perform: onLeftTap)
                Color.clear
                    .frame(width: geo.size.width / 2, height: geo.size.height)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 1, perform: onRightTap)
            }
        }
    }
}
