import Foundation

public struct PageKey: Hashable, Sendable {
    public let comicId: UUID
    public let pageIndex: Int

    public init(comicId: UUID, pageIndex: Int) {
        self.comicId = comicId
        self.pageIndex = pageIndex
    }

    public var fileName: String {
        "\(comicId.uuidString)-\(pageIndex).bin"
    }
}
