import XCTest
@testable import ScreenTutor

@MainActor
final class MicrophoneMuteTests: XCTestCase {
    func testAssistantPlaybackSuspendsTutorUploadWithoutMutingTheSession() {
        let model = AppModel()
        model.realtimeConnectionID = RealtimeConnectionID()
        model.phase = .speaking
        model.isMicrophoneMuted = false

        XCTAssertFalse(model.shouldUploadMicrophoneAudio)
        XCTAssertFalse(model.isMicrophoneMuted)
        XCTAssertEqual(model.microphoneControlState, .live)
        XCTAssertEqual(
            model.statusDetail,
            "Microphone upload paused until this reply finishes"
        )
    }

    func testMuteKeepsConnectionResponseAndSpeakingPhaseAlive() async {
        let model = AppModel()
        let connectionID = RealtimeConnectionID()
        model.realtimeConnectionID = connectionID
        model.phase = .speaking
        model.activeResponseID = "response_in_progress"
        model.activeResponseTurn = model.turnTracker.current

        await model.setMicrophoneMuted(true)

        XCTAssertTrue(model.isMicrophoneMuted)
        XCTAssertFalse(model.shouldUploadMicrophoneAudio)
        XCTAssertEqual(model.phase, .speaking)
        XCTAssertEqual(model.realtimeConnectionID, connectionID)
        XCTAssertEqual(model.activeResponseID, "response_in_progress")
        XCTAssertEqual(model.statusTitle, "Microphone muted")
        XCTAssertEqual(model.statusSymbolName, "mic.slash.fill")
    }

    func testUnmuteRestoresInputWithoutReplacingConversationState() async {
        let model = AppModel()
        let connectionID = RealtimeConnectionID()
        model.realtimeConnectionID = connectionID
        model.phase = .thinking
        model.isMicrophoneMuted = true

        await model.setMicrophoneMuted(false)

        XCTAssertFalse(model.isMicrophoneMuted)
        XCTAssertTrue(model.shouldUploadMicrophoneAudio)
        XCTAssertEqual(model.phase, .thinking)
        XCTAssertEqual(model.realtimeConnectionID, connectionID)
    }
}
