import SwiftUI
import Domain
import DesignSystem

public struct FolderCard: View {
    let folder: Folder
    let comicsInFolder: [ComicItem]
    var onTap: () -> Void
    var onDelete: () -> Void

    public init(
        folder: Folder,
        comicsInFolder: [ComicItem],
        onTap: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.folder = folder
        self.comicsInFolder = comicsInFolder
        self.onTap = onTap
        self.onDelete = onDelete
    }

    public var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
                FolderThumbnail(comicsInFolder: comicsInFolder)
                    .frame(width: 96, height: 96)
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
