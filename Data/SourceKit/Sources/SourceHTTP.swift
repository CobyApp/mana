import Foundation

/// Thin URLSession wrapper for source scraping. Carries a desktop User-Agent so cached/bot-gated
/// endpoints return real content, and exposes GET-as-text and GET-as-bytes. Ported from Android
/// `SourceHttp`.
public struct SourceHTTP: Sendable {
    public static let userAgent =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
        "(KHTML, like Gecko) Chrome/124.0 Safari/537.36"

    public enum HTTPError: Error, Sendable { case status(Int, String), empty }

    private let session: URLSession

    public init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 30
            config.timeoutIntervalForResource = 45
            config.requestCachePolicy = .reloadIgnoringLocalCacheData
            // Downloads run several chapters × pages at once against the same image host.
            config.httpMaximumConnectionsPerHost = 16
            config.urlCache = nil
            self.session = URLSession(configuration: config)
        }
    }

    public func get(_ urlString: String, headers: [String: String] = [:]) async throws -> String {
        let (data, code, url) = try await raw(urlString, headers: headers)
        guard (200..<300).contains(code) else { throw HTTPError.status(code, url) }
        guard let text = String(data: data, encoding: .utf8) else { throw HTTPError.empty }
        return text
    }

    public func getBytes(_ urlString: String, headers: [String: String] = [:]) async throws -> Data {
        let (data, code, url) = try await raw(urlString, headers: headers)
        guard (200..<300).contains(code) else { throw HTTPError.status(code, url) }
        guard !data.isEmpty else { throw HTTPError.empty }
        return data
    }

    private func raw(_ urlString: String, headers: [String: String]) async throws -> (Data, Int, String) {
        guard let url = URL(string: urlString) else { throw HTTPError.status(-1, urlString) }
        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        for (k, v) in headers { request.setValue(v, forHTTPHeaderField: k) }
        let (data, response) = try await session.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        return (data, code, urlString)
    }
}
