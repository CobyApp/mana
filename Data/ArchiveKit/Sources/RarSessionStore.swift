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

    func archive(for id: UUID) -> URKArchive? { archives[id]?.archive }
    func entries(for id: UUID) -> [String]? { entryNames[id] }

    func close(_ id: UUID) {
        archives.removeValue(forKey: id)
        entryNames.removeValue(forKey: id)
    }
}
