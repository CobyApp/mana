import Foundation
import UIKit
import PDFKit

/// Wraps PDFDocument (a class without Sendable conformance) so it can be
/// safely transferred into the actor's isolated storage. All access to
/// the underlying PDFDocument happens exclusively on the actor's executor.
private final class SendablePDFDocument: @unchecked Sendable {
    let document: PDFDocument
    init(_ document: PDFDocument) { self.document = document }
}

actor PDFSessionStore {
    static let shared = PDFSessionStore()
    private var documents: [UUID: SendablePDFDocument] = [:]

    func register(_ doc: PDFDocument) -> UUID {
        let id = UUID()
        documents[id] = SendablePDFDocument(doc)
        return id
    }

    func pageCount(for id: UUID) -> Int {
        documents[id]?.document.pageCount ?? 0
    }

    func pageData(for id: UUID, at index: Int) throws -> Data {
        guard let doc = documents[id]?.document else {
            throw ArchiveStoreError.handleClosed
        }
        guard index >= 0, index < doc.pageCount, let page = doc.page(at: index) else {
            throw ArchiveStoreError.indexOutOfBounds(index)
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
            throw ArchiveStoreError.encodingFailed
        }
        return pngData
    }

    func close(_ id: UUID) {
        documents.removeValue(forKey: id)
    }
}

enum ArchiveStoreError: Error {
    case handleClosed
    case indexOutOfBounds(Int)
    case encodingFailed
}
