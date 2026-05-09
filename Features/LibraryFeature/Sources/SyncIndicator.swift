import SwiftUI
import DesignSystem

public struct SyncIndicator: View {
    let status: SyncStatus

    public init(status: SyncStatus) {
        self.status = status
    }

    public var body: some View {
        switch status {
        case .unavailable:
            Image(systemName: "icloud.slash")
                .foregroundStyle(.secondary)
                .accessibilityLabel(Text("library.sync.unavailable", bundle: .module))
        case .idle:
            Image(systemName: "checkmark.icloud")
                .foregroundStyle(.secondary)
                .accessibilityLabel(Text("library.sync.idle", bundle: .module))
        case .active:
            Image(systemName: "icloud.and.arrow.up.and.arrow.down")
                .symbolEffect(.pulse, options: .repeating)
                .foregroundStyle(Tokens.Colors.accent)
                .accessibilityLabel(Text("library.sync.active", bundle: .module))
        }
    }
}
