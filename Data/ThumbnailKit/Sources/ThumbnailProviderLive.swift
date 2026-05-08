import Foundation
import Domain

public actor ThumbnailProviderLive: ThumbnailProvider {
    private let cacheDir: URL
    private let fm = FileManager.default

    public init(cacheDir: URL) {
        self.cacheDir = cacheDir
        try? fm.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    public func thumbnail(for comicId: UUID, page: Int, maxDim: CGFloat) async throws -> Data {
        let url = fileURL(comicId: comicId, page: page)
        if let cached = try? Data(contentsOf: url) {
            return cached
        }
        throw ThumbnailError.notFound
    }

    /// Stores a downsampled version of `rawPageBytes`; called by importer.
    public func storeThumbnail(comicId: UUID, page: Int, rawPageBytes: Data, maxDim: CGFloat) async throws -> Data {
        guard let downsampled = ImageDownsampler.downsample(rawPageBytes, maxDim: maxDim) else {
            throw ThumbnailError.encodingFailed
        }
        let url = fileURL(comicId: comicId, page: page)
        try downsampled.write(to: url, options: .atomic)
        return downsampled
    }

    public func remove(comicId: UUID) async {
        let prefix = "\(comicId.uuidString)-"
        let items = (try? fm.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil)) ?? []
        for item in items where item.lastPathComponent.hasPrefix(prefix) {
            try? fm.removeItem(at: item)
        }
    }

    private func fileURL(comicId: UUID, page: Int) -> URL {
        cacheDir.appending(path: "\(comicId.uuidString)-\(page).jpg")
    }
}

public enum ThumbnailError: Error, Equatable, Sendable {
    case notFound
    case encodingFailed
}
