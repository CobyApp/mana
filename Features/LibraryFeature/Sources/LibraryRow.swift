import SwiftUI
import Domain
import DesignSystem

public struct LibraryRow: View {
    let comic: ComicItem

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
                Text(comic.format.rawValue.uppercased())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, Tokens.Spacing.s)
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
