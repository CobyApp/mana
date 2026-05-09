import SwiftUI
import CoreTransferable
import Domain
import DesignSystem

public struct FolderCard: View {
    let folder: Folder
    let comicsInFolder: [ComicItem]
    var onTap: () -> Void
    var onRename: () -> Void
    var onDelete: () -> Void
    var onDropComic: (UUID) -> Void

    @State private var isTargeted = false

    public init(
        folder: Folder,
        comicsInFolder: [ComicItem],
        onTap: @escaping () -> Void,
        onRename: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onDropComic: @escaping (UUID) -> Void
    ) {
        self.folder = folder
        self.comicsInFolder = comicsInFolder
        self.onTap = onTap
        self.onRename = onRename
        self.onDelete = onDelete
        self.onDropComic = onDropComic
    }

    public var body: some View {
        Button(action: onTap) {
            VStack(spacing: Tokens.Spacing.s) {
                MangaPanel(
                    surface: .paper,
                    tiltIndex: tiltIndex,
                    cornerRadius: Tokens.Radius.panel,
                    strokeWidth: Tokens.Stroke.panel
                ) {
                    ZStack {
                        FolderThumbnail(comicsInFolder: comicsInFolder)
                        VStack {
                            HStack {
                                folderTag
                                Spacer()
                                countBadge
                            }
                            .padding(8)
                            Spacer()
                        }
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
        }
        .buttonStyle(.plain)
        .dropDestination(for: ComicDragPayload.self) { payloads, _ in
            for payload in payloads {
                for comicId in payload.comicIds {
                    onDropComic(comicId)
                }
            }
            return !payloads.isEmpty
        } isTargeted: { isTargeted = $0 }
        .contextMenu {
            Button(action: onRename) {
                Label {
                    Text("library.rename_folder", bundle: .module)
                } icon: {
                    Image(systemName: "pencil")
                }
            }
            Button(role: .destructive, action: onDelete) {
                Label {
                    Text("library.delete", bundle: .module)
                } icon: {
                    Image(systemName: "trash")
                }
            }
        }
    }

    private var tiltIndex: Int {
        abs(folder.id.hashValue)
    }

    private var folderTag: some View {
        Text("FOLDER")
            .font(Tokens.Typography.mono)
            .foregroundStyle(Tokens.Colors.paper)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Tokens.Colors.ink)
    }

    @ViewBuilder
    private var countBadge: some View {
        if !comicsInFolder.isEmpty {
            Text("×\(comicsInFolder.count)")
                .font(Tokens.Typography.mono)
                .foregroundStyle(Tokens.Colors.ink)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Tokens.Colors.accent)
                .overlay(
                    Rectangle().strokeBorder(Tokens.Colors.ink, lineWidth: 1.5)
                )
        }
    }
}
