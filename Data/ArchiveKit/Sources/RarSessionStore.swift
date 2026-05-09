import Foundation
import UnrarKit

/// Wraps URKArchive (an Objective-C class without Sendable conformance) so it can be
/// safely transferred into the actor's isolated storage. All access to
/// the underlying URKArchive happens exclusively on the actor's executor.
private final class SendableURKArchive: @unchecked Sendable {
    let archive: URKArchive
    init(_ archive: URKArchive) { self.archive = archive }
}

actor RarSessionStore {
    static let shared = RarSessionStore()
    private var archives: [UUID: SendableURKArchive] = [:]
    private var entryNames: [UUID: [String]] = [:]

    func register(_ archive: URKArchive, entryNames: [String]) -> UUID {
        let id = UUID()
        archives[id] = SendableURKArchive(archive)
        self.entryNames[id] = entryNames
        return id
    }

    func pageCount(for id: UUID) -> Int { entryNames[id]?.count ?? 0 }

    func extractPage(handle id: UUID, index: Int) throws -> Data {
        guard let entries = entryNames[id], let archive = archives[id]?.archive else {
            throw ArchiveStoreError.handleClosed
        }
        guard index >= 0, index < entries.count else {
            throw ArchiveStoreError.indexOutOfBounds(index)
        }
        return try archive.extractData(fromFile: entries[index])
    }

    func close(_ id: UUID) {
        archives.removeValue(forKey: id)
        entryNames.removeValue(forKey: id)
    }
}
