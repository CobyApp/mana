// Data/IntelligenceKit/Sources/IntelligenceAvailabilityLive.swift
import Foundation
import Domain

public struct IntelligenceAvailabilityLive: IntelligenceAvailability {
    public init() {}

    public var isAvailable: Bool {
        if #available(iOS 18.0, *) {
            return true
        }
        return false
    }
}
