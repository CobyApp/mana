import Foundation

/// Lazy resolver for the iCloud ubiquity container.
/// `containerURL` is recomputed each time it's read because iOS may take a moment to register
/// the container after first launch — caching the first result (often nil) leaves sync stuck off.
public struct UbiquityContainer: Sendable {
    public let identifier: String

    public init(identifier: String) {
        self.identifier = identifier
    }

    public var containerURL: URL? {
        FileManager.default
            .url(forUbiquityContainerIdentifier: identifier)?
            .appending(path: "Documents")
    }

    public var isAvailable: Bool { containerURL != nil }
}
