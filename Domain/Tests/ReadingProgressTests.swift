import Testing
import Foundation
@testable import Domain

@Test func readingProgressEquatable() {
    let id = UUID()
    let date = Date(timeIntervalSince1970: 1)
    let a = ReadingProgress(comicId: id, lastPageIndex: 5, totalPages: 10, updatedAt: date)
    let b = ReadingProgress(comicId: id, lastPageIndex: 5, totalPages: 10, updatedAt: date)
    #expect(a == b)
}
