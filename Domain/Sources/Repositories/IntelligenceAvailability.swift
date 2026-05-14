import Foundation

public protocol IntelligenceAvailability: Sendable {
    /// True only when the on-device system language model is loaded and ready.
    var isAvailable: Bool { get }
}
