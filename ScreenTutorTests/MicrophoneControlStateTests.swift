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
        XCTAssertEqual(muted, .muted)
        XCTAssertEqual(muted.tone, .muted)
        XCTAssertEqual(muted.label, "Unmute ScreenTutor microphone")
    }

    func testInterruptedConversationOffersReconnectInsteadOfNewSession() {
        let state = MicrophoneControlState(
            phase: .idle,
            isMuted: true,
            canReconnect: true
        )

        XCTAssertEqual(state, .reconnect)
        XCTAssertEqual(state.label, "Reconnect microphone")
        XCTAssertTrue(state.isEnabled)
    }
}
