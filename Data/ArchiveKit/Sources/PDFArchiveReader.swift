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
        await PDFSessionStore.shared.pageCount(for: handle.id)
    }

    public func pageData(_ handle: ArchiveHandle, index: Int) async throws -> Data {
        do {
            return try await PDFSessionStore.shared.pageData(for: handle.id, at: index)
        } catch ArchiveStoreError.handleClosed {
            throw ArchiveError.ioFailure(reason: "handle closed")
        } catch ArchiveStoreError.indexOutOfBounds(let i) {
            throw ArchiveError.indexOutOfBounds(i)
        } catch ArchiveStoreError.encodingFailed {
            throw ArchiveError.ioFailure(reason: "PNG encoding failed")
        }
    }

    public func closeArchive(_ handle: ArchiveHandle) async {
        await PDFSessionStore.shared.close(handle.id)
    }
}
