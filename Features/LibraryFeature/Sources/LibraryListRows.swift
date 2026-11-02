import SwiftUI
import UIKit
import Domain
import DesignSystem

/// Compact list-mode row for a comic (Android `LibraryCells.ComicRow`): [checkbox in selection]
/// [44×58 cover with a 6pt progress strip] [title, up to 2 lines] ["NP" page badge].
struct LibraryListRow: View {
    let comic: ComicItem
    let progress: ReadingProgress?
    let isSelectionMode: Bool
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 0) {
            if isSelectionMode {
                ZStack {
                    Rectangle().fill(isSelected ? Tokens.Colors.accent : Tokens.Colors.paper)
                    Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: Tokens.Stroke.regular)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(Tokens.Colors.ink)
                    }
                }
                .frame(width: 24, height: 24)
                .padding(.trailing, Tokens.Spacing.s)
            }
            ListCover(data: comic.coverThumbnail, iconSize: 20)
                .overlay(alignment: .bottom) {
                    if let ratio = progressRatio {
                        Rectangle()
                            .fill(Tokens.Colors.ink.opacity(0.85))
                            .frame(height: 6)
                            .overlay(alignment: .leading) {
                                GeometryReader { geo in
                                    Rectangle()
                                        .fill(Tokens.Colors.accent)
                                        .frame(width: geo.size.width * max(0.03, ratio))
                                }
                            }
                    }
                }
                .overlay(Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: Tokens.Stroke.hair))
                .frame(width: 44, height: 58)
                .padding(.trailing, Tokens.Spacing.m)
            Text(comic.title)
                .font(Tokens.Typography.subtitle)
                .foregroundStyle(Tokens.Colors.ink)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let pages = comic.pageCount, pages > 0 {
                Text(verbatim: "\(pages)P")
                    .font(Tokens.Typography.mono)
                    .foregroundStyle(Tokens.Colors.paper)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Tokens.Colors.ink)
                    .padding(.leading, Tokens.Spacing.s)
            }
        }
        .padding(Tokens.Spacing.s)
        .background(isSelected ? Tokens.Colors.accent.opacity(0.18) : Tokens.Colors.paper)
        .overlay(Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: Tokens.Stroke.regular))
        .contentShape(Rectangle())
    }

    private var progressRatio: CGFloat? {
        guard let p = progress, p.totalPages > 0 else { return nil }
        return min(1, max(0, CGFloat(p.lastPageIndex + 1) / CGFloat(p.totalPages)))
    }
}

/// Compact list-mode row for a folder (Android `LibraryCells.FolderRow`): [44×58 cover]
/// [folder icon + name] [accent "×N" badge]. Long-press asks to delete; accepts dropped comics.
struct FolderListRow: View {
    let folder: Folder
    let cover: Data?
    let comicCount: Int
    let onTap: () -> Void
    let onLongPress: () -> Void
    let onDropComic: (UUID) -> Void

    @State private var isTargeted = false

    var body: some View {
        HStack(spacing: 0) {
            FolderThumbnail(cover: cover)
                .overlay(Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: Tokens.Stroke.hair))
                .frame(width: 44, height: 58)
                .padding(.trailing, Tokens.Spacing.m)
            HStack(spacing: 6) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Tokens.Colors.ink)
                    .frame(width: 16, height: 16)
                Text(folder.name)
                    .font(Tokens.Typography.subtitle)
                    .foregroundStyle(Tokens.Colors.ink)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if comicCount > 0 {
                Text(verbatim: "×\(comicCount)")
                    .font(Tokens.Typography.mono)
                    .foregroundStyle(Tokens.Colors.ink)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Tokens.Colors.accent)
                    .overlay(Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: Tokens.Stroke.hair))
            }
        }
        .padding(Tokens.Spacing.s)
        .background(isTargeted ? Tokens.Colors.accent.opacity(0.15) : Tokens.Colors.paper)
        .overlay(
            Rectangle().strokeBorder(
                isTargeted ? Tokens.Colors.accent : Tokens.Colors.ink,
                lineWidth: isTargeted ? Tokens.Stroke.bold : Tokens.Stroke.regular
            )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            MangaHaptic.tap.play()
            onTap()
        }
        .onLongPressGesture(minimumDuration: 0.45) {
            MangaHaptic.longPress.play()
            onLongPress()
        }
        .dropDestination(for: ComicDragPayload.self) { payloads, _ in
            let ids = payloads.flatMap(\.comicIds)
            ids.forEach(onDropComic)
            return !ids.isEmpty
        } isTargeted: { isTargeted = $0 }
    }
}

/// "Continue reading" card at the top of the library root (Android `ContinueReadingBanner`):
/// paper card with bold ink stroke and a hard (5,6) ink shadow; cover, caption + title + thin
/// progress bar, and "page/total" on the right.
struct ContinueReadingBanner: View {
    let comic: ComicItem
    let progress: ReadingProgress
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                ListCover(data: comic.coverThumbnail, iconSize: 18)
                    .overlay(Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: Tokens.Stroke.regular))
                    .frame(width: 46, height: 62)
                    .padding(.trailing, Tokens.Spacing.m)
                VStack(alignment: .leading, spacing: 0) {
                    Text("library.continue_reading", bundle: .module)
                        .font(Tokens.Typography.caption)
                        .foregroundStyle(Tokens.Colors.accent)
                    Text(comic.title)
                        .font(Tokens.Typography.title)
                        .foregroundStyle(Tokens.Colors.ink)
                        .lineLimit(1)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Tokens.Colors.ink.opacity(0.18))
                            Rectangle()
                                .fill(Tokens.Colors.accent)
                                .frame(width: geo.size.width * fraction)
                        }
                    }
                    .frame(height: 6)
                    .padding(.top, 6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if progress.totalPages > 0 {
                    Text(verbatim: "\(progress.lastPageIndex + 1)/\(progress.totalPages)")
                        .font(Tokens.Typography.mono)
                        .foregroundStyle(Tokens.Colors.ink.opacity(0.7))
                        .padding(.leading, Tokens.Spacing.s)
                }
            }
            .padding(Tokens.Spacing.s)
            .background(Tokens.Colors.paper)
            .overlay(Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: Tokens.Stroke.bold))
            .background(Tokens.Colors.ink.offset(x: 5, y: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(MangaPressStyle(haptic: .tap))
    }

    private var fraction: CGFloat {
        guard progress.totalPages > 0 else { return 0.02 }
        let raw = CGFloat(progress.lastPageIndex + 1) / CGFloat(progress.totalPages)
        return min(1, max(0.02, raw))
    }
}

private struct ListCover: View {
    let data: Data?
    var iconSize: CGFloat = 18

    var body: some View {
        Group {
            if let data, let img = UIImage(data: data) {
                Color.clear.overlay {
                    Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
                }
            } else {
                ZStack {
                    Tokens.Colors.paper
                    HalftoneBackground(spacing: Tokens.Halftone.denseDotSpacing,
                                       radius: Tokens.Halftone.denseDotRadius)
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: iconSize, weight: .black))
                        .foregroundStyle(Tokens.Colors.ink)
                }
            }
        }
        .clipped()
    }
}
