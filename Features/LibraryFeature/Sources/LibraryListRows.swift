import SwiftUI
import UIKit
import Domain
import DesignSystem

/// Compact list-mode row for a comic: small cover, title, format · pages, and a progress bar.
struct LibraryListRow: View {
    let comic: ComicItem
    let progress: ReadingProgress?
    let isSelectionMode: Bool
    let isSelected: Bool

    var body: some View {
        HStack(spacing: Tokens.Spacing.m) {
            if isSelectionMode {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(isSelected ? Tokens.Colors.accent : Tokens.Colors.ink.opacity(0.4))
            }
            ListCover(data: comic.coverThumbnail)
                .frame(width: 46, height: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text(comic.title)
                    .font(Tokens.Typography.subtitle)
                    .foregroundStyle(Tokens.Colors.ink)
                    .lineLimit(2)
                Text(verbatim: meta)
                    .font(Tokens.Typography.caption)
                    .foregroundStyle(Tokens.Colors.ink.opacity(0.55))
                if let ratio = progressRatio {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Tokens.Colors.ink.opacity(0.12))
                            Rectangle().fill(Tokens.Colors.accent).frame(width: geo.size.width * ratio)
                        }
                    }
                    .frame(height: 5)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Tokens.Spacing.s)
        .background(Tokens.Colors.paper)
        .overlay(Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: 1.5))
        .opacity(isSelectionMode && !isSelected ? 0.6 : 1)
        .contentShape(Rectangle())
    }

    private var meta: String {
        var parts = [comic.format.rawValue.uppercased()]
        if let pages = comic.pageCount { parts.append("\(pages)p") }
        if let p = progress, p.totalPages > 0 { parts.append("\(p.lastPageIndex + 1)/\(p.totalPages)") }
        return parts.joined(separator: " · ")
    }

    private var progressRatio: CGFloat? {
        guard let p = progress, p.totalPages > 0 else { return nil }
        return min(1, max(0, CGFloat(p.lastPageIndex + 1) / CGFloat(p.totalPages)))
    }
}

/// Compact list-mode row for a folder; still accepts dropped comics like `FolderCard`.
struct FolderListRow: View {
    let folder: Folder
    let comicCount: Int
    let onTap: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    let onDropComic: (UUID) -> Void

    @State private var isTargeted = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Tokens.Spacing.m) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Tokens.Colors.accent)
                    .frame(width: 46, height: 46)
                Text(folder.name)
                    .font(Tokens.Typography.subtitle)
                    .foregroundStyle(Tokens.Colors.ink)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(verbatim: "×\(comicCount)")
                    .font(Tokens.Typography.mono)
                    .foregroundStyle(Tokens.Colors.ink.opacity(0.6))
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Tokens.Colors.ink.opacity(0.4))
            }
            .padding(Tokens.Spacing.s)
            .background(isTargeted ? Tokens.Colors.accent.opacity(0.15) : Tokens.Colors.paper)
            .overlay(Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: isTargeted ? 3 : 1.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(action: onRename) {
                Label { Text("library.rename_folder", bundle: .module) } icon: { Image(systemName: "pencil") }
            }
            Button(role: .destructive, action: onDelete) {
                Label { Text("library.delete", bundle: .module) } icon: { Image(systemName: "trash") }
            }
        }
        .dropDestination(for: ComicDragPayload.self) { payloads, _ in
            let ids = payloads.flatMap(\.comicIds)
            ids.forEach(onDropComic)
            return !ids.isEmpty
        } isTargeted: { isTargeted = $0 }
    }
}

/// "Continue reading" card at the top of the library root: last unfinished comic + progress.
struct ContinueReadingBanner: View {
    let comic: ComicItem
    let progress: ReadingProgress
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Tokens.Spacing.m) {
                ListCover(data: comic.coverThumbnail)
                    .frame(width: 44, height: 62)
                VStack(alignment: .leading, spacing: 4) {
                    Text("library.continue_reading", bundle: .module)
                        .font(Tokens.Typography.caption)
                        .foregroundStyle(Tokens.Colors.paper.opacity(0.7))
                        .textCase(.uppercase)
                    Text(comic.title)
                        .font(Tokens.Typography.subtitle)
                        .foregroundStyle(Tokens.Colors.paper)
                        .lineLimit(1)
                    Text(verbatim: "\(progress.lastPageIndex + 1) / \(progress.totalPages)")
                        .font(Tokens.Typography.mono)
                        .foregroundStyle(Tokens.Colors.accent)
                }
                Spacer(minLength: 0)
                Image(systemName: "play.fill")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Tokens.Colors.paper)
            }
            .padding(Tokens.Spacing.s)
            .background(Tokens.Colors.ink)
            .overlay(Rectangle().strokeBorder(Tokens.Colors.paper, lineWidth: 1.5).padding(2))
            .background(Tokens.Colors.accent.offset(x: 4, y: 4))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct ListCover: View {
    let data: Data?

    var body: some View {
        Group {
            if let data, let img = UIImage(data: data) {
                Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Tokens.Colors.paper
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(Tokens.Colors.ink)
                }
            }
        }
        .clipped()
        .overlay(Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: 1.2))
    }
}
