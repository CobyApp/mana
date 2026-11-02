import SwiftUI
import Domain
import DesignSystem

/// Single folder cover (Android `FolderThumbnail`): the folder's custom cover, else the most
/// recently added comic's cover (resolved by `LibraryFeature.State.coverData(for:)`), else a
/// dense halftone placeholder.
public struct FolderThumbnail: View {
    let cover: Data?

    public init(cover: Data?) {
        self.cover = cover
    }

    public var body: some View {
        if let cover, let img = UIImage(data: cover) {
            Color.clear
                .overlay {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
                .clipped()
        } else {
            ZStack {
                Tokens.Colors.paper
                HalftoneBackground(spacing: Tokens.Halftone.denseDotSpacing,
                                   radius: Tokens.Halftone.denseDotRadius)
            }
        }
    }
}
