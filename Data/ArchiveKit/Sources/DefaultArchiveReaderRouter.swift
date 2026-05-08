import Foundation
import Domain

public struct DefaultArchiveReaderRouter: ArchiveReaderRouter {
    private let zip: ZipArchiveReader
    private let rar: RarArchiveReader
    private let pdf: PDFArchiveReader

    public init(
        zip: ZipArchiveReader = ZipArchiveReader(),
        rar: RarArchiveReader = RarArchiveReader(),
        pdf: PDFArchiveReader = PDFArchiveReader()
    ) {
        self.zip = zip
        self.rar = rar
        self.pdf = pdf
    }

    public func reader(for format: ComicFormat) -> any ArchiveReader {
        switch format {
        case .zip, .cbz: return zip
        case .rar, .cbr: return rar
        case .pdf: return pdf
        case .folder:
            preconditionFailure("Folder format not supported")
        }
    }
}
