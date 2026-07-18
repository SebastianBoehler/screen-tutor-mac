import CoreGraphics
import XCTest
@testable import ScreenTutor

final class AmbientTranscriptPresentationTests: XCTestCase {
    func testExpandsOnlyForEnabledTranscriptDuringAConversation() {
        XCTAssertTrue(
            AmbientTranscriptPresentation(
                isEnabled: true,
                phase: .speaking,
                userText: "Where is the result?",
                assistantText: "It is on the right."
            ).isExpanded
        )
        XCTAssertFalse(
            AmbientTranscriptPresentation(
                isEnabled: false,
                phase: .speaking,
                userText: "Where is the result?",
                assistantText: "It is on the right."
            ).isExpanded
        )
        XCTAssertFalse(
            AmbientTranscriptPresentation(
                isEnabled: true,
                phase: .idle,
                userText: "Where is the result?",
                assistantText: "It is on the right."
            ).isExpanded
        )
        XCTAssertFalse(
            AmbientTranscriptPresentation(
                isEnabled: true,
                phase: .listening,
                userText: "",
                assistantText: ""
            ).isExpanded
        )
    }

    func testScreenAnchorStaysFixedUntilExplicitRetarget() {
        var policy = HUDScreenAnchorPolicy<String>()

        XCTAssertEqual(policy.resolve(isVisible: true, candidate: "left"), "left")
        XCTAssertEqual(policy.resolve(isVisible: true, candidate: "right"), "left")

        policy.retarget(to: "right")

        XCTAssertEqual(policy.resolve(isVisible: true, candidate: "left"), "right")
    }

    func testScreenAnchorClearsWhenPresentationHides() {
        var policy = HUDScreenAnchorPolicy<String>()
        XCTAssertEqual(policy.resolve(isVisible: true, candidate: "left"), "left")

        XCTAssertNil(policy.resolve(isVisible: false, candidate: "right"))

        XCTAssertEqual(policy.resolve(isVisible: true, candidate: "right"), "right")
    }

    func testDraggedPlacementKeepsItsCenterWhenTranscriptExpands() {
        var policy = HUDPanelPlacementPolicy()
        policy.recordUserFrame(CGRect(x: 100, y: 100, width: 420, height: 76))

        let origin = policy.origin(
            for: CGSize(width: 420, height: 204),
            automaticOrigin: .zero,
            visibleFrame: CGRect(x: 0, y: 0, width: 1_440, height: 900)
        )

        XCTAssertEqual(origin, CGPoint(x: 100, y: 36))
    }

    func testDraggedPlacementStaysInsideTheVisibleScreen() {
        var policy = HUDPanelPlacementPolicy()
        policy.recordUserFrame(CGRect(x: 1_300, y: 850, width: 420, height: 76))

        let origin = policy.origin(
            for: CGSize(width: 420, height: 204),
            automaticOrigin: .zero,
            visibleFrame: CGRect(x: 0, y: 0, width: 1_440, height: 900)
        )

        XCTAssertEqual(origin, CGPoint(x: 1_012, y: 688))
    }
}
