import CoreGraphics
import XCTest
@testable import ScreenTutor

final class TeachingPointerTests: XCTestCase {
    func testMapsNormalizedTopLeftPointIntoAppKitWindowFrame() throws {
        let pointer = try TeachingPointer(
            argumentsJSON: #"{"x":0.25,"y":0.4,"label":"loss curve"}"#,
            windowFrame: CGRect(x: 100, y: 200, width: 1_000, height: 500)
        )

        XCTAssertEqual(pointer.label, "loss curve")
        XCTAssertEqual(pointer.globalPoint.x, 350, accuracy: 0.001)
        XCTAssertEqual(pointer.globalPoint.y, 500, accuracy: 0.001)
    }

    func testRejectsPointOutsideScreenshot() {
        XCTAssertThrowsError(
            try TeachingPointer(
                argumentsJSON: #"{"x":1.1,"y":0.2,"label":"outside"}"#,
                windowFrame: CGRect(x: 0, y: 0, width: 100, height: 100)
            )
        )
    }
}
