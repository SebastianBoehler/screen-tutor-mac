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
}
