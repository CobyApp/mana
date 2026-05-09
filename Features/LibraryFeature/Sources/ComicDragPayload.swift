import Foundation
import CoreTransferable
import UniformTypeIdentifiers

public struct ComicDragPayload: Codable, Transferable, Sendable {
    public let comicIds: [UUID]

    public init(comicIds: [UUID]) {
        self.comicIds = comicIds
    }

    public init(comicId: UUID) {
        self.comicIds = [comicId]
    }

    public static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .manaComicDragPayload)
    }
}

public extension UTType {
    static let manaComicDragPayload = UTType(exportedAs: "com.coby.mana.comic-drag-payload")
}
