import Foundation

public enum ReadingMode: Equatable, Sendable, Hashable {
    case single
    case dual
    case scroll(direction: ScrollDirection)
}

public enum ScrollDirection: String, Sendable, Equatable, Hashable, CaseIterable {
    case ltr, rtl, ttb
}

extension ReadingMode {
    public var rawString: String {
        switch self {
        case .single: return "single"
        case .dual: return "dual"
        case .scroll(let dir): return "scroll-\(dir.rawValue)"
        }
    }

    public init?(rawString: String) {
        switch rawString {
        case "single": self = .single
        case "dual": self = .dual
        case "scroll-ltr": self = .scroll(direction: .ltr)
        case "scroll-rtl": self = .scroll(direction: .rtl)
        case "scroll-ttb": self = .scroll(direction: .ttb)
        default: return nil
        }
    }
}
