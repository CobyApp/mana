import Testing
import Foundation
@testable import Domain

@Test func comicItemEquatableByValue() {
    let id = UUID()
    let url = URL(fileURLWithPath: "/tmp/x.cbz")
    let a = ComicItem(id: id, url: url, format: .cbz, title: "X", pageCount: 12, coverThumbnail: nil, dateAdded: Date(timeIntervalSince1970: 0), fileSizeBytes: 100)
    let b = ComicItem(id: id, url: url, format: .cbz, title: "X", pageCount: 12, coverThumbnail: nil, dateAdded: Date(timeIntervalSince1970: 0), fileSizeBytes: 100)
    #expect(a == b)
}

@Test func comicFormatRawValueIsLowercaseExtension() {
    #expect(ComicFormat.cbz.rawValue == "cbz")
    #expect(ComicFormat.pdf.rawValue == "pdf")
}
