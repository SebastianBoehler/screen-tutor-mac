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
                    RealtimeSessionUpdateEvent.screenTutor(
                        model: settings.realtimeModel,
                        language: settings.tutorLanguage,
                        tutorInstructions: settings.tutorInstructions,
                        reasoningEffort: settings.reasoningEffort
                    ),
                    connectionID: connectionID
                )
            case "session.updated":
                guard phase == .connecting else { return }
                try await replayConversationHistory(connectionID: connectionID)
                guard
                    isCurrentSession(generation: generation, connectionID: connectionID),
                    phase == .connecting
                else { return }
                beginConversationHistoryIfNeeded()
                recoverableConversation = nil
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
            case "output_audio_buffer.started":
                markAssistantSpeaking(event)
            case "output_audio_buffer.stopped", "output_audio_buffer.cleared":
                finishAssistantPlayback(event)
            case "response.output_audio.delta":
                markAssistantSpeaking(event)
            case "response.output_audio.done":
                break
            case "response.output_audio_transcript.delta":
                if belongsToActiveResponse(event) {
                    markAssistantSpeaking(event)
                    assistantTranscript += event.delta ?? ""
                }
            case "response.output_audio_transcript.done":
                if belongsToActiveResponse(event), let transcript = event.transcript {
                    assistantTranscript = transcript
                    stageAssistantTranscript(event)
                }
            case "response.done":
                recordResponseUsage(event.response)
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
            await teardownSession(
                preserving: error.localizedDescription,
                retainingConversationForReconnect: true
            )
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
        liveToolActivities.removeAll()
        errorMessage = nil
        userIsSpeaking = true
        phase = .listening
        latestUserTranscript = ""
        assistantTranscript = ""
        capturedApplicationName = nil
        lastSnapshotWindowContext = nil
        activeResponseID = nil
        activeResponseTurn = nil
        activeAudioResponseID = nil
        currentUserItemID = nil
        currentUserItemTurn = nil
        clearHighlight?()

        await settleScreenToolTask(cancelling: false)
        guard isCurrentTurn(turn, generation: generation, connectionID: connectionID) else {
            return
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

    private func markAssistantSpeaking(_ event: RealtimeServerEvent) {
        guard
            phase != .paused,
            phase != .pausing,
            belongsToActiveResponse(event)
        else { return }
        activeAudioResponseID = event.responseID ?? activeAudioResponseID
        idleTimer.cancel()
        phase = .speaking
    }

    private func finishAssistantPlayback(_ event: RealtimeServerEvent) {
        guard event.responseID == activeAudioResponseID else { return }
        activeAudioResponseID = nil
        if !userIsSpeaking && phase == .speaking { enterListening() }
    }

    private func belongsToActiveResponse(_ event: RealtimeServerEvent) -> Bool {
        guard
            let activeResponseID,
            let activeResponseTurn,
            turnTracker.isCurrent(activeResponseTurn)
        else { return false }
        return event.responseID == nil || event.responseID == activeResponseID
    }

}
