import SwiftUI
import Domain
import DesignSystem

public struct FolderThumbnail: View {
    let comicsInFolder: [ComicItem]

    public init(comicsInFolder: [ComicItem]) {
        self.comicsInFolder = comicsInFolder
    }

    public var body: some View {
        let covers = comicsInFolder.prefix(4)
        Group {
            switch covers.count {
            case 0:
                placeholder
            case 1:
                cover(covers[covers.startIndex])
            default:
                grid(Array(covers))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.card))
    }

    @ViewBuilder
    private func cover(_ item: ComicItem) -> some View {
        if let data = item.coverThumbnail, let img = UIImage(data: data) {
            Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
        } else {
            placeholder
        }
    }

    @ViewBuilder
    private func grid(_ items: [ComicItem]) -> some View {
        let padded = items + Array(repeating: nil as ComicItem?, count: max(0, 4 - items.count))
        VStack(spacing: 1) {
            HStack(spacing: 1) {
                cell(padded[0])
                cell(padded[1])
            }
            HStack(spacing: 1) {
                cell(padded.count > 2 ? padded[2] : nil)
                cell(padded.count > 3 ? padded[3] : nil)
            }
        }
    }

    @ViewBuilder
    private func cell(_ item: ComicItem?) -> some View {
        if let item, let data = item.coverThumbnail, let img = UIImage(data: data) {
            Image(uiImage: img).resizable().aspectRatio(contentMode: .fill).clipped()
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        Tokens.Colors.backgroundSecondary
    }
}
