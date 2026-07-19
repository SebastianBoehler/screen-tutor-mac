import Foundation

extension AppModel {
    func startSession(continuing conversation: ConversationProjection? = nil) async {
        guard phase == .idle else { return }
        errorMessage = nil
        isMicrophoneMuted = false
        assistantTranscript = ""
        capturedApplicationName = nil
        phase = .requestingPermissions
        sessionGeneration &+= 1
        let generation = sessionGeneration
        pendingHistoryReplay = conversation?.messages ?? []
        if let conversation {
            historyIdentity.resume(conversation.id)
        }
        let latestArchivedTurn = conversation?.messages.map(\.turn).max() ?? 0
        turnTracker = ConversationTurnTracker(initialTurn: latestArchivedTurn)

        do {
            guard let apiKey = try settings.loadAPIKey() else {
                throw AppModelError.missingAPIKey
            }
            guard await MicrophonePermissionService.request() else {
                throw AudioIOError.microphonePermissionDenied
            }
            guard generation == sessionGeneration else { return }
            settings.refresh()
            guard captureService.hasPermission || captureService.requestPermission() else {
                throw ScreenCaptureError.permissionDenied
            }
            settings.refresh()
            guard settings.screenPermissionGranted else {
                throw AppModelError.screenPermissionRequiresRestart
            }
            guard generation == sessionGeneration else { return }

            phase = .connecting
            let connectionID = RealtimeConnectionID()
            realtimeConnectionID = connectionID
            try await realtimeClient.connect(
                connectionID: connectionID,
                apiKey: apiKey,
                model: settings.realtimeModel,
                onEvent: { [weak self] event in
                    await self?.handle(
                        event,
                        generation: generation,
                        connectionID: connectionID
                    )
                },
                onDisconnect: { [weak self] message in
                    await self?.handleDisconnect(
                        message,
                        generation: generation,
                        connectionID: connectionID
                    )
                }
            )
            guard isCurrentSession(generation: generation, connectionID: connectionID) else {
                await realtimeClient.disconnect(connectionID: connectionID)
                return
            }
        } catch {
            guard generation == sessionGeneration else { return }
            await teardownSession(
                preserving: error.localizedDescription,
                retainingConversationForReconnect: conversation != nil
            )
        }
    }

    func replayConversationHistory(
        connectionID: RealtimeConnectionID
    ) async throws {
        for message in pendingHistoryReplay {
            try await realtimeClient.send(
                ConversationReplayEvent(role: message.role, text: message.text),
                connectionID: connectionID
            )
        }
        pendingHistoryReplay.removeAll()
    }

    func startAudioStreaming(
        generation: Int,
        connectionID: RealtimeConnectionID
    ) async throws {
        let stream = try await audioIO.start(
            ownerID: connectionID,
            onPlaybackDrained: { [weak self] itemID in
                await self?.playbackDrained(
                    itemID: itemID,
                    generation: generation,
                    connectionID: connectionID
                )
            }
        )
        guard isCurrentSession(generation: generation, connectionID: connectionID) else {
            await audioIO.stop(ownerID: connectionID)
            return
        }
        audioUploadTask = Task { [weak self] in
            do {
                for try await pcmData in stream {
                    guard
                        let self,
                        self.isCurrentSession(
                            generation: generation,
                            connectionID: connectionID
                        )
                    else { return }
                    guard self.shouldUploadMicrophoneAudio else { continue }
                    try await self.realtimeClient.send(
                        InputAudioAppendEvent(pcmData: pcmData),
                        connectionID: connectionID
                    )
                }
            } catch is CancellationError {
                return
            } catch {
                let failure = error
                Task { @MainActor [weak self] in
                    await self?.handleAudioFailure(
                        failure,
                        generation: generation,
                        connectionID: connectionID
                    )
                }
            }
        }
    }

    func enterListening() {
        phase = .listening
        guard !isMicrophoneMuted else {
            idleTimer.cancel()
            return
        }
        idleTimer.arm { [weak self] in
            Task { @MainActor [weak self] in
                guard
                    let self,
                    self.phase == .listening,
                    !self.userIsSpeaking,
                    !self.isMicrophoneMuted
                else { return }
                await self.setMicrophoneMuted(true)
            }
        }
    }

    func setMicrophoneMuted(_ muted: Bool) async {
        guard phase.hasConversation, realtimeConnectionID != nil else { return }
        isMicrophoneMuted = muted
        userIsSpeaking = muted ? false : userIsSpeaking
        if muted {
            idleTimer.cancel()
        } else {
            errorMessage = nil
            if phase == .listening { enterListening() }
        }
    }

    func handleAudioFailure(
        _ error: Error,
        generation: Int,
        connectionID: RealtimeConnectionID
    ) async {
        guard
            isCurrentSession(generation: generation, connectionID: connectionID)
        else { return }
        await teardownSession(
            preserving: error.localizedDescription,
            retainingConversationForReconnect: true
        )
    }

    func handleDisconnect(
        _ message: String,
        generation: Int,
        connectionID: RealtimeConnectionID
    ) async {
        guard isCurrentSession(generation: generation, connectionID: connectionID) else {
            return
        }
        await teardownSession(
            preserving: message,
            retainingConversationForReconnect: true
        )
    }
}
