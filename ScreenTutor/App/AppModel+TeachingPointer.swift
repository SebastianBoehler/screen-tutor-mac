import Foundation

extension AppModel {
    func handleTeachingPointerCall(
        _ item: RealtimeItem,
        turn: Int,
        generation: Int,
        connectionID: RealtimeConnectionID
    ) async throws {
        guard let callID = item.callID else { throw TeachingPointerError.invalidArguments }
        let output: String
        let status: ConversationToolStatus
        do {
            guard let arguments = item.arguments else {
                throw TeachingPointerError.invalidArguments
            }
            guard let lastSnapshotWindowContext else {
                throw TeachingPointerError.noWindowContext
            }
            let windowFrame = try await screenTools.resolveWindowFrame(
                for: lastSnapshotWindowContext
            )
            guard isCurrentTurn(turn, generation: generation, connectionID: connectionID) else {
                try await sendTurnCancelledOutput(for: item, connectionID: connectionID)
                return
            }
            let pointer = try TeachingPointer(
                argumentsJSON: arguments,
                windowFrame: windowFrame
            )
            guard let showTeachingPointer else {
                throw TeachingPointerPresentationError.panelPresentationFailed
            }
            try showTeachingPointer(pointer)
            output = try encodeToolOutput(
                TeachingPointerSuccessOutput(ok: true, status: "pointed")
            )
            status = .succeeded
        } catch {
            output = try encodeToolOutput(
                ToolFailureOutput(
                    ok: false,
                    error: ToolFailure(
                        code: pointerErrorCode(error),
                        message: error.localizedDescription
                    )
                )
            )
            status = .failed
        }

        guard isCurrentTurn(turn, generation: generation, connectionID: connectionID) else {
            try await sendTurnCancelledOutput(for: item, connectionID: connectionID)
            return
        }
        recordToolActivity(name: item.name, status: status, turn: turn)
        phase = .thinking
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

    private func pointerErrorCode(_ error: Error) -> String {
        if error is TeachingPointerPresentationError { return "pointer_presentation_failed" }
        if error is ScreenCaptureError { return "pointer_context_stale" }
        return "invalid_pointer"
    }
}
