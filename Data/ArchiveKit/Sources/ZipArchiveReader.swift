import Foundation
import ZIPFoundation
import Domain

public struct ZipArchiveReader: ArchiveReader {
    public init() {}

    private static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "gif", "webp", "bmp", "heic"]

    public func openArchive(at url: URL) async throws -> ArchiveHandle {
        do {
            let archive = try Archive(url: url, accessMode: .read)
            let imageEntries = archive
                .filter { entry in
                    let ext = (entry.path as NSString).pathExtension.lowercased()
                    return entry.type == .file && Self.imageExtensions.contains(ext)
                }
                .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
            let id = await ZipArchiveSessionStore.shared.register(archive, sortedImageEntries: imageEntries)
            return ArchiveHandle(id: id)
        } catch let error as Archive.ArchiveError {
            throw mapArchiveError(error)
        } catch {
            throw ArchiveError.ioFailure(reason: error.localizedDescription)
        }
    }

    public func pageCount(_ handle: ArchiveHandle) async -> Int {
        await ZipArchiveSessionStore.shared.entries(for: handle.id)?.count ?? 0
    }

    public func pageData(_ handle: ArchiveHandle, index: Int) async throws -> Data {
        try await ZipArchiveSessionStore.shared.extractPage(handle: handle.id, index: index)
    }

    public func closeArchive(_ handle: ArchiveHandle) async {
        await ZipArchiveSessionStore.shared.close(handle.id)
    }
}

private func mapArchiveError(_ error: Archive.ArchiveError) -> ArchiveError {
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
    case .unreadableArchive:
        return .ioFailure(reason: String(describing: error))
    default:
        return .ioFailure(reason: String(describing: error))
    }
}
