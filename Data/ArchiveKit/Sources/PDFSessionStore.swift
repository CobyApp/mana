import Foundation
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

    func document(for id: UUID) -> PDFDocument? { documents[id]?.document }

    func close(_ id: UUID) {
        documents.removeValue(forKey: id)
    }
}
