import Foundation

public enum ComicFormat: String, Sendable, Equatable, CaseIterable {
    case zip, cbz, rar, cbr, pdf, folder

    public init?(fileExtension: String) {
        self.init(rawValue: fileExtension.lowercased())
    }
}
