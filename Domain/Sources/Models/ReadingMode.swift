import Foundation

public enum ReadingMode: Equatable, Sendable, Hashable, CaseIterable {
    case single
    case dual

    public static let allCases: [ReadingMode] = [.single, .dual]
}

public extension ReadingMode {
    var rawString: String {
        switch self {
        case .single: return "single"
        case .dual:   return "dual"
        }
    }

    init?(rawString: String) {
        switch rawString {
        case "single": self = .single
        case "dual":   self = .dual
        // Legacy fall-through: any old "scroll-*" raw value loaded from disk just becomes .single
        case let s where s.hasPrefix("scroll-"): self = .single
        default: return nil
        }
    }
}
