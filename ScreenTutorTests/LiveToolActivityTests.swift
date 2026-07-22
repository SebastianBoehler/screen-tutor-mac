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

    func testVisualCaptureToolsPlayCueButPointerDoesNot() {
        let model = AppModel()
        var cueCount = 0
        model.playScreenInspectionCue = { cueCount += 1 }

        model.beginToolActivity(name: "list_windows", turn: 1)
        model.beginToolActivity(name: "capture_camera", turn: 1)
        model.beginToolActivity(name: "point_at_screen_position", turn: 1)

        XCTAssertEqual(cueCount, 2)
        XCTAssertEqual(model.liveToolActivities.count, 3)
        XCTAssertEqual(model.liveToolActivities[1].displayName, "Taking camera photo")
    }
}
