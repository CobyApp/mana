import SwiftUI
import UIKit

/// Semantic haptics, mirroring Android `ManaHaptics`.
public enum MangaHaptic: Sendable {
    case tick      // toggles, selection
    case tap       // navigation
    case confirm   // accent / committing actions
    case longPress
    case none

    @MainActor
    public func play() {
        switch self {
        case .tick: UISelectionFeedbackGenerator().selectionChanged()
        case .tap: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .confirm: UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .longPress: UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .none: break
        }
    }
}

/// Spring scale-down while pressed (0.95) + a semantic haptic on release. Use instead of
/// `.plain` for manga chips/badges/buttons. Ported from Android `Modifier.pressable`.
public struct MangaPressStyle: ButtonStyle {
    private let haptic: MangaHaptic
    private let pressedScale: CGFloat

    public init(haptic: MangaHaptic = .tap, pressedScale: CGFloat = 0.95) {
        self.haptic = haptic
        self.pressedScale = pressedScale
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.45), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if !pressed { haptic.play() }
            }
    }
}
