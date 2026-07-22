import Foundation

extension AppModel {
    func beginFunctionCall(
        _ item: RealtimeItem,
        userItemID: String?,
        turn: Int,
        generation: Int,
        connectionID: RealtimeConnectionID
    ) {
        screenToolTask?.cancel()
        let taskID = UUID()
        screenToolTaskID = taskID
        screenToolTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let failure: Error?
            do {
                try await self.handleFunctionCall(
                    item,
                    userItemID: userItemID,
                    turn: turn,
                    generation: generation,
                    connectionID: connectionID
                )
                failure = nil
            } catch is CancellationError {
                failure = nil
            } catch {
                failure = error
            }

            guard self.screenToolTaskID == taskID else { return }
            self.screenToolTaskID = nil
            self.screenToolTask = nil
            if
                let failure,
                self.isCurrentTurn(
                    turn,
                    generation: generation,
                    connectionID: connectionID
                )
            {
                await self.teardownSession(
                    preserving: failure.localizedDescription,
                    retainingConversationForReconnect: true
                )
            }
        }
    }

    func settleScreenToolTask(cancelling: Bool) async {
        let task = screenToolTask
        screenToolTask = nil
        screenToolTaskID = nil
        if cancelling { task?.cancel() }
        if let task { await task.value }
    }

    func handleFunctionCall(
        _ item: RealtimeItem,
        userItemID: String?,
        turn: Int,
        generation: Int,
        connectionID: RealtimeConnectionID
    ) async throws {
        guard isCurrentTurn(turn, generation: generation, connectionID: connectionID) else {
            try await sendTurnCancelledOutput(for: item, connectionID: connectionID)
            return
        }

        beginToolActivity(name: item.name, turn: turn)

        if item.name == "point_at_screen_position" {
            try await handleTeachingPointerCall(
                item,
                turn: turn,
                generation: generation,
                connectionID: connectionID
            )
            return
        }

        if item.name == "capture_camera" {
            try await handleCameraCall(
                item,
                userItemID: userItemID,
                turn: turn,
                generation: generation,
                connectionID: connectionID
            )
            return
        }

        guard let resolution = try await screenTools.handle(item) else {
            recordToolActivity(name: item.name, status: .failed, turn: turn)
            try await sendToolFailure(
                item: item,
                code: "unknown_tool",
                message: "The requested screen tool is not available.",
                turn: turn,
                generation: generation,
                connectionID: connectionID
            )
            return
        }
        guard isCurrentTurn(turn, generation: generation, connectionID: connectionID) else {
            try await sendTurnCancelledOutput(for: item, connectionID: connectionID)
            return
        }
        recordToolActivity(
            name: item.name,
            status: resolution.succeeded ? .succeeded : .failed,
            turn: turn
        )

        phase = .thinking
        try await realtimeClient.send(
            FunctionCallOutputEvent(
                callID: resolution.callID,
                output: resolution.output,
                previousItemID: item.id
            ),
            connectionID: connectionID
        )
        guard isCurrentTurn(turn, generation: generation, connectionID: connectionID) else {
            return
        }

        if let snapshot = resolution.snapshot {
            guard let userItemID else { throw AppModelError.missingCommittedItemID }
            capturedApplicationName = snapshot.applicationName
            lastSnapshotWindowContext = snapshot.windowContext
            try await realtimeClient.send(
                ConversationImageEvent(
                    jpegData: snapshot.jpegData,
                    applicationName: snapshot.applicationName,
                    windowTitle: snapshot.windowTitle,
                    previousItemID: userItemID
                ),
                connectionID: connectionID
            )
            guard isCurrentTurn(turn, generation: generation, connectionID: connectionID) else {
                return
            }
        }
        try await requestResponse(
            for: turn,
            generation: generation,
            connectionID: connectionID
        )
    }

    private func sendToolFailure(
        item: RealtimeItem,
        code: String,
        message: String,
        turn: Int,
        generation: Int,
        connectionID: RealtimeConnectionID
    ) async throws {
        guard let callID = item.callID else { throw ScreenToolCallError.missingCallID }
        let output = try encodeToolOutput(
            ToolFailureOutput(
                ok: false,
                error: ToolFailure(code: code, message: message)
            )
        )
        guard isCurrentTurn(turn, generation: generation, connectionID: connectionID) else {
            return
        }
        try await realtimeClient.send(
            FunctionCallOutputEvent(
                callID: callID,
                output: output,
                previousItemID: item.id
            ),
            connectionID: connectionID
        )
        guard isCurrentTurn(turn, generation: generation, connectionID: connectionID) else {
            return
        }
        try await requestResponse(
            for: turn,
            generation: generation,
            connectionID: connectionID
        )
    }

    func sendTurnCancelledOutput(
        for item: RealtimeItem,
        connectionID: RealtimeConnectionID
    ) async throws {
        guard
            let callID = item.callID,
            realtimeConnectionID == connectionID
        else { return }
        let output = try encodeToolOutput(
            ToolFailureOutput(
                ok: false,
                error: ToolFailure(
                    code: "turn_cancelled",
                    message: "The spoken turn was superseded or paused."
                )
            )
        )
        try await realtimeClient.send(
            FunctionCallOutputEvent(
                callID: callID,
                output: output,
                previousItemID: item.id
            ),
            connectionID: connectionID
        )
    }

    func encodeToolOutput<T: Encodable>(_ output: T) throws -> String {
        let data = try JSONEncoder().encode(output)
        guard let json = String(data: data, encoding: .utf8) else {
            throw ScreenToolCallError.outputEncodingFailed
        }
        return json
    }
}
