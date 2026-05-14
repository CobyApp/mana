// Data/IntelligenceKit/Sources/IntelligenceAvailabilityLive.swift
import Foundation
import Domain
#if canImport(FoundationModels)
import FoundationModels
#endif

@available(iOS 26.0, *)
public struct IntelligenceAvailabilityLive: IntelligenceAvailability {
    public init() {}

    public var isAvailable: Bool {
        switch SystemLanguageModel.default.availability {
        case .available:
            return true
        case .unavailable:
            return false
        }
    }
}
