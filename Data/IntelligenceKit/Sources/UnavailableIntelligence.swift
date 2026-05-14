import Foundation
import Domain

public struct UnavailableIntelligence: IntelligenceAvailability {
    public let isAvailable: Bool = false
    public init() {}
}
