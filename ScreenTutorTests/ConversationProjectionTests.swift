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
        let captureTool = ConversationRecord.toolCall(
            conversationID: conversationID,
            turn: 1,
            name: "capture_window",
            status: .succeeded,
            at: start.addingTimeInterval(1.25)
        )
        let pointerTool = ConversationRecord.toolCall(
            conversationID: conversationID,
            turn: 1,
            name: "point_at_screen_position",
            status: .failed,
            at: start.addingTimeInterval(1.5)
        )
        let log = ConversationLog(
            conversationID: conversationID,
            records: [started, assistant, captureTool, user, pointerTool, assistant],
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
        XCTAssertEqual(
            projection.messages.last?.toolCalls.map(\.name),
            ["capture_window", "point_at_screen_position"]
        )
        XCTAssertEqual(
            projection.messages.last?.toolCalls.map(\.status),
            [.succeeded, .failed]
        )
        XCTAssertEqual(projection.skippedLineCount, 1)
    }

    func testAggregatesUsageAcrossEveryResponseInConversation() {
        let conversationID = UUID()
        let firstUsage = TokenUsage(
            inputTokens: 100,
            outputTokens: 20,
            totalTokens: 120,
            inputAudioTokens: 60,
            cachedInputTokens: 40,
            outputAudioTokens: 12
        )
        let secondUsage = TokenUsage(
            inputTokens: 180,
            outputTokens: 30,
            totalTokens: 210,
            inputAudioTokens: 80,
            cachedInputTokens: 120,
            outputAudioTokens: 18
        )
        let log = ConversationLog(
            conversationID: conversationID,
            records: [
                .usage(
                    conversationID: conversationID,
                    turn: 1,
                    responseID: "response_1",
                    usage: firstUsage
                ),
                .usage(
                    conversationID: conversationID,
                    turn: 1,
                    responseID: "response_tool_followup",
                    usage: secondUsage
                )
            ],
            skippedLineCount: 0,
            fileURL: URL(fileURLWithPath: "/tmp/conversation.jsonl")
        )

        let usage = ConversationProjection(log: log).usage

        XCTAssertEqual(usage.inputTokens, 280)
        XCTAssertEqual(usage.outputTokens, 50)
        XCTAssertEqual(usage.totalTokens, 330)
        XCTAssertEqual(usage.cachedInputTokens, 160)
        XCTAssertEqual(usage.inputAudioTokens, 140)
        XCTAssertEqual(usage.outputAudioTokens, 30)
    }
}
