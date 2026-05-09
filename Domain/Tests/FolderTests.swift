import Testing
import Foundation
@testable import Domain

@Test func folderEquatableByValue() {
    let id = UUID()
    let date = Date(timeIntervalSince1970: 0)
    #expect(Folder(id: id, name: "Manga", dateAdded: date) == Folder(id: id, name: "Manga", dateAdded: date))
}

@Test func pageDirectionRawValues() {
    #expect(PageProgressionDirection.leftToRight.rawValue == "leftToRight")
    #expect(PageProgressionDirection.rightToLeft.rawValue == "rightToLeft")
}

@Test func comicItemPreservesNewFields() {
    let folderId = UUID()
    let item = ComicItem(
        id: UUID(),
        url: URL(fileURLWithPath: "/tmp/x.cbz"),
        format: .cbz,
        title: "X",
        pageCount: 1,
        coverThumbnail: nil,
        dateAdded: .init(timeIntervalSince1970: 0),
        fileSizeBytes: 0,
        readingMode: nil,
        folderId: folderId,
        pageProgressionDirection: .rightToLeft
    )
    #expect(item.folderId == folderId)
    #expect(item.pageProgressionDirection == .rightToLeft)
}
