import Foundation
import CoreTransferable
import UniformTypeIdentifiers

public struct ComicDragPayload: Codable, Transferable, Sendable {
    public let comicId: UUID

    public init(comicId: UUID) {
        self.comicId = comicId
    }

    public static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .manaComicDragPayload)
    }
}

public extension UTType {
    static let manaComicDragPayload = UTType(exportedAs: "com.coby.mana.comic-drag-payload")
}
