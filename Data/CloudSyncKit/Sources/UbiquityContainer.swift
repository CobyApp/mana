import Foundation

/// Resolves and gates access to the iCloud ubiquity container.
/// `containerURL` is `nil` when iCloud is unavailable (no signed-in account, missing entitlements,
/// or development build without code signing).
public struct UbiquityContainer: Sendable {
    public let identifier: String
    public let containerURL: URL?

    public init(identifier: String) {
        self.identifier = identifier
        self.containerURL = FileManager.default
            .url(forUbiquityContainerIdentifier: identifier)?
            .appending(path: "Documents")
    }

    public var isAvailable: Bool { containerURL != nil }
}
