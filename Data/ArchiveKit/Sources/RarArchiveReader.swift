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
        await RarSessionStore.shared.pageCount(for: handle.id)
    }

    public func pageData(_ handle: ArchiveHandle, index: Int) async throws -> Data {
        do {
            return try await RarSessionStore.shared.extractPage(handle: handle.id, index: index)
        } catch ArchiveStoreError.handleClosed {
            throw ArchiveError.ioFailure(reason: "handle closed")
        } catch ArchiveStoreError.indexOutOfBounds(let i) {
            throw ArchiveError.indexOutOfBounds(i)
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
