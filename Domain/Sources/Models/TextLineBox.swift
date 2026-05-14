import Foundation
import CoreGraphics

public struct TextLineBox: Equatable, Sendable, Hashable, Codable, Identifiable {
    public let id: UUID
    public let text: String
    /// Vision-normalized rect. Origin is bottom-left, all values in 0...1.
    public let boundingBox: CGRect
    public let confidence: Float

    public init(id: UUID, text: String, boundingBox: CGRect, confidence: Float) {
        self.id = id
        self.text = text
        self.boundingBox = boundingBox
        self.confidence = confidence
    }
}
