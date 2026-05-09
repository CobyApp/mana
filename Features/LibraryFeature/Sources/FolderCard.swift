import SwiftUI
import CoreTransferable
import Domain
import DesignSystem

public struct FolderCard: View {
    let folder: Folder
    let comicsInFolder: [ComicItem]
    var onTap: () -> Void
    var onDelete: () -> Void
    var onDropComic: (UUID) -> Void

    @State private var isTargeted = false

    public init(
        folder: Folder,
        comicsInFolder: [ComicItem],
        onTap: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onDropComic: @escaping (UUID) -> Void
    ) {
        self.folder = folder
        self.comicsInFolder = comicsInFolder
        self.onTap = onTap
        self.onDelete = onDelete
        self.onDropComic = onDropComic
    }

    public var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
                FolderThumbnail(comicsInFolder: comicsInFolder)
                    .frame(width: 96, height: 96)
                    .overlay(
                        RoundedRectangle(cornerRadius: Tokens.Radius.card)
                            .stroke(isTargeted ? Tokens.Colors.accent : .clear, lineWidth: 3)
                    )
                Text(folder.name)
                    .font(.caption)
                    .lineLimit(1)
                Text("\(comicsInFolder.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 96)
        }
        .buttonStyle(.plain)
        .dropDestination(for: ComicDragPayload.self) { payloads, _ in
            for payload in payloads {
                onDropComic(payload.comicId)
            }
            return !payloads.isEmpty
        } isTargeted: { isTargeted = $0 }
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label {
                    Text("library.delete", bundle: .module)
                } icon: {
                    Image(systemName: "trash")
                }
            }
        }
    }
}
