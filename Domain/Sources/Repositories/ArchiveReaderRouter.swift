import Foundation

public protocol ArchiveReaderRouter: Sendable {
    func reader(for format: ComicFormat) -> any ArchiveReader
}
