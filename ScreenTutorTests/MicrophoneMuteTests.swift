import XCTest
@testable import ScreenTutor

@MainActor
final class MicrophoneMuteTests: XCTestCase {
    func testAssistantPlaybackKeepsTutorMicrophoneLiveForBargeIn() {
        let model = AppModel()
        model.realtimeConnectionID = RealtimeConnectionID()
        model.phase = .speaking
        model.isMicrophoneMuted = false

        XCTAssertFalse(model.isMicrophoneMuted)
        XCTAssertEqual(model.microphoneControlState, .live)
        XCTAssertEqual(model.statusDetail, "Screen-aware Realtime voice")
    }

    func testMuteKeepsConnectionResponseAndSpeakingPhaseAlive() async {
        let transport = MicrophoneRecordingTransport()
        let client = RealtimeClient(makeTransport: { transport })
        let model = AppModel(realtimeClient: client)
        let connectionID = RealtimeConnectionID()
        try? await client.connect(
            connectionID: connectionID,
            apiKey: "sk-test",
            model: .flagship,
            onEvent: { _ in },
            onDisconnect: { _ in }
        )
        model.realtimeConnectionID = connectionID
        model.phase = .speaking
        model.activeResponseID = "response_in_progress"
        model.activeResponseTurn = model.turnTracker.current

        await model.setMicrophoneMuted(true)

        XCTAssertTrue(model.isMicrophoneMuted)
        XCTAssertEqual(model.phase, .speaking)
        XCTAssertEqual(model.realtimeConnectionID, connectionID)
        XCTAssertEqual(model.activeResponseID, "response_in_progress")
        XCTAssertEqual(model.statusTitle, "Microphone muted")
        XCTAssertEqual(model.statusSymbolName, "mic.slash.fill")
        XCTAssertEqual(transport.muteChanges, [true])
    }

    func testUnmuteRestoresInputWithoutReplacingConversationState() async {
        let transport = MicrophoneRecordingTransport()
        let client = RealtimeClient(makeTransport: { transport })
        let model = AppModel(realtimeClient: client)
        let connectionID = RealtimeConnectionID()
        try? await client.connect(
            connectionID: connectionID,
            apiKey: "sk-test",
            model: .flagship,
            onEvent: { _ in },
            onDisconnect: { _ in }
        )
        model.realtimeConnectionID = connectionID
        model.phase = .thinking
        model.isMicrophoneMuted = true

        await model.setMicrophoneMuted(false)

        XCTAssertFalse(model.isMicrophoneMuted)
        XCTAssertEqual(model.phase, .thinking)
        XCTAssertEqual(model.realtimeConnectionID, connectionID)
        XCTAssertEqual(transport.muteChanges, [false])
    }
}

@MainActor
private final class MicrophoneRecordingTransport: RealtimeTransporting {
    var muteChanges: [Bool] = []

    func connect(
        apiKey: String,
        model: RealtimeModel,
        onMessage: @escaping (String) async -> Void,
        onDisconnect: @escaping (String) async -> Void
    ) async throws {}

    func send(_ text: String) async throws {}

    func setMicrophoneMuted(_ muted: Bool) async throws {
        muteChanges.append(muted)
    }

    func disconnect() {}
}
