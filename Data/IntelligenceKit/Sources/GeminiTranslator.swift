import Foundation
import os

/// High-quality translation via Google Gemini (needs an API key). A whole page's text blocks are
/// sent together as a JSON array so the model has panel context, and it returns the same-length
/// array of Korean translations. Watermarks/site links become blank. Ported from the Android
/// `GeminiTextTranslator`.
public struct GeminiTranslator: Sendable {
    private static let watermark = "RTMTH"
    private static let maxAttempts = 3
    private static let retryBackoffMillis: UInt64 = 1200
    private static let log = Logger(subsystem: "com.coby.mana", category: "gemini")

    private let session: URLSession

    public init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 60
            config.timeoutIntervalForResource = 90
            self.session = URLSession(configuration: config)
        }
    }

    public enum GeminiError: Error, Sendable { case http(String), parse }

    /// Translate `texts` (one page's blocks). Returns a same-size list; throws on API/parse error.
    public func translate(_ texts: [String], targetLanguage: String, apiKey: String, model: String) async throws -> [String] {
        guard !texts.isEmpty else { return [] }

        let body: [String: Any] = [
            "systemInstruction": ["parts": [["text": Self.systemPrompt(target: targetLanguage)]]],
            "contents": [[
                "role": "user",
                "parts": [["text": jsonArrayString(texts)]]
            ]],
            "generationConfig": [
                "temperature": 0.3,
                "responseMimeType": "application/json"
            ]
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        // The Generative Language API authenticates the key via the ?key= query param.
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else { throw GeminiError.http("bad url") }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        var raw: Data?
        var lastErr = ""
        var attempt = 0
        while attempt < Self.maxAttempts {
            do {
                let (data, response) = try await session.data(for: request)
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                if (200..<300).contains(code) {
                    raw = data
                    break
                }
                lastErr = "HTTP \(code): \(String(data: data, encoding: .utf8)?.prefix(200) ?? "")"
                // Only transient statuses are worth retrying.
                if code != 503 && code != 429 && code < 500 { break }
            } catch {
                lastErr = error.localizedDescription
            }
            attempt += 1
            if attempt < Self.maxAttempts {
                try? await Task.sleep(nanoseconds: Self.retryBackoffMillis * UInt64(attempt) * 1_000_000)
            }
        }
        guard let raw else {
            Self.log.error("Gemini failed: \(lastErr, privacy: .public)")
            throw GeminiError.http(lastErr)
        }

        // candidates[0].content.parts[0].text holds the JSON array string.
        guard
            let root = try? JSONSerialization.jsonObject(with: raw) as? [String: Any],
            let candidates = root["candidates"] as? [[String: Any]],
            let content = candidates.first?["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]],
            let partText = parts.first?["text"] as? String,
            let arrData = partText.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8),
            let arr = try? JSONSerialization.jsonObject(with: arrData) as? [Any]
        else {
            throw GeminiError.parse
        }

        return (0..<texts.count).map { i in
            let v = (i < arr.count ? arr[i] as? String : nil) ?? ""
            return v.contains(Self.watermark) ? "" : v
        }
    }

    private func jsonArrayString(_ texts: [String]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: texts),
              let s = String(data: data, encoding: .utf8) else { return "[]" }
        return s
    }

    private static func systemPrompt(target: String) -> String {
        let lang = languageName(target)
        return """
        You translate text from scanned Japanese manga into natural, fluent \(lang).
        Input is a JSON array of strings (one per speech bubble / text block), in reading order.
        Rules:
        - Output ONLY a JSON array of strings, the SAME length and order as the input.
        - Translate each string to natural \(lang), adapting idioms.
        - Keep sound effects/onomatopoeia natural in \(lang).
        - Replace any watermark or site link (e.g. a URL / site name) with "\(watermark)".
        - Do not add, merge, split, or reorder items. Return exactly as many items as given.
        """
    }

    private static func languageName(_ code: String) -> String {
        switch code {
        case "ko": return "Korean"
        case "ja": return "Japanese"
        case "en": return "English"
        default:   return "Korean"
        }
    }
}
