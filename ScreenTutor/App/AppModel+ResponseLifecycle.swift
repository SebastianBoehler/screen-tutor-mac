import Foundation

extension AppModel {
    func requestResponse(
        for turn: Int,
        generation: Int,
        connectionID: RealtimeConnectionID
    ) async throws {
        guard
            isCurrentTurn(turn, generation: generation, connectionID: connectionID),
            phase != .paused,
            phase != .pausing,
            phase != .stopping,
            phase != .idle
        else { return }
        let event = ResponseCreateEvent(turnID: turn)
        pendingResponseCreates[event.eventID] = turn
        do {
            try await realtimeClient.send(event, connectionID: connectionID)
        } catch {
            pendingResponseCreates.removeValue(forKey: event.eventID)
            throw error
        }
    }

    func responseCreated(
        _ response: RealtimeResponse?,
        generation: Int,
        connectionID: RealtimeConnectionID
    ) async throws {
        guard let responseID = response?.id else { return }
        let turn = response?.metadata?["screen_tutor_turn"].flatMap(Int.init)
        if let turn {
            pendingResponseCreates = pendingResponseCreates.filter { $0.value != turn }
        }
        guard
            let turn,
            isCurrentTurn(turn, generation: generation, connectionID: connectionID),
            phase != .paused,
            phase != .pausing,
            phase != .stopping
        else {
            try await sendResponseCancel(
                responseID: responseID,
                connectionID: connectionID
            )
            return
        }
        activeResponseID = responseID
        activeResponseTurn = turn
        assistantTranscript = ""
    }

    func handleResponseDone(
        _ response: RealtimeResponse?,
        generation: Int,
        connectionID: RealtimeConnectionID
    ) async throws {
        guard
            let responseID = response?.id,
            let turn = response?.metadata?["screen_tutor_turn"].flatMap(Int.init),
            let status = response?.status
        else { return }
        if status == "cancelled" {
            pendingResponseCancels.removeValue(forKey: responseID)
        }
        pendingResponseCreates = pendingResponseCreates.filter { $0.value != turn }

        let ownsActiveResponse = responseID == activeResponseID
        if ownsActiveResponse {
            activeResponseID = nil
            activeResponseTurn = nil
        }

        let functionCall = response?.output?.first(where: { $0.type == "function_call" })
        guard
            isCurrentTurn(turn, generation: generation, connectionID: connectionID),
            ownsActiveResponse
        else {
            if status == "completed", let functionCall {
                try await sendTurnCancelledOutput(
                    for: functionCall,
                    connectionID: connectionID
                )
            }
            return
        }

        switch status {
        case "completed":
            if let functionCall {
                beginFunctionCall(
                    functionCall,
                    userItemID: currentUserItemTurn == turn ? currentUserItemID : nil,
                    turn: turn,
                    generation: generation,
                    connectionID: connectionID
                )
            } else if activeAssistantItemID == nil, phase == .thinking {
                enterListening()
            }
        case "failed", "incomplete":
            throw AppModelError.responseFailed(status)
        case "cancelled":
            if
                !userIsSpeaking,
                phase != .paused,
                phase != .pausing,
                phase != .stopping
            {
                enterListening()
            }
        default:
            break
        }
    }

    func sendResponseCancel(
        responseID: String,
        connectionID: RealtimeConnectionID
    ) async throws {
        guard pendingResponseCancels[responseID] == nil else { return }
        let event = ResponseCancelEvent(responseID: responseID)
        pendingResponseCancels[responseID] = event.eventID
        do {
            try await realtimeClient.send(event, connectionID: connectionID)
        } catch {
            if pendingResponseCancels[responseID] == event.eventID {
                pendingResponseCancels.removeValue(forKey: responseID)
            }
            throw error
        }
    }

    func handleRealtimeError(_ error: RealtimeAPIError?) async {
        let message = error?.message ?? "The Realtime API returned an error."
        if consumeExpectedCancelError(error) { return }
        if
            let eventID = error?.eventID,
            let turn = pendingResponseCreates.removeValue(forKey: eventID)
        {
            errorMessage = message
            if turnTracker.isCurrent(turn), phase == .thinking, activeResponseID == nil {
                enterListening()
            }
            return
        }
        if phase == .connecting {
            await teardownSession(
                preserving: message,
                retainingConversationForReconnect: historyIdentity.current != nil
            )
            return
        }
        errorMessage = message
    }

    private func consumeExpectedCancelError(_ error: RealtimeAPIError?) -> Bool {
        guard
            let eventID = error?.eventID,
            let responseID = pendingResponseCancels.first(where: { $0.value == eventID })?.key
        else { return false }
        pendingResponseCancels.removeValue(forKey: responseID)
        return true
    }
}
