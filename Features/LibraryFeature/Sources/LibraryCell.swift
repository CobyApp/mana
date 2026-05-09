import SwiftUI
import Domain
import DesignSystem

public struct LibraryCell: View {
    let comic: ComicItem

    public init(comic: ComicItem) {
        self.comic = comic
    }

    public var body: some View {
        VStack(spacing: Tokens.Spacing.s) {
            cover
                .aspectRatio(0.7, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.card))
                .shadow(color: .black.opacity(0.18), radius: 5, x: 0, y: 3)

            Text(comic.title)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .foregroundStyle(.primary)
        }
        .padding(.bottom, Tokens.Spacing.xs)
    }

    @ViewBuilder
    private var cover: some View {
        if let data = comic.coverThumbnail, let img = UIImage(data: data) {
            Image(uiImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipped()
        } else {
            ZStack {
                Tokens.Colors.backgroundSecondary
                Image(systemName: "book.closed")
                    .font(.title)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
