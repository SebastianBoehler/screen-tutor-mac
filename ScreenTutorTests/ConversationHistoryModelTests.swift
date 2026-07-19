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
}
