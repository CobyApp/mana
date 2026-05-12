import SwiftUI
import Domain
import DesignSystem

public struct LibraryCell: View {
    let comic: ComicItem
    let progress: ReadingProgress?
    let isSelectionMode: Bool
    let isSelected: Bool

    public init(
        comic: ComicItem,
        progress: ReadingProgress? = nil,
        isSelectionMode: Bool = false,
        isSelected: Bool = false
    ) {
        self.comic = comic
        self.progress = progress
        self.isSelectionMode = isSelectionMode
        self.isSelected = isSelected
    }

    public var body: some View {
        VStack(spacing: Tokens.Spacing.s) {
            MangaPanel(
                surface: .paper,
                tiltIndex: tiltIndex,
                cornerRadius: Tokens.Radius.panel,
                strokeWidth: Tokens.Stroke.panel
            ) {
                cover
                    .aspectRatio(0.7, contentMode: .fit)
                    .frame(maxWidth: .infinity)
            }
            .overlay(alignment: .topLeading) {
                if isSelectionMode {
                    selectionBadge
                        .padding(8)
                }
            }
            .overlay(alignment: .bottomLeading) {
                if !isSelectionMode {
                    pageBadge
                        .padding(.horizontal, 6)
                        .padding(.bottom, 18)
                }
            }
            .opacity(isSelectionMode && !isSelected ? 0.55 : 1.0)
            .glitch(trigger: isSelected, intensity: 6)

            Text(comic.title)
                .font(Tokens.Typography.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .foregroundStyle(Tokens.Colors.ink)
        }
        .padding(.bottom, Tokens.Spacing.xs)
        .padding(.trailing, 4)   // breathing room for the offset ink shadow
        .padding(.bottom, 5)
    }

    private var tiltIndex: Int {
        // Stable per-comic so tilt doesn't change across reloads
        abs(comic.id.hashValue)
    }

    @ViewBuilder
    private var cover: some View {
        ZStack(alignment: .bottom) {
            if let data = comic.coverThumbnail, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                ZStack {
                    Tokens.Colors.paper
                    HalftoneBackground(spacing: Tokens.Halftone.denseDotSpacing,
                                       radius: Tokens.Halftone.denseDotRadius)
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 36, weight: .black))
                        .foregroundStyle(Tokens.Colors.ink)
                }
            }
            progressIndicator
        }
    }

    @ViewBuilder
    private var progressIndicator: some View {
        if let ratio = progressRatio {
            Rectangle()
                .fill(Tokens.Colors.ink.opacity(0.85))
                .frame(height: 12)
                .overlay(alignment: .leading) {
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Tokens.Colors.accent)
                            // Guarantee a visible sliver even when the ratio
                            // resolves to a couple of percent on long comics.
                            .frame(width: max(14, geo.size.width * CGFloat(ratio)))
                    }
                }
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Tokens.Colors.paper.opacity(0.7))
                        .frame(height: 1)
                }
        }
    }

    /// Any persisted progress means the comic is in progress — the reader
    /// only writes a ReadingProgress row after the user actually flips a
    /// page, so the mere presence of a row is the signal we want.
    private var progressRatio: Double? {
        guard let p = progress, p.totalPages > 0 else { return nil }
        let raw = Double(p.lastPageIndex + 1) / Double(p.totalPages)
        return min(1.0, max(0.0, raw))
    }

    private var selectionBadge: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Tokens.Colors.accent : Tokens.Colors.paper)
            Circle()
                .strokeBorder(Tokens.Colors.ink, lineWidth: Tokens.Stroke.bold)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Tokens.Colors.ink)
            }
        }
        .frame(width: 28, height: 28)
    }

    @ViewBuilder
    private var pageBadge: some View {
        if let pages = comic.pageCount, pages > 0 {
            Text("\(pages)P")
                .font(Tokens.Typography.mono)
                .foregroundStyle(Tokens.Colors.paper)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Tokens.Colors.ink)
                .overlay(
                    Rectangle()
                        .strokeBorder(Tokens.Colors.paper, lineWidth: 1)
                        .padding(1)
                )
        }
    }
}
