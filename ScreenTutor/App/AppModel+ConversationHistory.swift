import Foundation

struct ConversationHistoryIdentity {
    private(set) var current: UUID?

    mutating func ensureCurrent(
        using makeID: () -> UUID = UUID.init
    ) -> UUID {
        if let current { return current }
        let id = makeID()
        current = id
        return id
    }

    mutating func clear() {
        current = nil
    }
}

struct PendingUserHistoryTurn {
    let conversationID: UUID
    let turn: Int
    let timestamp: Date
}

struct PendingAssistantHistoryMessage {
    let conversationID: UUID
    let turn: Int
    let itemID: String
    let text: String
    let timestamp: Date
}

extension AppModel {
    func beginConversationHistoryIfNeeded() {
        guard historyIdentity.current == nil else { return }
        let conversationID = historyIdentity.ensureCurrent()
        history.record(.started(conversationID: conversationID))
    }

    func trackUserHistoryTurn(itemID: String, turn: Int) {
        guard let conversationID = historyIdentity.current else { return }
        pendingUserHistoryTurns[itemID] = PendingUserHistoryTurn(
            conversationID: conversationID,
            turn: turn,
            timestamp: Date()
        )
    }

    func recordUserTranscript(itemID: String?, transcript: String?) {
        guard
            let itemID,
            let turn = pendingUserHistoryTurns.removeValue(forKey: itemID),
            turn.conversationID == historyIdentity.current
        else { return }
        let text = transcript?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else {
            recordUnavailableUserTranscript(itemID: itemID, turn: turn)
            return
        }

        latestUserTranscript = text
        history.record(
            .message(
                conversationID: turn.conversationID,
                turn: turn.turn,
                role: .user,
                text: text,
                providerItemID: itemID,
                at: turn.timestamp
            )
        )
    }

    func recordUserTranscriptionFailure(itemID: String?) {
        guard
            let itemID,
            let turn = pendingUserHistoryTurns.removeValue(forKey: itemID),
            turn.conversationID == historyIdentity.current
        else { return }
        recordUnavailableUserTranscript(itemID: itemID, turn: turn)
    }

    func stageAssistantTranscript(_ event: RealtimeServerEvent) {
        guard
            let conversationID = historyIdentity.current,
            let responseID = event.responseID ?? activeResponseID,
            let turn = activeResponseTurn,
            let itemID = event.itemID,
            let text = event.transcript?.trimmingCharacters(in: .whitespacesAndNewlines),
            !text.isEmpty
        else { return }

        pendingAssistantHistory[responseID] = PendingAssistantHistoryMessage(
            conversationID: conversationID,
            turn: turn,
            itemID: itemID,
            text: text,
            timestamp: Date()
        )
    }

    func recordToolActivity(
        name: String?,
        status: ConversationToolStatus,
        turn: Int
    ) {
        guard
            let conversationID = historyIdentity.current,
            let name = name?.trimmingCharacters(in: .whitespacesAndNewlines),
            !name.isEmpty
        else { return }
        history.record(
            .toolCall(
                conversationID: conversationID,
                turn: turn,
                name: name,
                status: status
            )
        )
    }

    func finalizeAssistantHistory(_ response: RealtimeResponse?) {
        guard let responseID = response?.id else { return }
        guard let pending = pendingAssistantHistory.removeValue(forKey: responseID) else { return }
        guard
            responseID == activeResponseID,
            activeResponseTurn == pending.turn,
            response?.metadata?["screen_tutor_turn"].flatMap(Int.init) == pending.turn,
            turnTracker.isCurrent(pending.turn),
            response?.status == "completed",
            response?.output?.contains(where: { $0.type == "function_call" }) != true,
            pending.conversationID == historyIdentity.current
        else { return }

        history.record(
            .message(
                conversationID: pending.conversationID,
                turn: pending.turn,
                role: .assistant,
                text: pending.text,
                providerItemID: pending.itemID,
                responseID: responseID,
                at: pending.timestamp
            )
        )
    }

    private func recordUnavailableUserTranscript(
        itemID: String,
        turn: PendingUserHistoryTurn
    ) {
        let text = "Voice transcript unavailable for this turn."
        latestUserTranscript = text
        history.record(
            .message(
                conversationID: turn.conversationID,
                turn: turn.turn,
                role: .user,
                text: text,
                providerItemID: itemID,
                at: turn.timestamp
            )
        )
    }

    func resetConversationHistorySession() {
        historyIdentity.clear()
        pendingUserHistoryTurns.removeAll()
        pendingAssistantHistory.removeAll()
        latestUserTranscript = ""
    }

    func finishPendingConversationHistory() {
        for itemID in Array(pendingUserHistoryTurns.keys) {
            recordUserTranscriptionFailure(itemID: itemID)
        }
        pendingAssistantHistory.removeAll()
    }
}
