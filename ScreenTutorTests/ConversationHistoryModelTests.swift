import Foundation
import XCTest
@testable import ScreenTutor

@MainActor
final class ConversationHistoryModelTests: XCTestCase {
    func testQueuedRecordsPersistInOrderWithoutReloadingTheArchive() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScreenTutorHistoryModelTests-\(UUID().uuidString)")
        let store = ConversationLogStore(rootDirectoryURL: directory)
        let model = ConversationHistoryModel(store: store)
        let conversationID = UUID()

        model.record(.started(conversationID: conversationID))
        model.record(
            .message(
                conversationID: conversationID,
                turn: 1,
                role: .assistant,
                text: "It is the validation curve.",
                providerItemID: "assistant"
            )
        )
        model.record(
            .message(
                conversationID: conversationID,
                turn: 1,
                role: .user,
                text: "What is this curve?",
                providerItemID: "user"
            )
        )

        await model.flush()

        let stored = try await store.loadConversation(conversationID)
        XCTAssertEqual(stored.records.map(\.providerItemID), [nil, "assistant", "user"])
        XCTAssertEqual(model.conversations.first?.messages.map(\.role), [.user, .assistant])
        XCTAssertEqual(
            model.conversationFileURLs,
            [store.fileURL(for: conversationID)]
        )
    }

    func testDeleteConversationFlushesAndRemovesProjection() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScreenTutorHistoryDeleteTests-\(UUID().uuidString)")
        let store = ConversationLogStore(rootDirectoryURL: directory)
        let model = ConversationHistoryModel(store: store)
        let deletedID = UUID()
        let retainedID = UUID()
        model.record(.started(conversationID: deletedID))
        model.record(.started(conversationID: retainedID))

        await model.deleteConversation(id: deletedID)

        XCTAssertEqual(model.conversations.map(\.id), [retainedID])
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: store.fileURL(for: deletedID).path)
        )
        XCTAssertNil(model.errorMessage)
    }

    func testDeleteAllConversationsClearsProjections() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScreenTutorHistoryDeleteAllTests-\(UUID().uuidString)")
        let model = ConversationHistoryModel(
            store: ConversationLogStore(rootDirectoryURL: directory)
        )
        model.record(.started(conversationID: UUID()))
        model.record(.started(conversationID: UUID()))

        await model.deleteAllConversations()

        XCTAssertTrue(model.conversations.isEmpty)
        XCTAssertNil(model.errorMessage)
    }
}
