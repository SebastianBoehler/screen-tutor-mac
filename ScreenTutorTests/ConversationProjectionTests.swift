import Foundation
import XCTest
@testable import ScreenTutor

final class ConversationProjectionTests: XCTestCase {
    func testProjectsLateUserTranscriptionBeforeAssistantInTheSameTurn() throws {
        let conversationID = UUID()
        let start = Date(timeIntervalSince1970: 1_750_000_000)
        let started = ConversationRecord.started(conversationID: conversationID, at: start)
        let assistant = ConversationRecord.message(
            conversationID: conversationID,
            turn: 1,
            role: .assistant,
            text: "That curve shows validation loss.",
            providerItemID: "item_assistant",
            responseID: "response_1",
            at: start.addingTimeInterval(2)
        )
        let user = ConversationRecord.message(
            conversationID: conversationID,
            turn: 1,
            role: .user,
            text: "What does that curve show?",
            providerItemID: "item_user",
            responseID: nil,
            at: start.addingTimeInterval(1)
        )
        let log = ConversationLog(
            conversationID: conversationID,
            records: [started, assistant, user, assistant],
            skippedLineCount: 1,
            fileURL: URL(fileURLWithPath: "/tmp/conversation.jsonl")
        )

        let projection = ConversationProjection(log: log)

        XCTAssertEqual(projection.title, "What does that curve show?")
        XCTAssertEqual(projection.messages.map(\.role), [.user, .assistant])
        XCTAssertEqual(projection.messages.map(\.text), [
            "What does that curve show?",
            "That curve shows validation loss."
        ])
        XCTAssertEqual(projection.skippedLineCount, 1)
    }
}
