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
                ZStack {
                    FolderThumbnail(comicsInFolder: comicsInFolder)
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "folder.fill")
                                .font(.caption)
                                .foregroundStyle(.white)
                                .padding(6)
                                .background(.black.opacity(0.5), in: .circle)
                                .padding(8)
                        }
                        Spacer()
                    }
                }
                .aspectRatio(0.7, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.card))
                .overlay(
                    RoundedRectangle(cornerRadius: Tokens.Radius.card)
                        .stroke(isTargeted ? Tokens.Colors.accent : .clear, lineWidth: 3)
                )
                .shadow(color: .black.opacity(0.18), radius: 5, x: 0, y: 3)

                Text(folder.name)
                    .font(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.primary)
            }
            .padding(.bottom, Tokens.Spacing.xs)
        }
        .buttonStyle(.plain)
        .dropDestination(for: ComicDragPayload.self) { payloads, _ in
            for payload in payloads {
                onDropComic(payload.comicId)
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
}
