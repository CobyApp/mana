import Foundation

public enum ReadingMode: Equatable, Sendable, Hashable, CaseIterable {
    case single
    case dual
    /// Continuous vertical scroll (webtoon): pages stack top-to-bottom and scroll as one strip.
    case webtoon

    public static let allCases: [ReadingMode] = [.single, .dual, .webtoon]
}

public extension ReadingMode {
    var rawString: String {
        switch self {
        case .single:  return "single"
        case .dual:    return "dual"
        case .webtoon: return "webtoon"
        }
    }

    init?(rawString: String) {
        switch rawString {
        case "single":  self = .single
        case "dual":    self = .dual
        case "webtoon": self = .webtoon
        // Legacy fall-through: any old "scroll-*" raw value loaded from disk becomes .webtoon
        case let s where s.hasPrefix("scroll-"): self = .webtoon
        default: return nil
        }
    }
}
