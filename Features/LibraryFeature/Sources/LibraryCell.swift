import SwiftUI
import Domain
import DesignSystem

public struct LibraryCell: View {
    let comic: ComicItem
    let isSelectionMode: Bool
    let isSelected: Bool

    public init(comic: ComicItem, isSelectionMode: Bool = false, isSelected: Bool = false) {
        self.comic = comic
        self.isSelectionMode = isSelectionMode
        self.isSelected = isSelected
    }

    public var body: some View {
        VStack(spacing: Tokens.Spacing.s) {
            cover
                .aspectRatio(0.7, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.card))
                .shadow(color: .black.opacity(0.18), radius: 5, x: 0, y: 3)
                .overlay(alignment: .topLeading) {
                    if isSelectionMode {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundStyle(isSelected ? Tokens.Colors.accent : .white.opacity(0.9))
                            .background(.black.opacity(0.3), in: .circle)
                            .padding(8)
                    }
                }
                .opacity(isSelectionMode && !isSelected ? 0.6 : 1.0)

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
