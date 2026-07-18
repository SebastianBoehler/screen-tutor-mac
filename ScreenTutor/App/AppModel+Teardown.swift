import Foundation

extension AppModel {
    func teardownSession(preserving message: String?) async {
        if let teardownTask {
            await teardownTask.value
            return
        }

        let taskID = UUID()
        teardownTaskID = taskID
        let task = Task<Void, Never> { @MainActor [weak self] in
            guard let self else { return }
            await self.performTeardown(preserving: message)
            guard self.teardownTaskID == taskID else { return }
            self.teardownTask = nil
            self.teardownTaskID = nil
        }
        teardownTask = task
        await task.value
    }

    private func performTeardown(preserving message: String?) async {
        sessionGeneration &+= 1
        _ = turnTracker.advance()
        let generation = sessionGeneration
        let connectionID = realtimeConnectionID
        realtimeConnectionID = nil
        idleTimer.cancel()
        if phase != .idle { phase = .stopping }

        await settleScreenToolTask(cancelling: true)
        let uploadTask = audioUploadTask
        audioUploadTask = nil
        uploadTask?.cancel()
        if let uploadTask { await uploadTask.value }
        if let connectionID {
            await audioIO.stop(ownerID: connectionID)
        }
        guard generation == sessionGeneration else { return }
        if let connectionID {
            await realtimeClient.disconnect(connectionID: connectionID)
        }
        guard generation == sessionGeneration else { return }

        finishPendingConversationHistory()
        await history.flush()
        screenTools.invalidateWindowCatalog()
        activeResponseID = nil
        activeResponseTurn = nil
        currentUserItemID = nil
        currentUserItemTurn = nil
        pendingResponseCancels.removeAll()
        pendingResponseCreates.removeAll()
        activeAssistantItemID = nil
        userIsSpeaking = false
        capturedApplicationName = nil
        lastSnapshotWindowContext = nil
        resetConversationHistorySession()
        clearHighlight?()
        phase = .idle
        errorMessage = message
        settings.refresh()
    }
}
