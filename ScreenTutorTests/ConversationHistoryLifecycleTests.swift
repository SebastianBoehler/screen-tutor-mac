import Foundation
import XCTest
@testable import ScreenTutor

@MainActor
final class ConversationHistoryLifecycleTests: XCTestCase {
    func testFailedInputTranscriptionLeavesAnExplicitUserMarker() async throws {
        let model = makeModel()
        model.beginConversationHistoryIfNeeded()
        model.trackUserHistoryTurn(itemID: "user-item", turn: 1)

        model.recordUserTranscriptionFailure(itemID: "user-item")
        await model.history.flush()

        let conversation = try XCTUnwrap(model.history.conversations.first)
        XCTAssertEqual(conversation.messages.map(\.role), [.user])
        XCTAssertEqual(
            conversation.messages.first?.text,
            "Voice transcript unavailable for this turn."
        )
    }

    func testLateResponseDoesNotEnterHistoryAfterResponseOwnershipChanges() async throws {
        let model = makeModel()
        model.beginConversationHistoryIfNeeded()
        let conversationID = try XCTUnwrap(model.historyIdentity.current)
        let turn = model.turnTracker.advance()
        model.activeResponseID = "current-response"
        model.activeResponseTurn = turn
        model.pendingAssistantHistory["stale-response"] = PendingAssistantHistoryMessage(
            conversationID: conversationID,
            turn: turn,
            itemID: "assistant-item",
            text: "Stale answer",
            timestamp: Date()
        )

        model.finalizeAssistantHistory(
            RealtimeResponse(
                id: "stale-response",
                status: "completed",
                metadata: ["screen_tutor_turn": String(turn)],
                output: []
            )
        )
        await model.history.flush()

        XCTAssertTrue(model.history.conversations.first?.messages.isEmpty == true)
    }

    private func makeModel() -> AppModel {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScreenTutorHistoryLifecycleTests-\(UUID().uuidString)")
        return AppModel(
            history: ConversationHistoryModel(
                store: ConversationLogStore(rootDirectoryURL: directory)
            )
        )
    }
}
