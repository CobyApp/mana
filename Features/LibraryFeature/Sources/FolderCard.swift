import SwiftUI
import CoreTransferable
import Domain
import DesignSystem

/// Grid folder card (Android `LibraryCells.FolderCard`): one cover with a "FOLDER" ink tag and
/// an accent "×N" badge on top. Tap opens; long-press asks to delete; accepts dropped comics.
public struct FolderCard: View {
    let folder: Folder
    let cover: Data?
    let count: Int
    var onTap: () -> Void
    var onLongPress: () -> Void
    var onDropComic: (UUID) -> Void

    @State private var isTargeted = false

    public init(
        folder: Folder,
        cover: Data?,
        count: Int,
        onTap: @escaping () -> Void,
        onLongPress: @escaping () -> Void,
        onDropComic: @escaping (UUID) -> Void
    ) {
        self.folder = folder
        self.cover = cover
        self.count = count
        self.onTap = onTap
        self.onLongPress = onLongPress
        self.onDropComic = onDropComic
    }

    public var body: some View {
        VStack(spacing: Tokens.Spacing.s) {
            MangaPanel(
                surface: .paper,
                tiltIndex: tiltIndex,
                cornerRadius: Tokens.Radius.panel,
                strokeWidth: Tokens.Stroke.panel
            ) {
                FolderThumbnail(cover: cover)
                    .overlay(alignment: .top) {
                        HStack {
                            folderTag
                            Spacer()
                            countBadge
                        }
                        .padding(8)
                    }
                    .aspectRatio(0.7, contentMode: .fit)
                    .frame(maxWidth: .infinity)
            }
            .overlay(alignment: .center) {
                if isTargeted {
                    RoundedRectangle(cornerRadius: Tokens.Radius.panel, style: .continuous)
                        .strokeBorder(
                            Tokens.Colors.accent,
                            style: StrokeStyle(lineWidth: Tokens.Stroke.bold, dash: [8, 4])
                        )
                        .padding(2)
                }
            }
            .glitch(trigger: isTargeted, intensity: 5)

            Text(folder.name)
                .font(Tokens.Typography.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .foregroundStyle(Tokens.Colors.ink)
        }
        .padding(.bottom, Tokens.Spacing.xs)
        .padding(.trailing, 4)
        .padding(.bottom, 5)
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
            for payload in payloads {
                for comicId in payload.comicIds {
                    onDropComic(comicId)
                }
            }
            return !payloads.isEmpty
        } isTargeted: { isTargeted = $0 }
    }

    private var tiltIndex: Int {
        abs(folder.id.hashValue)
    }

    private var folderTag: some View {
        Text(verbatim: "FOLDER")
            .font(Tokens.Typography.mono)
            .foregroundStyle(Tokens.Colors.paper)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Tokens.Colors.ink)
    }

    @ViewBuilder
    private var countBadge: some View {
        if count > 0 {
            Text(verbatim: "×\(count)")
                .font(Tokens.Typography.mono)
                .foregroundStyle(Tokens.Colors.ink)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Tokens.Colors.accent)
                .overlay(
                    Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: Tokens.Stroke.hair)
                )
        }
    }
}
