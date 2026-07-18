import Foundation
import XCTest
@testable import ScreenTutor

final class ConversationLogStoreTests: XCTestCase {
    func testRecordsRoundTripAsOneJSONObjectPerLine() async throws {
        let fixture = try Fixture()
        let conversationID = UUID()
        let startedAt = Date(timeIntervalSince1970: 1_750_000_000)
        let store = ConversationLogStore(rootDirectoryURL: fixture.directory)

        try await store.append(.started(conversationID: conversationID, at: startedAt))
        try await store.append(
            .message(
                conversationID: conversationID,
                turn: 1,
                role: .user,
                text: "Explain this formula",
                providerItemID: "item_user_1",
                responseID: nil,
                at: startedAt.addingTimeInterval(1)
            )
        )

        let fileURL = store.fileURL(for: conversationID)
        let lines = try String(contentsOf: fileURL, encoding: .utf8)
            .split(separator: "\n")
        XCTAssertEqual(lines.count, 2)
        for line in lines {
            XCTAssertNoThrow(try JSONSerialization.jsonObject(with: Data(line.utf8)))
        }

        let loaded = try await store.loadConversation(conversationID)
        XCTAssertEqual(loaded.records.count, 2)
        XCTAssertEqual(loaded.skippedLineCount, 0)
        XCTAssertEqual(loaded.records.last?.text, "Explain this formula")
    }

    func testMalformedTailDoesNotHideARecordAppendedAfterIt() async throws {
        let fixture = try Fixture()
        let conversationID = UUID()
        let store = ConversationLogStore(rootDirectoryURL: fixture.directory)
        try await store.append(.started(conversationID: conversationID))

        let fileURL = store.fileURL(for: conversationID)
        let handle = try FileHandle(forWritingTo: fileURL)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(#"{"truncated":true"#.utf8))
        try handle.close()

        try await store.append(
            .message(
                conversationID: conversationID,
                turn: 1,
                role: .assistant,
                text: "The valid reply",
                providerItemID: "item_assistant_1"
            )
        )

        let loaded = try await store.loadConversation(conversationID)
        XCTAssertEqual(loaded.records.count, 2)
        XCTAssertEqual(loaded.skippedLineCount, 1)
        XCTAssertEqual(loaded.records.last?.text, "The valid reply")
    }

    func testConcurrentAppendsAreSerializedAndPrivate() async throws {
        let fixture = try Fixture()
        let conversationID = UUID()
        let store = ConversationLogStore(rootDirectoryURL: fixture.directory)
        try await store.append(.started(conversationID: conversationID))

        try await withThrowingTaskGroup(of: Void.self) { group in
            for turn in 1...20 {
                group.addTask {
                    try await store.append(
                        .message(
                            conversationID: conversationID,
                            turn: turn,
                            role: .assistant,
                            text: "Reply \(turn)",
                            providerItemID: "item_\(turn)"
                        )
                    )
                }
            }
            try await group.waitForAll()
        }

        let loaded = try await store.loadConversation(conversationID)
        XCTAssertEqual(loaded.records.count, 21)
        let attributes = try FileManager.default.attributesOfItem(
            atPath: store.fileURL(for: conversationID).path
        )
        let permissions = try XCTUnwrap(attributes[.posixPermissions] as? NSNumber)
        XCTAssertEqual(permissions.intValue & 0o777, 0o600)
    }
}

private struct Fixture {
    let directory: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScreenTutorHistoryTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }
}
