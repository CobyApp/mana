import Foundation
import Domain

public struct DefaultArchiveReaderRouter: ArchiveReaderRouter {
    private let zip: ZipArchiveReader

    public init(zip: ZipArchiveReader = ZipArchiveReader()) {
        self.zip = zip
    }

    public func reader(for format: ComicFormat) -> any ArchiveReader {
        switch format {
        case .zip, .cbz:
            return zip
        case .rar, .cbr, .pdf, .folder:
            // Plan 2 adds these; for now, fail loudly so we don't silently route wrong formats.
            preconditionFailure("Format \(format.rawValue) not supported until Plan 2")
        }
    }
}
