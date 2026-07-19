import Foundation

extension AppModel {
    func teardownSession(
        preserving message: String?,
        retainingConversationForReconnect: Bool = false
    ) async {
        if let teardownTask {
            await teardownTask.value
            return
        }

        let taskID = UUID()
        teardownTaskID = taskID
        let task = Task<Void, Never> { @MainActor [weak self] in
            guard let self else { return }
            await self.performTeardown(
                preserving: message,
                retainingConversationForReconnect: retainingConversationForReconnect
            )
            guard self.teardownTaskID == taskID else { return }
            self.teardownTask = nil
            self.teardownTaskID = nil
        }
        teardownTask = task
        await task.value
    }

    private func performTeardown(
        preserving message: String?,
        retainingConversationForReconnect: Bool
    ) async {
        let recoveryID = retainingConversationForReconnect ? historyIdentity.current : nil
        let existingRecovery = recoverableConversation
        sessionGeneration &+= 1
        _ = turnTracker.advance()
        let generation = sessionGeneration
        let connectionID = realtimeConnectionID
        realtimeConnectionID = nil
        idleTimer.cancel()
        if phase != .idle { phase = .stopping }

        await settleScreenToolTask(cancelling: true)
        if let connectionID {
            realtimeClient.disconnect(connectionID: connectionID)
        }
        guard generation == sessionGeneration else { return }

        finishPendingConversationHistory()
        await history.flush()
        let recoveredConversation: ConversationProjection? = if let recoveryID {
            await history.conversation(id: recoveryID)
        } else {
            nil
        }
        screenTools.invalidateWindowCatalog()
        activeResponseID = nil
        activeResponseTurn = nil
        currentUserItemID = nil
        currentUserItemTurn = nil
        pendingResponseCancels.removeAll()
        pendingResponseCreates.removeAll()
        activeAudioResponseID = nil
        userIsSpeaking = false
        isMicrophoneMuted = true
        liveToolActivities.removeAll()
        capturedApplicationName = nil
        lastSnapshotWindowContext = nil
        resetConversationHistorySession()
        recoverableConversation = retainingConversationForReconnect
            ? recoveredConversation ?? existingRecovery
            : nil
        clearHighlight?()
        phase = .idle
        errorMessage = message
        settings.refresh()
    }
}
