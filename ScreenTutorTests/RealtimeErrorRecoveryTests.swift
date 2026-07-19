import XCTest
@testable import ScreenTutor

@MainActor
final class RealtimeErrorRecoveryTests: XCTestCase {
    func testCorrelatedResponseCreateErrorReturnsCurrentTurnToListening() async {
        let model = AppModel()
        let turn = model.turnTracker.advance()
        model.phase = .thinking
        model.pendingResponseCreates["evt_create"] = turn

        await model.handleRealtimeError(
            RealtimeAPIError(
                type: "invalid_request_error",
                code: "invalid_event",
                message: "The response could not be created.",
                param: nil,
                eventID: "evt_create"
            )
        )

        XCTAssertEqual(model.phase, .listening)
        XCTAssertEqual(model.errorMessage, "The response could not be created.")
        XCTAssertTrue(model.pendingResponseCreates.isEmpty)
    }

    func testCorrelatedSafeCancelErrorIsIgnored() async {
        let model = AppModel()
        model.pendingResponseCancels["resp_done"] = "evt_cancel"

        await model.handleRealtimeError(
            RealtimeAPIError(
                type: "invalid_request_error",
                code: "response_cancel_not_active",
                message: "There is no active response to cancel.",
                param: nil,
                eventID: "evt_cancel"
            )
        )

        XCTAssertNil(model.errorMessage)
        XCTAssertTrue(model.pendingResponseCancels.isEmpty)
    }

    func testCompletedResponseKeepsCorrelationForLateSafeCancelError() async throws {
        let model = AppModel()
        let connectionID = RealtimeConnectionID()
        let turn = model.turnTracker.advance()
        model.realtimeConnectionID = connectionID
        model.phase = .thinking
        model.activeResponseID = "resp_done"
        model.activeResponseTurn = turn
        model.pendingResponseCancels["resp_done"] = "evt_cancel"

        try await model.handleResponseDone(
            RealtimeResponse(
                id: "resp_done",
                status: "completed",
                metadata: ["screen_tutor_turn": String(turn)],
                output: []
            ),
            generation: model.sessionGeneration,
            connectionID: connectionID
        )
        XCTAssertEqual(model.pendingResponseCancels["resp_done"], "evt_cancel")

        await model.handleRealtimeError(
            RealtimeAPIError(
                type: "invalid_request_error",
                code: "response_cancel_not_active",
                message: "There is no active response to cancel.",
                param: nil,
                eventID: "evt_cancel"
            )
        )

        XCTAssertNil(model.errorMessage)
        XCTAssertTrue(model.pendingResponseCancels.isEmpty)
    }

    func testSessionSetupErrorReturnsAppToRetryableIdleState() async {
        let model = AppModel()
        model.phase = .connecting

        await model.handleRealtimeError(
            RealtimeAPIError(
                type: "invalid_request_error",
                code: "invalid_session",
                message: "The session configuration was rejected.",
                param: "session.model",
                eventID: "evt_session_update"
            )
        )

        XCTAssertEqual(model.phase, .idle)
        XCTAssertEqual(model.errorMessage, "The session configuration was rejected.")
        XCTAssertTrue(model.phase.isPrimaryActionEnabled)
    }

    func testDisconnectRetainsConversationForTheNextConnection() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScreenTutorReconnectTests-\(UUID().uuidString)")
        let history = ConversationHistoryModel(
            store: ConversationLogStore(rootDirectoryURL: directory)
        )
        let model = AppModel(history: history)
        model.beginConversationHistoryIfNeeded()
        let conversationID = try XCTUnwrap(model.historyIdentity.current)
        let connectionID = RealtimeConnectionID()
        model.realtimeConnectionID = connectionID
        model.phase = .listening

        await model.handleDisconnect(
            "The network connection was interrupted.",
            generation: model.sessionGeneration,
            connectionID: connectionID
        )

        XCTAssertEqual(model.phase, .idle)
        XCTAssertEqual(model.recoverableConversation?.id, conversationID)
        XCTAssertEqual(model.microphoneControlState, .reconnect)
        XCTAssertEqual(
            model.errorMessage,
            "The network connection was interrupted."
        )
    }
}
