import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ScreenImageEncoder {
    static let maximumJPEGBytes = 180_000

    private let qualities: [CGFloat] = [0.82, 0.68, 0.54, 0.40, 0.28]
    private let longestSides = [1_920, 1_600, 1_400, 1_200, 1_000, 800]

    func jpegData(from source: CGImage) -> Data? {
        for longestSide in longestSides {
            guard let image = resized(source, maximumDimension: longestSide) else { return nil }
            for quality in qualities {
                guard let data = encode(image, quality: quality) else { return nil }
                if data.count <= Self.maximumJPEGBytes { return data }
            }
        }
        return nil
    }

    private func resized(_ source: CGImage, maximumDimension: Int) -> CGImage? {
        let longestSide = max(source.width, source.height)
        guard longestSide > maximumDimension else { return source }
        let scale = CGFloat(maximumDimension) / CGFloat(longestSide)
        let width = max(1, Int((CGFloat(source.width) * scale).rounded()))
        let height = max(1, Int((CGFloat(source.height) * scale).rounded()))
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .high
        context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    private func encode(_ image: CGImage, quality: CGFloat) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else { return nil }
        let properties = [
            kCGImageDestinationLossyCompressionQuality: quality
        ] as CFDictionary
        CGImageDestinationAddImage(destination, image, properties)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
