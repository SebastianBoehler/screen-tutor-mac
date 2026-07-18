import CoreGraphics
import XCTest
@testable import ScreenTutor

final class CapturedWindowContextTests: XCTestCase {
    func testRevalidationUsesTheCurrentOriginWhenSizeIsUnchanged() throws {
        let context = CapturedWindowContext(
            windowID: 42,
            processID: 7,
            capturedFrame: CGRect(x: 100, y: 200, width: 800, height: 600)
        )

        let frame = try context.revalidatedFrame(
            currentFrame: CGRect(x: 350, y: 410, width: 800, height: 600)
        )

        XCTAssertEqual(frame, CGRect(x: 350, y: 410, width: 800, height: 600))
    }

    func testRevalidationRejectsAResizedWindow() {
        let context = CapturedWindowContext(
            windowID: 42,
            processID: 7,
            capturedFrame: CGRect(x: 100, y: 200, width: 800, height: 600)
        )

        XCTAssertThrowsError(
            try context.revalidatedFrame(
                currentFrame: CGRect(x: 100, y: 200, width: 810, height: 600)
            )
        ) { error in
            XCTAssertEqual(error as? ScreenCaptureError, .windowGeometryChanged)
        }
    }
}
