import Foundation
import UIKit
import PDFKit
import Domain

public struct PDFArchiveReader: ArchiveReader {
    public init() {}

    public func openArchive(at url: URL) async throws -> ArchiveHandle {
        guard let doc = PDFDocument(url: url) else {
            throw ArchiveError.corrupted
        }
        if doc.isLocked {
            throw ArchiveError.encrypted
        }
        let id = await PDFSessionStore.shared.register(doc)
        return ArchiveHandle(id: id)
    }

    public func pageCount(_ handle: ArchiveHandle) async -> Int {
        await PDFSessionStore.shared.document(for: handle.id)?.pageCount ?? 0
    }

    public func pageData(_ handle: ArchiveHandle, index: Int) async throws -> Data {
        guard let doc = await PDFSessionStore.shared.document(for: handle.id) else {
            throw ArchiveError.ioFailure(reason: "handle closed")
        }
        guard index >= 0, index < doc.pageCount, let page = doc.page(at: index) else {
            throw ArchiveError.indexOutOfBounds(index)
        }
        let bounds = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2.0
        let renderSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)

        let renderer = UIGraphicsImageRenderer(size: renderSize)
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: renderSize))
            ctx.cgContext.translateBy(x: 0, y: renderSize.height)
            ctx.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
        guard let pngData = image.pngData() else {
            throw ArchiveError.ioFailure(reason: "PNG encoding failed")
        }
        return pngData
    }

    public func closeArchive(_ handle: ArchiveHandle) async {
        await PDFSessionStore.shared.close(handle.id)
    }
}
