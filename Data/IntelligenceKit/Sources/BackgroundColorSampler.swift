// Data/IntelligenceKit/Sources/BackgroundColorSampler.swift
import Foundation
import CoreGraphics
import UIKit

public struct BackgroundColorSampler: Sendable {
    /// Opaque paper-ish fallback (ARGB 0xFFF6F3EC) used when the bbox cannot
    /// be sampled — keeps the overlay readable instead of going transparent.
    public static let fallbackARGB: UInt32 = 0xFFF6F3EC

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

        // Downscale the ring to a single 1x1 pixel — fastest reliable average.
        let bytesPerRow = 4
        var pixel: [UInt8] = [0, 0, 0, 0]
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return Self.fallbackARGB }
        let info: UInt32 = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        guard let ctx = CGContext(
            data: &pixel,
            width: 1, height: 1, bitsPerComponent: 8,
            bytesPerRow: bytesPerRow, space: space, bitmapInfo: info
        ) else { return Self.fallbackARGB }
        ctx.interpolationQuality = .medium
        // Draw the cropped region into the 1x1 context.
        if let cropped = cg.cropping(to: outer) {
            ctx.draw(cropped, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        let r = UInt32(pixel[0]), g = UInt32(pixel[1]), b = UInt32(pixel[2])
        // Force alpha to 0xFF — overlay must be opaque.
        return (0xFF << 24) | (r << 16) | (g << 8) | b
    }
}
