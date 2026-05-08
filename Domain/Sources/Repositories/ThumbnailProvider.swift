import Foundation

public protocol ThumbnailProvider: Sendable {
    func thumbnail(for comicId: UUID, page: Int, maxDim: CGFloat) async throws -> Data
}
