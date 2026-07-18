import Foundation

enum ConversationRole: String, Codable, Sendable {
    case user
    case assistant
}

enum ConversationRecordType: String, Codable, Sendable {
    case started = "conversation_started"
    case message
}

struct ConversationRecord: Codable, Identifiable, Sendable {
    let schemaVersion: Int
    let id: UUID
    let conversationID: UUID
    let timestamp: Date
    let type: ConversationRecordType
    let turn: Int?
    let role: ConversationRole?
    let text: String?
    let providerItemID: String?
    let responseID: String?

    static func started(
        conversationID: UUID,
        at timestamp: Date = Date()
    ) -> ConversationRecord {
        ConversationRecord(
            schemaVersion: 1,
            id: UUID(),
            conversationID: conversationID,
            timestamp: timestamp,
            type: .started,
            turn: nil,
            role: nil,
            text: nil,
            providerItemID: nil,
            responseID: nil
        )
    }

    static func message(
        conversationID: UUID,
        turn: Int,
        role: ConversationRole,
        text: String,
        providerItemID: String,
        responseID: String? = nil,
        at timestamp: Date = Date()
    ) -> ConversationRecord {
        ConversationRecord(
            schemaVersion: 1,
            id: UUID(),
            conversationID: conversationID,
            timestamp: timestamp,
            type: .message,
            turn: turn,
            role: role,
            text: text,
            providerItemID: providerItemID,
            responseID: responseID
        )
    }

    enum CodingKeys: String, CodingKey {
        case turn, role, text
        case schemaVersion = "schema"
        case id = "record_id"
        case conversationID = "conversation_id"
        case timestamp
        case type
        case providerItemID = "provider_item_id"
        case responseID = "response_id"
    }
}

struct ConversationLog: Sendable {
    let conversationID: UUID
    let records: [ConversationRecord]
    let skippedLineCount: Int
    let fileURL: URL
}
