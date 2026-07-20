import CoreGraphics
import ImageIO
import XCTest
@testable import ScreenTutor

final class ScreenImageEncoderTests: XCTestCase {
    func testNoisyScreenshotFitsRealtimeDataChannelBudget() throws {
        let image = try makeNoiseImage(width: 1_600, height: 1_000)

        let jpeg = try XCTUnwrap(ScreenImageEncoder().jpegData(from: image))
        let event = ConversationImageEvent(
            jpegData: jpeg,
            applicationName: "Xcode",
            windowTitle: "ScreenTutor",
            previousItemID: "item_voice_turn"
        )
        let eventData = try JSONEncoder().encode(event)

        XCTAssertLessThanOrEqual(jpeg.count, ScreenImageEncoder.maximumJPEGBytes)
        XCTAssertLessThanOrEqual(eventData.count, RealtimeEventSizePolicy.maximumTextBytes)
        XCTAssertEqual(jpeg.prefix(2), Data([0xFF, 0xD8]))
    }

    private func makeNoiseImage(width: Int, height: Int) throws -> CGImage {
        var pixels = Data(count: width * height * 4)
        pixels.withUnsafeMutableBytes { rawBuffer in
            guard let bytes = rawBuffer.bindMemory(to: UInt8.self).baseAddress else { return }
            var state: UInt32 = 0xA341_316C
            for index in 0..<(width * height) {
                state = 1_664_525 &* state &+ 1_013_904_223
                bytes[index * 4] = UInt8(truncatingIfNeeded: state)
                bytes[index * 4 + 1] = UInt8(truncatingIfNeeded: state >> 8)
                bytes[index * 4 + 2] = UInt8(truncatingIfNeeded: state >> 16)
                bytes[index * 4 + 3] = 255
            }
        }
        let provider = try XCTUnwrap(CGDataProvider(data: pixels as CFData))
        return try XCTUnwrap(
            CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(
                    rawValue: CGImageAlphaInfo.last.rawValue
                ),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        )
    }
}
