import Foundation

struct ConversationMessage: Identifiable, Sendable {
    let id: UUID
    let turn: Int
    let role: ConversationRole
    let text: String
    let timestamp: Date
    let providerItemID: String
    let responseID: String?
    let toolCalls: [ConversationToolCall]
}

struct ConversationToolCall: Identifiable, Sendable {
    let id: UUID
    let turn: Int
    let name: String
    let status: ConversationToolStatus
    let timestamp: Date
}

struct ConversationProjection: Identifiable, Sendable {
    let id: UUID
    let title: String
    let startedAt: Date?
    let messages: [ConversationMessage]
    let toolCalls: [ConversationToolCall]
    let skippedLineCount: Int
    let fileURL: URL

    init(log: ConversationLog) {
        id = log.conversationID
        skippedLineCount = log.skippedLineCount
        fileURL = log.fileURL

        var seenRecordIDs = Set<UUID>()
        let uniqueRecords = log.records.filter { seenRecordIDs.insert($0.id).inserted }
        startedAt = uniqueRecords
            .filter { $0.type == .started }
            .map(\.timestamp)
            .min() ?? uniqueRecords.map(\.timestamp).min()

        let projectedToolCalls = uniqueRecords.compactMap { record in
            guard
                record.type == .toolCall,
                let turn = record.turn,
                let name = record.toolName,
                let status = record.toolStatus
            else { return nil }
            return ConversationToolCall(
                id: record.id,
                turn: turn,
                name: name,
                status: status,
                timestamp: record.timestamp
            )
        }
        .sorted(by: Self.toolPrecedes)
        toolCalls = projectedToolCalls

        let projectedMessages = uniqueRecords.compactMap { record in
            guard
                record.type == .message,
                let turn = record.turn,
                let role = record.role,
                let text = record.text,
                let providerItemID = record.providerItemID
            else { return nil }
            return ConversationMessage(
                id: record.id,
                turn: turn,
                role: role,
                text: text,
                timestamp: record.timestamp,
                providerItemID: providerItemID,
                responseID: record.responseID,
                toolCalls: []
            )
        }
        .sorted(by: Self.precedes)

        var attachedTurns = Set<Int>()
        messages = projectedMessages.map { message in
            let activities = message.role == .assistant && attachedTurns.insert(message.turn).inserted
                ? projectedToolCalls.filter { $0.turn == message.turn }
                : []
            return ConversationMessage(
                id: message.id,
                turn: message.turn,
                role: message.role,
                text: message.text,
                timestamp: message.timestamp,
                providerItemID: message.providerItemID,
                responseID: message.responseID,
                toolCalls: activities
            )
        }

        title = messages
            .first(where: { $0.role == .user })?
            .text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty ?? "Conversation"
    }

    private static func precedes(
        _ lhs: ConversationMessage,
        _ rhs: ConversationMessage
    ) -> Bool {
        if lhs.turn != rhs.turn { return lhs.turn < rhs.turn }
        if lhs.role != rhs.role { return lhs.role == .user }
        if lhs.timestamp != rhs.timestamp { return lhs.timestamp < rhs.timestamp }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func toolPrecedes(
        _ lhs: ConversationToolCall,
        _ rhs: ConversationToolCall
    ) -> Bool {
        if lhs.turn != rhs.turn { return lhs.turn < rhs.turn }
        if lhs.timestamp != rhs.timestamp { return lhs.timestamp < rhs.timestamp }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
