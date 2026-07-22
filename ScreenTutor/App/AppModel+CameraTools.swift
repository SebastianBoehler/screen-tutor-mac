import Foundation

extension AppModel {
    func handleCameraCall(
        _ item: RealtimeItem,
        userItemID: String?,
        turn: Int,
        generation: Int,
        connectionID: RealtimeConnectionID
    ) async throws {
        guard let callID = item.callID else { throw ScreenToolCallError.missingCallID }
        let resolution = try await cameraTools.capture(callID: callID)
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
            try await realtimeClient.send(
                ConversationImageEvent(
                    jpegData: snapshot.jpegData,
                    contextDescription: "Current camera photo from \(snapshot.deviceName).",
                    eventIDPrefix: "camera",
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
}
