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
                throw AppModelError.microphonePermissionDenied
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
                realtimeClient.disconnect(connectionID: connectionID)
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
        guard phase.hasConversation, let connectionID = realtimeConnectionID else { return }
        do {
            try await realtimeClient.setMicrophoneMuted(
                muted,
                connectionID: connectionID
            )
            isMicrophoneMuted = muted
            userIsSpeaking = muted ? false : userIsSpeaking
            if muted {
                idleTimer.cancel()
            } else {
                errorMessage = nil
                if phase == .listening { enterListening() }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
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
