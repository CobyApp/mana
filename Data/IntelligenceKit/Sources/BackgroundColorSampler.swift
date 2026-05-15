// Data/IntelligenceKit/Sources/BackgroundColorSampler.swift
import Foundation
import CoreGraphics
import UIKit

public struct BackgroundColorSampler: Sendable {
    /// Opaque paper-ish fallback (ARGB 0xFFF6F3EC) used when the bbox cannot
    /// be sampled — keeps the overlay readable instead of going transparent.
    public static let fallbackARGB: UInt32 = 0xFFF6F3EC

    /// Tells whether a sampled background color looks like the inside of a
    /// printed speech bubble: high luminance, low saturation. Used by
    /// `PageTranslatorLive` to drop SFX / signage / artwork text before
    /// invoking the LLM.
    public static func isLikelyBubbleBackground(_ argb: UInt32) -> Bool {
        let r = Double((argb >> 16) & 0xFF) / 255.0
        let g = Double((argb >>  8) & 0xFF) / 255.0
        let b = Double(argb         & 0xFF) / 255.0
        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        let saturation = maxC > 0 ? (maxC - minC) / maxC : 0
        return luminance > 0.82 && saturation < 0.18
    }

    public init() {}

    /// Samples a single representative color from a thin ring just outside the
    /// normalized bbox. Sampling outside the text rather than inside avoids
    /// picking up the ink color.
    public func sample(imageData: Data, normalizedBox: CGRect) -> UInt32 {
        guard
            let image = UIImage(data: imageData),
            let cg = image.cgImage,
            cg.width > 0, cg.height > 0
        else { return Self.fallbackARGB }

        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        // Convert Vision (origin bottom-left) → image-space (origin top-left).
        let imgRect = CGRect(
            x: normalizedBox.minX * w,
            y: (1 - normalizedBox.maxY) * h,
            width: normalizedBox.width * w,
            height: normalizedBox.height * h
        )
        // Sample a 4-pixel ring outside the bbox, clamped to image bounds.
        let inset: CGFloat = -4
        let outer = imgRect.insetBy(dx: inset, dy: inset)
            .intersection(CGRect(x: 0, y: 0, width: w, height: h))
        guard !outer.isNull, outer.width >= 1, outer.height >= 1 else {
            return Self.fallbackARGB
        }

        // Sample four 4×4 corner patches of the outer ring, then average them.
        // This avoids including any text-ink pixels from inside the bbox while
        // still capturing the background color that surrounds the text.
        let patchSize: CGFloat = 4
        let corners: [CGRect] = [
            CGRect(x: outer.minX, y: outer.minY, width: patchSize, height: patchSize),
            CGRect(x: outer.maxX - patchSize, y: outer.minY, width: patchSize, height: patchSize),
            CGRect(x: outer.minX, y: outer.maxY - patchSize, width: patchSize, height: patchSize),
            CGRect(x: outer.maxX - patchSize, y: outer.maxY - patchSize, width: patchSize, height: patchSize),
        ].compactMap { patch -> CGRect? in
            let clamped = patch.intersection(CGRect(x: 0, y: 0, width: w, height: h))
            return (clamped.isNull || clamped.width < 1 || clamped.height < 1) ? nil : clamped
        }
        guard !corners.isEmpty else { return Self.fallbackARGB }

        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return Self.fallbackARGB }
        let info: UInt32 = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        var totalR: Double = 0, totalG: Double = 0, totalB: Double = 0
        for patch in corners {
            var pixel: [UInt8] = [0, 0, 0, 0]
            guard let ctx = CGContext(
                data: &pixel,
                width: 1, height: 1, bitsPerComponent: 8,
                bytesPerRow: 4, space: space, bitmapInfo: info
            ) else { continue }
            ctx.interpolationQuality = .medium
            if let cropped = cg.cropping(to: patch) {
                ctx.draw(cropped, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            }
            totalR += Double(pixel[0])
            totalG += Double(pixel[1])
            totalB += Double(pixel[2])
        }
        let n = Double(corners.count)
        let r = UInt32(totalR / n), g = UInt32(totalG / n), b = UInt32(totalB / n)
        // Force alpha to 0xFF — overlay must be opaque.
        return (0xFF << 24) | (r << 16) | (g << 8) | b
    }
}
