import Foundation
import ZIPFoundation
import Domain

public struct ZipArchiveReader: ArchiveReader {
    public init() {}

    private static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "gif", "webp", "bmp", "heic"]

    /// Reject macOS sidecar entries that masquerade as images:
    /// - everything under `__MACOSX/` (a resource-fork shadow tree the Finder
    ///   bundles into zips it creates)
    /// - AppleDouble files whose name starts with `._` — these aren't real
    ///   images, decoding them gives a black frame and inflates the page count
    static func isReadableImagePath(_ path: String) -> Bool {
        let components = path.split(separator: "/", omittingEmptySubsequences: true)
        if components.first == "__MACOSX" { return false }
        if let name = components.last, name.hasPrefix("._") { return false }
        return true
    }

    public func openArchive(at url: URL) async throws -> ArchiveHandle {
        do {
            let archive = try Archive(url: url, accessMode: .read)
            let imageEntries = archive
                .filter { entry in
                    guard entry.type == .file else { return false }
                    let ext = (entry.path as NSString).pathExtension.lowercased()
                    guard Self.imageExtensions.contains(ext) else { return false }
                    return Self.isReadableImagePath(entry.path)
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
        await ZipArchiveSessionStore.shared.pageCount(for: handle.id)
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
