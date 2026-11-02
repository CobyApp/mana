import SwiftUI
import UIKit

/// Loads a remote source image that requires custom headers (Referer / desktop User-Agent to pass
/// the site's hotlink/bot gating). Decoded images are kept in a small in-memory cache so scrolling
/// a grid doesn't refetch. Mirrors Android's `SourceImage`.
public struct SourceImage: View {
    let url: String?
    let headers: [String: String]
    var contentMode: ContentMode = .fill

    public init(url: String?, headers: [String: String], contentMode: ContentMode = .fill) {
        self.url = url
        self.headers = headers
        self.contentMode = contentMode
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
        image = nil
        failed = false
        guard let url, let decoded = await RemoteImageLoader.shared.load(url, headers: headers) else {
            failed = true
            return
        }
        image = decoded
    }
}

/// Shared headered image fetcher + in-memory decoded-image cache.
actor RemoteImageLoader {
    static let shared = RemoteImageLoader()

    private let cache = NSCache<NSString, UIImage>()
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.requestCachePolicy = .returnCacheDataElseLoad
        session = URLSession(configuration: config)
        cache.countLimit = 150
    }

    func load(_ urlString: String, headers: [String: String]) async -> UIImage? {
        let key = urlString as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        for (k, v) in headers { request.setValue(v, forHTTPHeaderField: k) }
        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}
