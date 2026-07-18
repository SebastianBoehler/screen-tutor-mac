import Foundation

extension AppModel {
    func startSession() async {
        guard phase == .idle else { return }
        errorMessage = nil
        assistantTranscript = ""
        capturedApplicationName = nil
        phase = .requestingPermissions
        sessionGeneration &+= 1
        let generation = sessionGeneration
        turnTracker = ConversationTurnTracker()

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
            await teardownSession(preserving: error.localizedDescription)
        }
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
        idleTimer.arm { [weak self] in
            Task { @MainActor [weak self] in
                guard
                    let self,
                    self.phase == .listening,
                    !self.userIsSpeaking
                else { return }
                await self.pauseListening()
            }
        }
    }

    func resumeListening() async {
        guard phase == .paused, let connectionID = realtimeConnectionID else { return }
        let generation = sessionGeneration
        errorMessage = nil
        phase = .resuming
        do {
            try await startAudioStreaming(
                generation: generation,
                connectionID: connectionID
            )
            guard
                isCurrentSession(generation: generation, connectionID: connectionID),
                phase == .resuming
            else { return }
            enterListening()
        } catch {
            guard isCurrentSession(generation: generation, connectionID: connectionID) else {
                return
            }
            phase = .paused
            errorMessage = error.localizedDescription
        }
    }

    func pauseListening() async {
        guard
            phase == .listening || phase == .thinking || phase == .speaking,
            let connectionID = realtimeConnectionID
        else { return }
        let generation = sessionGeneration
        idleTimer.cancel()
        phase = .pausing
        let pauseTurn = turnTracker.advance()
        userIsSpeaking = false
        screenTools.invalidateWindowCatalog()
        clearHighlight?()
        let responseID = activeResponseID
        activeResponseID = nil
        activeResponseTurn = nil
        activeAssistantItemID = nil
        let uploadTask = audioUploadTask
        audioUploadTask = nil
        uploadTask?.cancel()
        let cutoff = await audioIO.interruptAssistantAudio(ownerID: connectionID)
        await settleScreenToolTask(cancelling: false)
        guard isCurrentPause(pauseTurn, generation: generation, connectionID: connectionID) else {
            return
        }
        if let uploadTask { await uploadTask.value }
        guard isCurrentPause(pauseTurn, generation: generation, connectionID: connectionID) else {
            return
        }
        await audioIO.stop(ownerID: connectionID)
        guard isCurrentPause(pauseTurn, generation: generation, connectionID: connectionID) else {
            return
        }
        do {
            if let responseID {
                try await sendResponseCancel(
                    responseID: responseID,
                    connectionID: connectionID
                )
            }
            guard isCurrentPause(pauseTurn, generation: generation, connectionID: connectionID) else {
                return
            }
            if let cutoff {
                try await realtimeClient.send(
                    ConversationTruncateEvent(
                        itemID: cutoff.itemID,
                        audioEndMilliseconds: cutoff.audioEndMilliseconds
                    ),
                    connectionID: connectionID
                )
            }
            guard isCurrentPause(pauseTurn, generation: generation, connectionID: connectionID) else {
                return
            }
            try await realtimeClient.send(
                InputAudioClearEvent(),
                connectionID: connectionID
            )
            guard isCurrentPause(pauseTurn, generation: generation, connectionID: connectionID) else {
                return
            }
            phase = .paused
        } catch {
            guard isCurrentSession(generation: generation, connectionID: connectionID) else {
                return
            }
            await teardownSession(preserving: error.localizedDescription)
        }
    }

    func handleAudioFailure(
        _ error: Error,
        generation: Int,
        connectionID: RealtimeConnectionID
    ) async {
        guard
            isCurrentSession(generation: generation, connectionID: connectionID),
            phase != .paused,
            phase != .pausing
        else { return }
        await teardownSession(preserving: error.localizedDescription)
    }

    func handleDisconnect(
        _ message: String,
        generation: Int,
        connectionID: RealtimeConnectionID
    ) async {
        guard isCurrentSession(generation: generation, connectionID: connectionID) else {
            return
        }
        await teardownSession(preserving: message)
    }

    private func isCurrentPause(
        _ turn: Int,
        generation: Int,
        connectionID: RealtimeConnectionID
    ) -> Bool {
        isCurrentTurn(turn, generation: generation, connectionID: connectionID)
            && phase == .pausing
    }
}
