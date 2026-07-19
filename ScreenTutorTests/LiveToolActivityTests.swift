import XCTest
@testable import ScreenTutor

@MainActor
final class LiveToolActivityTests: XCTestCase {
    func testCaptureToolAppearsInOverlayAndPlaysPrivacyCue() {
        let model = AppModel()
        var cueCount = 0
        model.playScreenInspectionCue = { cueCount += 1 }

        model.beginToolActivity(name: "capture_window", turn: 3)
        model.recordToolActivity(name: "capture_window", status: .succeeded, turn: 3)

        XCTAssertEqual(cueCount, 1)
        XCTAssertEqual(
            model.liveToolActivities,
            [
                LiveToolActivity(
                    name: "capture_window",
                    status: .succeeded,
                    turn: 3
                )
            ]
        )
        XCTAssertEqual(model.liveToolActivities.first?.displayName, "Capturing window")
    }

    func testWindowListingAlsoPlaysCueButHighlightDoesNot() {
        let model = AppModel()
        var cueCount = 0
        model.playScreenInspectionCue = { cueCount += 1 }

        model.beginToolActivity(name: "list_windows", turn: 1)
        model.beginToolActivity(name: "highlight_screen_region", turn: 1)

        XCTAssertEqual(cueCount, 1)
        XCTAssertEqual(model.liveToolActivities.count, 2)
    }
}
