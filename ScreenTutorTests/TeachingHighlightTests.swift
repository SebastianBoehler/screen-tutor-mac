import CoreGraphics
import XCTest
@testable import ScreenTutor

final class TeachingHighlightTests: XCTestCase {
    func testMapsNormalizedTopLeftCoordinatesIntoAppKitWindowFrame() throws {
        let highlight = try TeachingHighlight(
            argumentsJSON: """
            {"x":0.1,"y":0.2,"width":0.3,"height":0.4,"label":"loss curve"}
            """,
            windowFrame: CGRect(x: 100, y: 200, width: 1_000, height: 500)
        )

        XCTAssertEqual(highlight.label, "loss curve")
        XCTAssertEqual(highlight.globalFrame.origin.x, 200, accuracy: 0.001)
        XCTAssertEqual(highlight.globalFrame.origin.y, 400, accuracy: 0.001)
        XCTAssertEqual(highlight.globalFrame.width, 300, accuracy: 0.001)
        XCTAssertEqual(highlight.globalFrame.height, 200, accuracy: 0.001)
    }

    func testRejectsRegionOutsideScreenshot() {
        XCTAssertThrowsError(
            try TeachingHighlight(
                argumentsJSON: """
                {"x":0.9,"y":0.2,"width":0.3,"height":0.4,"label":"outside"}
                """,
                windowFrame: CGRect(x: 0, y: 0, width: 100, height: 100)
            )
        )
    }
}
