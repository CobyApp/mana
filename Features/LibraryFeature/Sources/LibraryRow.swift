import SwiftUI
import Domain
import DesignSystem

public struct LibraryRow: View {
    let comic: ComicItem
    @State private var isLocallyAvailable: Bool = false

    public init(comic: ComicItem) {
        self.comic = comic
    }

    public var body: some View {
        HStack(spacing: Tokens.Spacing.m) {
            cover
                .frame(width: 60, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.card))
            VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
                Text(comic.title).font(.headline)
                HStack(spacing: 4) {
                    Text(comic.format.rawValue.uppercased())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !isLocallyAvailable {
                        Image(systemName: "icloud.and.arrow.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, Tokens.Spacing.s)
        .task(id: comic.url) {
            // Re-check availability whenever the row appears or url changes.
            // Plan 4 polish: subscribe to FileSyncService events for live updates.
            isLocallyAvailable = FileManager.default.fileExists(atPath: comic.url.path)
        }
    }

    @ViewBuilder
    private var cover: some View {
        if let data = comic.coverThumbnail, let img = UIImage(data: data) {
            Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
        } else {
            RoundedRectangle(cornerRadius: Tokens.Radius.card)
                .fill(Color.gray.opacity(0.3))
        }
    }
}
