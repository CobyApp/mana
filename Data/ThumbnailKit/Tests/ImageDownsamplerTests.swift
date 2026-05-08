import Testing
import Foundation
import UIKit
@testable import ThumbnailKit

@Suite struct ImageDownsamplerTests {

    @Test func downsamplesLargeImageToMaxDim() throws {
        let large = makeRedImage(width: 2000, height: 3000)
        let pngData = try #require(large.pngData())

        let resultData = try #require(ImageDownsampler.downsample(pngData, maxDim: 256))
        let resultImage = try #require(UIImage(data: resultData))

        #expect(resultImage.size.width <= 256)
        #expect(resultImage.size.height <= 256)
        #expect(resultData.count < pngData.count)
    }

    @Test func smallerImageIsReturnedAsIs() throws {
        let small = makeRedImage(width: 100, height: 100)
        let jpegData = try #require(small.jpegData(compressionQuality: 0.8))

        let resultData = try #require(ImageDownsampler.downsample(jpegData, maxDim: 256))
        let resultImage = try #require(UIImage(data: resultData))

        #expect(resultImage.size.width <= 256)
        #expect(resultImage.size.height <= 256)
    }

    private func makeRedImage(width: Int, height: Int) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }
}
