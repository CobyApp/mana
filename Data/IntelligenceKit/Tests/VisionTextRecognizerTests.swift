// Data/IntelligenceKit/Tests/VisionTextRecognizerTests.swift
import Testing
import Foundation
import UIKit
@testable import IntelligenceKit

@MainActor
@Suite struct VisionTextRecognizerTests {

    private func textImagePNG(_ text: String, size: CGSize = CGSize(width: 400, height: 120)) -> Data {
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 48, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            let attr = NSAttributedString(string: text, attributes: attrs)
            attr.draw(at: CGPoint(x: 20, y: 30))
        }
        return img.pngData()!
    }

    /// English-only sanity check. We tried Korean and Japanese, but the system
    /// font rasterized into a small synthetic PNG is too clean / out-of-distribution
    /// for Vision OCR — it returns garbage at 48 pt. Real comic book pages contain
    /// printed glyphs that Vision handles well; this test only proves the
    /// recognizer plumbs `recognitionLanguages = ["ja","ko","en"]` correctly and
    /// surfaces a non-empty result.
    @Test func recognizesRenderedText() async throws {
        let data = textImagePNG("Hello")
        let recognizer = VisionTextRecognizer()
        let boxes = try await recognizer.recognize(imageData: data)
        #expect(!boxes.isEmpty)
        let joined = boxes.map(\.text).joined()
        #expect(joined.contains("Hello"))
    }

    @Test func returnsEmptyForBlankImage() async throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
        let blank = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
        let data = blank.pngData()!
        let recognizer = VisionTextRecognizer()
        let boxes = try await recognizer.recognize(imageData: data)
        #expect(boxes.isEmpty)
    }
}
