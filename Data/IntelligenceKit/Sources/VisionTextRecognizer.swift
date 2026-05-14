import Foundation
import Vision
import UIKit
import Domain

public struct VisionTextRecognizer: Sendable {
    public init() {}

    public func recognize(imageData: Data) async throws -> [TextLineBox] {
        guard let uiImage = UIImage(data: imageData), let cg = uiImage.cgImage else {
            return []
        }
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { req, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = (req.results as? [VNRecognizedTextObservation]) ?? []
                let lines: [TextLineBox] = observations.compactMap { obs in
                    guard let candidate = obs.topCandidates(1).first else { return nil }
                    return TextLineBox(
                        id: UUID(),
                        text: candidate.string,
                        boundingBox: obs.boundingBox,  // Vision normalized, bottom-left origin
                        confidence: candidate.confidence
                    )
                }
                continuation.resume(returning: lines)
            }
            request.recognitionLanguages = ["ja", "ko", "en"]
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do { try handler.perform([request]) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }
}
