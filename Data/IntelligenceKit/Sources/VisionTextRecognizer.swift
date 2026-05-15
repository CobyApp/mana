import Foundation
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit
import Domain

public struct VisionTextRecognizer: Sendable {
    public init() {}

    public func recognize(imageData: Data) async throws -> [TextLineBox] {
        guard let uiImage = UIImage(data: imageData), let cg = uiImage.cgImage else {
            return []
        }
        // Pre-process the page to give Vision a fighting chance against
        // hand-lettered manga Japanese: strip color so halftone bleed-through
        // doesn't confuse character segmentation, and lift contrast so faint
        // strokes don't fall under the recognizer's confidence floor.
        let processed = Self.preprocess(cg) ?? cg
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { req, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = (req.results as? [VNRecognizedTextObservation]) ?? []
                let lines: [TextLineBox] = observations.compactMap { obs in
                    guard let candidate = obs.topCandidates(1).first else { return nil }
                    let bb = obs.boundingBox
                    let isVertical = bb.height > bb.width * 1.5  // taller than 1.5x wider → likely vertical
                    return TextLineBox(
                        id: UUID(),
                        text: candidate.string,
                        boundingBox: bb,  // Vision normalized, bottom-left origin
                        confidence: candidate.confidence,
                        isVertical: isVertical
                    )
                }
                continuation.resume(returning: lines)
            }
            request.recognitionLanguages = ["ja", "ko", "en"]
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: processed, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do { try handler.perform([request]) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }

    /// Desaturates and boosts contrast. Returns nil if Core Image can't render
    /// (extreme image sizes, etc.) — caller falls back to the unprocessed image.
    private static func preprocess(_ cg: CGImage) -> CGImage? {
        let input = CIImage(cgImage: cg)
        let filtered = input.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0.0,   // grayscale — keeps halftone dots from acting as colored noise
            kCIInputContrastKey: 1.35,    // mild lift — too much crushes thin Japanese strokes
            kCIInputBrightnessKey: 0.0
        ])
        let ctx = CIContext(options: [.useSoftwareRenderer: false])
        return ctx.createCGImage(filtered, from: filtered.extent)
    }
}
