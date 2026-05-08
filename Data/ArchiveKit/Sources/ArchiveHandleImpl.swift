import Foundation
import ZIPFoundation
import Domain

/// Wraps Archive (a class without Sendable conformance) so it can be
/// safely transferred into the actor's isolated storage. All access to
/// the underlying Archive happens exclusively on the actor's executor.
private final class SendableArchive: @unchecked Sendable {
    let archive: Archive
    init(_ archive: Archive) { self.archive = archive }
}

actor ZipArchiveSessionStore {
    static let shared = ZipArchiveSessionStore()
    private var archives: [UUID: SendableArchive] = [:]
    private var entryLists: [UUID: [Entry]] = [:]

    func register(_ archive: Archive, sortedImageEntries: [Entry]) -> UUID {
        let id = UUID()
        archives[id] = SendableArchive(archive)
        entryLists[id] = sortedImageEntries
        return id
    }

    func archive(for id: UUID) -> Archive? { archives[id]?.archive }
    func entries(for id: UUID) -> [Entry]? { entryLists[id] }

    func extractPage(handle id: UUID, index: Int) throws -> Data {
        guard let entries = entryLists[id],
              let archive = archives[id]?.archive
        else {
            throw ArchiveError.ioFailure(reason: "handle closed")
        }
        guard index >= 0, index < entries.count else {
            throw ArchiveError.indexOutOfBounds(index)
        }
        var buffer = Data()
        do {
            _ = try archive.extract(entries[index]) { chunk in
                buffer.append(chunk)
            }
            return buffer
        } catch let error as Archive.ArchiveError {
            throw mapZipError(error)
        } catch {
            throw ArchiveError.ioFailure(reason: error.localizedDescription)
        }
    }

    func close(_ id: UUID) {
        archives.removeValue(forKey: id)
        entryLists.removeValue(forKey: id)
    }
}

private func mapZipError(_ error: Archive.ArchiveError) -> ArchiveError {
    switch error {
    case .invalidEntryPath,
         .missingEndOfCentralDirectoryRecord,
         .invalidCRC32,
         .invalidEntrySize,
         .invalidLocalHeaderDataOffset,
         .invalidLocalHeaderSize,
         .invalidCentralDirectoryOffset,
         .invalidCentralDirectorySize,
         .invalidCentralDirectoryEntryCount:
        return .corrupted
    default:
        return .ioFailure(reason: String(describing: error))
    }
}
