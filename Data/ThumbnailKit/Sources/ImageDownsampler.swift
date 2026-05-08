import Foundation
import UIKit
import ImageIO

public enum ImageDownsampler {
    /// Downsample image bytes to a thumbnail with longest side <= maxDim,
    /// re-encoded as JPEG at quality 0.8. Returns nil if the input is not decodable.
    public static func downsample(_ data: Data, maxDim: CGFloat) -> Data? {
        let cfData = data as CFData
        guard let source = CGImageSourceCreateWithData(cfData, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDim
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        let uiImage = UIImage(cgImage: cgImage)
        return uiImage.jpegData(compressionQuality: 0.8)
    }
}
