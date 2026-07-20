import XCTest
@testable import ScreenTutor

final class MicrophoneControlStateTests: XCTestCase {
    func testActiveMicrophoneUsesDistinctLiveAndMutedPresentations() {
        let live = MicrophoneControlState(
            phase: .listening,
            isMuted: false,
            canReconnect: false
        )
        let muted = MicrophoneControlState(
            phase: .speaking,
            isMuted: true,
            canReconnect: false
        )

        XCTAssertEqual(live, .live)
        XCTAssertEqual(live.tone, .live)
        XCTAssertEqual(live.label, "Mute ScreenTutor microphone")
        XCTAssertEqual(live.compactLabel, "Mute")
        XCTAssertEqual(muted, .muted)
        XCTAssertEqual(muted.tone, .muted)
        XCTAssertEqual(muted.label, "Unmute ScreenTutor microphone")
        XCTAssertEqual(muted.compactLabel, "Unmute")
    }

    func testInterruptedConversationOffersReconnectInsteadOfNewSession() {
        let state = MicrophoneControlState(
            phase: .idle,
            isMuted: true,
            canReconnect: true
        )

        XCTAssertEqual(state, .reconnect)
        XCTAssertEqual(state.tone, .reconnecting)
        XCTAssertEqual(state.label, "Reconnect microphone")
        XCTAssertEqual(state.compactLabel, "Reconnect")
        XCTAssertTrue(state.isEnabled)
    }
}
