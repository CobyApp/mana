import Foundation

/// How the library lays out comics/folders: cover grid or compact list.
public enum LibraryViewMode: String, Sendable, Equatable, Hashable, CaseIterable {
    case grid
    case list

    public init(rawStringOrDefault raw: String) {
        self = LibraryViewMode(rawValue: raw) ?? .grid
    }
}
