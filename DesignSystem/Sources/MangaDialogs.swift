import SwiftUI

/// Full-screen manga dialog host: 45% ink scrim that fades in, panel springs up from 0.92.
/// Put it in an `.overlay { }` of the screen root; tapping the scrim calls `onDismiss`.
/// Ported from Android `ManaDialogs.ManaDialogScaffold`.
public struct MangaDialogHost<Panel: View>: View {
    private let isPresented: Bool
    private let onDismiss: () -> Void
    private let panel: Panel

    public init(isPresented: Bool, onDismiss: @escaping () -> Void, @ViewBuilder panel: () -> Panel) {
        self.isPresented = isPresented
        self.onDismiss = onDismiss
        self.panel = panel()
    }

    public var body: some View {
        ZStack {
            if isPresented {
                Tokens.Colors.ink.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture(perform: onDismiss)
                    .transition(.opacity)
                panel
                    .padding(Tokens.Spacing.l)
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isPresented)
    }
}

/// Manga-styled dialog panel: tilted SoundEffect title, body, then one or two equal-width
/// buttons. Paper card, ink stroke, hard ink offset shadow (6,7), max width 420.
public struct MangaDialogPanel<Body: View>: View {
    private let title: String
    private let content: Body
    private let cancelTitle: String?
    private let confirmTitle: String
    private let confirmIsAccent: Bool
    private let onCancel: () -> Void
    private let onConfirm: () -> Void

    public init(
        title: String,
        cancelTitle: String?,
        confirmTitle: String,
        confirmIsAccent: Bool = true,
        onCancel: @escaping () -> Void = {},
        onConfirm: @escaping () -> Void,
        @ViewBuilder content: () -> Body
    ) {
        self.title = title
        self.content = content()
        self.cancelTitle = cancelTitle
        self.confirmTitle = confirmTitle
        self.confirmIsAccent = confirmIsAccent
        self.onCancel = onCancel
        self.onConfirm = onConfirm
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.l) {
            SoundEffectText(
                title.uppercased(),
                font: Tokens.Typography.displayM,
                fill: Tokens.Colors.accent,
                stroke: Tokens.Colors.ink,
                strokeWidth: 4,
                tilt: -3,
                shadowOffset: .init(width: 3, height: 4)
            )
            content
            HStack(spacing: Tokens.Spacing.m) {
                if let cancelTitle {
                    MangaDialogButton(title: cancelTitle, isAccent: false, action: onCancel)
                }
                MangaDialogButton(title: confirmTitle, isAccent: confirmIsAccent, action: onConfirm)
            }
        }
        .padding(Tokens.Spacing.l)
        .frame(maxWidth: 420)
        .background(Tokens.Colors.paper)
        .overlay(Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: Tokens.Stroke.regular))
        .background(Rectangle().fill(Tokens.Colors.ink).offset(x: 6, y: 7))
    }
}

public extension MangaDialogPanel where Body == MangaDialogMessage {
    /// Plain confirm: title + message text.
    init(
        title: String,
        message: String,
        cancelTitle: String?,
        confirmTitle: String,
        confirmIsAccent: Bool = true,
        onCancel: @escaping () -> Void = {},
        onConfirm: @escaping () -> Void
    ) {
        self.init(
            title: title, cancelTitle: cancelTitle, confirmTitle: confirmTitle,
            confirmIsAccent: confirmIsAccent, onCancel: onCancel, onConfirm: onConfirm
        ) { MangaDialogMessage(message) }
    }
}

public struct MangaDialogMessage: View {
    private let text: String
    public init(_ text: String) { self.text = text }
    public var body: some View {
        Text(verbatim: text)
            .font(Tokens.Typography.body)
            .foregroundStyle(Tokens.Colors.ink)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Full-width dialog button; accent variant gets the ink offset shadow.
public struct MangaDialogButton: View {
    private let title: String
    private let isAccent: Bool
    private let action: () -> Void

    public init(title: String, isAccent: Bool, action: @escaping () -> Void) {
        self.title = title
        self.isAccent = isAccent
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(verbatim: title)
                .font(Tokens.Typography.title)
                .foregroundStyle(isAccent ? Tokens.Colors.paper : Tokens.Colors.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isAccent ? Tokens.Colors.accent : Tokens.Colors.paper)
                .overlay(Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: Tokens.Stroke.regular))
                .background {
                    if isAccent { Rectangle().fill(Tokens.Colors.ink).offset(x: 4, y: 5) }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(MangaPressStyle(haptic: isAccent ? .confirm : .tap))
    }
}
