import Foundation
import UnrarKit
import Domain

public struct RarArchiveReader: ArchiveReader {
    public init() {}

    private static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "gif", "webp", "bmp", "heic"]

    public func openArchive(at url: URL) async throws -> ArchiveHandle {
        do {
            let archive = try URKArchive(url: url)
            if archive.isPasswordProtected() {
                throw ArchiveError.encrypted
            }
            let allNames: [String] = try archive.listFilenames()
            let imageNames = allNames
                .filter {
                    let ext = ($0 as NSString).pathExtension.lowercased()
                    return Self.imageExtensions.contains(ext)
                }
                .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            let id = await RarSessionStore.shared.register(archive, entryNames: imageNames)
            return ArchiveHandle(id: id)
        } catch let archiveError as ArchiveError {
            throw archiveError
        } catch let error as NSError {
            throw map(error)
        }
    }

    public func pageCount(_ handle: ArchiveHandle) async -> Int {
        await RarSessionStore.shared.entries(for: handle.id)?.count ?? 0
    }

    public func pageData(_ handle: ArchiveHandle, index: Int) async throws -> Data {
        guard let entries = await RarSessionStore.shared.entries(for: handle.id),
              let archive = await RarSessionStore.shared.archive(for: handle.id)
        else {
            throw ArchiveError.ioFailure(reason: "handle closed")
        }
        guard index >= 0, index < entries.count else {
            throw ArchiveError.indexOutOfBounds(index)
        }
        do {
            let data = try archive.extractData(fromFile: entries[index])
            return data
        } catch let archiveError as ArchiveError {
            throw archiveError
        } catch let error as NSError {
            throw map(error)
        }
    }

    public func closeArchive(_ handle: ArchiveHandle) async {
        await RarSessionStore.shared.close(handle.id)
    }

    private func map(_ error: NSError) -> ArchiveError {
        let code = error.code
        switch URKErrorCode(rawValue: code) {
        case .missingPassword:
            return .encrypted
        case .badData, .badArchive, .unknownFormat:
            return .corrupted
        default:
            return .ioFailure(reason: error.localizedDescription)
        }
    }
}
