import SwiftUI
import UIKit
import ImageIO

/// Loads a remote source image that requires custom headers (Referer / desktop User-Agent to pass
/// the site's hotlink/bot gating). Decoded images are kept in a small in-memory cache so scrolling
/// a grid doesn't refetch. Mirrors Android's `SourceImage`.
public struct SourceImage: View {
    let url: String?
    let headers: [String: String]
    var contentMode: ContentMode = .fill
    var maxPixel: CGFloat?

    /// `maxPixel` downsamples the decoded image (use for thumbnails/covers).
    public init(url: String?, headers: [String: String], contentMode: ContentMode = .fill, maxPixel: CGFloat? = 480) {
        self.url = url
        self.headers = headers
        self.contentMode = contentMode
        self.maxPixel = maxPixel
    }

    @State private var image: UIImage?
    @State private var failed = false

    public var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.18))
                    .overlay {
                        if failed {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        } else {
                            ProgressView()
                        }
                    }
            }
        }
        .clipped()
        .task(id: url) { await load() }
    }

    private func load() async {
        failed = false
        guard let url, let decoded = await RemoteImageLoader.shared.load(url, headers: headers, maxPixel: maxPixel) else {
            failed = true
            return
        }
        image = decoded
    }
}

/// Shared headered image fetcher with an in-memory decoded-image cache (bounded by bytes), an
/// on-disk HTTP cache so covers survive relaunches, and in-flight de-duplication so a grid cell and
/// a prefetch asking for the same URL share one request. Images are decoded off the main thread;
/// `maxPixel` downsamples (covers) so grids don't hold full-resolution bitmaps.
actor RemoteImageLoader {
    static let shared = RemoteImageLoader()

    private let cache = NSCache<NSString, UIImage>()
    private let session: URLSession
    private var inFlight: [String: Task<UIImage?, Never>] = [:]

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.httpMaximumConnectionsPerHost = 8
        config.urlCache = URLCache(
            memoryCapacity: 16 * 1024 * 1024,
            diskCapacity: 300 * 1024 * 1024,
            directory: URL.cachesDirectory.appending(path: "mana-source-images")
        )
        session = URLSession(configuration: config)
        cache.totalCostLimit = 192 * 1024 * 1024
    }

    func load(_ urlString: String, headers: [String: String], maxPixel: CGFloat? = nil) async -> UIImage? {
        let key = (maxPixel.map { "\(urlString)#\(Int($0))" } ?? urlString)
        if let cached = cache.object(forKey: key as NSString) { return cached }
        if let running = inFlight[key] { return await running.value }
        let session = self.session
        let task = Task<UIImage?, Never> {
            guard let url = URL(string: urlString) else { return nil }
            var request = URLRequest(url: url)
            for (k, v) in headers { request.setValue(v, forHTTPHeaderField: k) }
            guard let (data, response) = try? await session.data(for: request),
                  let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
            return await Task.detached(priority: .userInitiated) { Self.decode(data, maxPixel: maxPixel) }.value
        }
        inFlight[key] = task
        let image = await task.value
        inFlight[key] = nil
        if let image {
            let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
            cache.setObject(image, forKey: key as NSString, cost: cost)
        }
        return image
    }

    /// Warms the cache for upcoming pages; results are dropped (they land in the caches).
    nonisolated func prefetch(_ urls: [String], headers: [String: String]) {
        for url in urls {
            Task(priority: .utility) { _ = await self.load(url, headers: headers) }
        }
    }

    private static func decode(_ data: Data, maxPixel: CGFloat?) -> UIImage? {
        if let maxPixel {
            let options = [kCGImageSourceShouldCache: false] as CFDictionary
            guard let source = CGImageSourceCreateWithData(data as CFData, options) else { return nil }
            let thumbOptions = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixel
            ] as CFDictionary
            guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions) else { return nil }
            return UIImage(cgImage: cg)
        }
        // Force decode now so the first draw on the main thread doesn't stall scrolling.
        return UIImage(data: data)?.preparingForDisplay()
    }
}
