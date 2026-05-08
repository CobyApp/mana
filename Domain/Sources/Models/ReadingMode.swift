import Foundation

public enum ReadingMode: Equatable, Sendable, Hashable {
    case single
    case dual
    case scroll(direction: ScrollDirection)
}

public enum ScrollDirection: String, Sendable, Equatable, Hashable, CaseIterable {
    case ltr, rtl, ttb
}
