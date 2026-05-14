// Data/IntelligenceKit/Tests/BackgroundColorSamplerTests.swift
import Testing
import Foundation
import CoreGraphics
import UIKit
@testable import IntelligenceKit

@MainActor
@Suite struct BackgroundColorSamplerTests {

    /// Makes an opaque 100x100 PNG of a single solid color.
    private func solidImageData(red: CGFloat, green: CGFloat, blue: CGFloat) -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
        let img = renderer.image { ctx in
            UIColor(red: red, green: green, blue: blue, alpha: 1.0).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
        return img.pngData()!
    }

    @Test func samplesSolidWhite() {
        let data = solidImageData(red: 1, green: 1, blue: 1)
        let sampler = BackgroundColorSampler()
        let bbox = CGRect(x: 0.3, y: 0.3, width: 0.2, height: 0.2)
        let argb = sampler.sample(imageData: data, normalizedBox: bbox)
        // alpha=FF, r≈FF, g≈FF, b≈FF — allow ±4 per channel for sRGB rounding.
        #expect((argb >> 24) & 0xFF == 0xFF)
        #expect(((argb >> 16) & 0xFF) > 0xF8)
        #expect(((argb >>  8) & 0xFF) > 0xF8)
        #expect((argb        & 0xFF) > 0xF8)
    }

    @Test func samplesSolidRed() {
        let data = solidImageData(red: 1, green: 0, blue: 0)
        let sampler = BackgroundColorSampler()
        let argb = sampler.sample(imageData: data, normalizedBox: CGRect(x: 0.1, y: 0.1, width: 0.1, height: 0.1))
        let r = (argb >> 16) & 0xFF
        let g = (argb >>  8) & 0xFF
        let b = argb         & 0xFF
        #expect(r > 0xF0)
        #expect(g < 0x10)
        #expect(b < 0x10)
    }

    @Test func emptyImageFallsBackToPaperColor() {
        let sampler = BackgroundColorSampler()
        let argb = sampler.sample(imageData: Data(), normalizedBox: .zero)
        // Fallback is opaque off-white.
        #expect((argb >> 24) & 0xFF == 0xFF)
    }
}
