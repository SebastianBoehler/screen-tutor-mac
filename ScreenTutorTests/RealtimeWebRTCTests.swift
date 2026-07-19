import Foundation
import XCTest
@testable import ScreenTutor

@MainActor
final class RealtimeWebRTCTests: XCTestCase {
    func testCallRequestKeepsAPIKeyNativeAndBootstrapsSelectedModel() throws {
        let request = try RealtimeCallRequest(
            apiKey: "sk-test-secret",
            offerSDP: "v=0\r\no=screen-tutor",
            model: .economy,
            boundary: "screen-tutor-boundary"
        ).urlRequest

        XCTAssertEqual(request.url?.absoluteString, "https://api.openai.com/v1/realtime/calls")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer sk-test-secret")
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Content-Type"),
            "multipart/form-data; boundary=screen-tutor-boundary"
        )

        let body = try XCTUnwrap(request.httpBody.flatMap { String(data: $0, encoding: .utf8) })
        XCTAssertTrue(body.contains("name=\"sdp\""))
        XCTAssertTrue(body.contains("v=0\r\no=screen-tutor"))
        XCTAssertTrue(body.contains("name=\"session\""))
        XCTAssertTrue(body.contains("\"model\":\"gpt-realtime-2.1-mini\""))
        XCTAssertFalse(body.contains("sk-test-secret"))
    }

    func testNativeMediaEnablesFullDuplexAudioProcessing() {
        let constraints = RealtimeWebRTCAudioConstraints.optional

        XCTAssertEqual(constraints["googEchoCancellation"], "true")
        XCTAssertEqual(constraints["googNoiseSuppression"], "true")
        XCTAssertEqual(constraints["googAutoGainControl"], "true")
        XCTAssertEqual(constraints["googHighpassFilter"], "true")
    }

    func testClientMuteControlsMediaTrackWithoutDisconnecting() async throws {
        let transport = RecordingRealtimeTransport()
        let client = RealtimeClient(makeTransport: { transport })
        let connectionID = RealtimeConnectionID()

        try await client.connect(
            connectionID: connectionID,
            apiKey: "sk-test",
            model: .flagship,
            onEvent: { _ in },
            onDisconnect: { _ in }
        )
        try await client.setMicrophoneMuted(true, connectionID: connectionID)
        try await client.setMicrophoneMuted(false, connectionID: connectionID)

        XCTAssertEqual(transport.muteChanges, [true, false])
        XCTAssertEqual(transport.disconnectCount, 0)
    }
}

@MainActor
private final class RecordingRealtimeTransport: RealtimeTransporting {
    var muteChanges: [Bool] = []
    var disconnectCount = 0

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

    func disconnect() {
        disconnectCount += 1
    }
}
