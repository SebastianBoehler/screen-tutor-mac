import XCTest
@testable import ScreenTutor

final class SessionPhaseTests: XCTestCase {
    func testPrimaryActionsMatchConversationState() {
        assertPrimaryAction(.idle, label: "Start conversation", symbol: "mic.fill")
        assertPrimaryAction(.paused, label: "Unmute microphone", symbol: "mic.fill")

        for phase in [SessionPhase.listening, .thinking, .speaking] {
            assertPrimaryAction(phase, label: "Mute microphone", symbol: "mic.slash.fill")
        }
    }

    func testConversationStatusTitlesAreExplicit() {
        XCTAssertEqual(SessionPhase.listening.title, "Listening")
        XCTAssertEqual(SessionPhase.thinking.title, "Thinking")
        XCTAssertEqual(SessionPhase.speaking.title, "Speaking")
        XCTAssertEqual(SessionPhase.paused.title, "Microphone muted")
    }

    func testTransitionPhasesDisablePrimaryAction() {
        for phase in [
            SessionPhase.requestingPermissions,
            .connecting,
            .pausing,
            .resuming,
            .stopping,
        ] {
            XCTAssertFalse(phase.isPrimaryActionEnabled)
        }
    }

    func testOnlyEstablishedConversationPhasesHaveConversation() {
        for phase in [SessionPhase.listening, .thinking, .speaking, .paused] {
            XCTAssertTrue(phase.hasConversation)
        }
        for phase in [
            SessionPhase.idle,
            .requestingPermissions,
            .connecting,
            .pausing,
            .resuming,
            .stopping,
        ] {
            XCTAssertFalse(phase.hasConversation)
        }
    }

    func testEveryNonIdlePhaseNeedsTeardown() {
        XCTAssertFalse(SessionPhase.idle.needsTeardown)
        for phase in [
            SessionPhase.requestingPermissions,
            .connecting,
            .listening,
            .thinking,
            .speaking,
            .pausing,
            .paused,
            .resuming,
            .stopping,
        ] {
            XCTAssertTrue(phase.needsTeardown)
        }
    }

    func testOverlayStopActionIsAvailableUntilStoppingBegins() {
        XCTAssertFalse(SessionPhase.idle.isStopActionEnabled)
        XCTAssertFalse(SessionPhase.stopping.isStopActionEnabled)
        for phase in [
            SessionPhase.requestingPermissions,
            .connecting,
            .listening,
            .thinking,
            .speaking,
            .pausing,
            .paused,
            .resuming,
        ] {
            XCTAssertTrue(phase.isStopActionEnabled)
        }
    }

    private func assertPrimaryAction(
        _ phase: SessionPhase,
        label: String,
        symbol: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(phase.primaryActionLabel, label, file: file, line: line)
        XCTAssertEqual(phase.primaryActionSymbolName, symbol, file: file, line: line)
        XCTAssertTrue(phase.isPrimaryActionEnabled, file: file, line: line)
    }
}
