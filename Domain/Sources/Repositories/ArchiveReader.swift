import Foundation

/// Opaque session token for an opened archive. The real per-archive state
/// (file descriptor, decoded entry list, etc.) lives inside the ArchiveReader
/// implementation, keyed by `id`. Treat this as a value type — equality is
/// identity equality.
public struct ArchiveHandle: Equatable, Sendable, Hashable, Identifiable {
    public let id: UUID
    public init(id: UUID = UUID()) { self.id = id }
}

public protocol ArchiveReader: Sendable {
    func openArchive(at url: URL) async throws -> ArchiveHandle
    func pageCount(_ handle: ArchiveHandle) async -> Int
    func pageData(_ handle: ArchiveHandle, index: Int) async throws -> Data
    func closeArchive(_ handle: ArchiveHandle) async
}

public enum ArchiveError: Error, Equatable, Sendable {
    case unsupportedFormat(String)
    case corrupted
    case encrypted
    case ioFailure(reason: String)
    case indexOutOfBounds(Int)
}
