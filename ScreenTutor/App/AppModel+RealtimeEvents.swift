import Foundation

extension AppModel {
    func handle(
        _ event: RealtimeServerEvent,
        generation: Int,
        connectionID: RealtimeConnectionID
    ) async {
        guard isCurrentSession(generation: generation, connectionID: connectionID) else {
            return
        }
        do {
            switch event.type {
            case "session.created":
                try await realtimeClient.send(
                    RealtimeSessionUpdateEvent.screenTutor,
                    connectionID: connectionID
                )
            case "session.updated":
                guard phase == .connecting else { return }
                try await startAudioStreaming(
                    generation: generation,
                    connectionID: connectionID
                )
                guard
                    isCurrentSession(generation: generation, connectionID: connectionID),
                    phase == .connecting
                else { return }
                beginConversationHistoryIfNeeded()
                enterListening()
            case "input_audio_buffer.speech_started":
                if phase != .paused && phase != .pausing {
                    await speechStarted(generation: generation, connectionID: connectionID)
                }
            case "input_audio_buffer.speech_stopped":
                userIsSpeaking = false
            case "input_audio_buffer.committed":
                if phase != .paused && phase != .pausing {
                    try await committedUserTurn(
                        itemID: event.itemID,
                        generation: generation,
                        connectionID: connectionID
                    )
                }
            case "conversation.item.input_audio_transcription.completed":
                recordUserTranscript(itemID: event.itemID, transcript: event.transcript)
            case "conversation.item.input_audio_transcription.failed":
                recordUserTranscriptionFailure(itemID: event.itemID)
            case "response.created":
                try await responseCreated(
                    event.response,
                    generation: generation,
                    connectionID: connectionID
                )
            case "response.output_audio.delta":
                try await receiveAudioDelta(
                    event,
                    generation: generation,
                    connectionID: connectionID
                )
            case "response.output_audio.done":
                if belongsToActiveResponse(event), let itemID = event.itemID {
                    try await audioIO.finishAssistantAudio(
                        itemID: itemID,
                        ownerID: connectionID
                    )
                }
            case "response.output_audio_transcript.delta":
                if belongsToActiveResponse(event) { assistantTranscript += event.delta ?? "" }
            case "response.output_audio_transcript.done":
                if belongsToActiveResponse(event), let transcript = event.transcript {
                    assistantTranscript = transcript
                    stageAssistantTranscript(event)
                }
            case "response.done":
                finalizeAssistantHistory(event.response)
                try await handleResponseDone(
                    event.response,
                    generation: generation,
                    connectionID: connectionID
                )
            case "error":
                await handleRealtimeError(event.error)
            default:
                break
            }
        } catch {
            guard isCurrentSession(generation: generation, connectionID: connectionID) else {
                return
            }
            await teardownSession(preserving: error.localizedDescription)
        }
    }

    private func speechStarted(
        generation: Int,
        connectionID: RealtimeConnectionID
    ) async {
        guard isCurrentSession(generation: generation, connectionID: connectionID) else {
            return
        }
        let turn = turnTracker.advance()
        idleTimer.cancel()
        screenTools.invalidateWindowCatalog()
        errorMessage = nil
        userIsSpeaking = true
        phase = .listening
        latestUserTranscript = ""
        assistantTranscript = ""
        capturedApplicationName = nil
        lastSnapshotWindowContext = nil
        activeResponseID = nil
        activeResponseTurn = nil
        activeAssistantItemID = nil
        currentUserItemID = nil
        currentUserItemTurn = nil
        clearHighlight?()

        let cutoff = await audioIO.interruptAssistantAudio(ownerID: connectionID)
        await settleScreenToolTask(cancelling: false)
        guard isCurrentTurn(turn, generation: generation, connectionID: connectionID) else {
            return
        }
        if let cutoff {
            guard isCurrentTurn(turn, generation: generation, connectionID: connectionID) else {
                return
            }
            do {
                try await realtimeClient.send(
                    ConversationTruncateEvent(
                        itemID: cutoff.itemID,
                        audioEndMilliseconds: cutoff.audioEndMilliseconds
                    ),
                    connectionID: connectionID
                )
            } catch {
                guard isCurrentTurn(
                    turn,
                    generation: generation,
                    connectionID: connectionID
                ) else { return }
                errorMessage = error.localizedDescription
            }
        }
    }

    private func committedUserTurn(
        itemID: String?,
        generation: Int,
        connectionID: RealtimeConnectionID
    ) async throws {
        guard isCurrentSession(generation: generation, connectionID: connectionID) else {
            return
        }
        let turn = turnTracker.current
        guard let itemID else { throw AppModelError.missingCommittedItemID }
        idleTimer.cancel()
        userIsSpeaking = false
        currentUserItemID = itemID
        currentUserItemTurn = turn
        trackUserHistoryTurn(itemID: itemID, turn: turn)
        phase = .thinking
        try await requestResponse(
            for: turn,
            generation: generation,
            connectionID: connectionID
        )
    }

    private func receiveAudioDelta(
        _ event: RealtimeServerEvent,
        generation: Int,
        connectionID: RealtimeConnectionID
    ) async throws {
        guard
            isCurrentSession(generation: generation, connectionID: connectionID),
            phase != .paused,
            phase != .pausing,
            belongsToActiveResponse(event)
        else { return }
        guard
            let delta = event.delta,
            let data = Data(base64Encoded: delta),
            let itemID = event.itemID
        else { throw AudioIOError.malformedOutputPCM }
        activeAssistantItemID = itemID
        try await audioIO.enqueueAssistantPCM16(
            data,
            itemID: itemID,
            ownerID: connectionID
        )
        guard
            isCurrentSession(generation: generation, connectionID: connectionID),
            belongsToActiveResponse(event)
        else { return }
        idleTimer.cancel()
        phase = .speaking
    }

    private func belongsToActiveResponse(_ event: RealtimeServerEvent) -> Bool {
        guard
            let activeResponseID,
            let activeResponseTurn,
            turnTracker.isCurrent(activeResponseTurn)
        else { return false }
        return event.responseID == nil || event.responseID == activeResponseID
    }

    func playbackDrained(
        itemID: String,
        generation: Int,
        connectionID: RealtimeConnectionID
    ) {
        guard
            isCurrentSession(generation: generation, connectionID: connectionID),
            activeAssistantItemID == itemID
        else { return }
        activeAssistantItemID = nil
        if !userIsSpeaking && phase == .speaking { enterListening() }
    }

}
