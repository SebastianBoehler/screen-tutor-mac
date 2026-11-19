import Foundation

/// Desk camera, Tutor Board, and Mac action tools, plus proactive desk-observer
/// interjections into the voice conversation.
extension AppModel {
    static let deskToolNames: Set<String> = [
        "look_at_desk", "get_desk_notes", "assign_task", "finish_task", "show_visual",
        "open_url", "open_application", "create_document"
    ]

    /// Handles a desk or action tool. Returns false when the tool belongs elsewhere.
    func handleDeskToolCall(
        _ item: RealtimeItem,
        userItemID: String?,
        turn: Int,
        generation: Int,
        connectionID: RealtimeConnectionID
    ) async throws -> Bool {
        guard let name = item.name, Self.deskToolNames.contains(name) else { return false }
        let arguments = ToolArguments(json: item.arguments)
        var image: (data: Data, description: String)?
        let result: ToolResult

        do {
            switch name {
            case "look_at_desk":
                let snapshot = try await deskCamera.currentSnapshot()
                image = (snapshot.jpegData, "Current overhead desk frame from \(snapshot.deviceName).")
                let notes = deskObserver.latest?.tutorNote ?? "No observer notes yet."
                result = .ok(["device": snapshot.deviceName, "observer_notes": notes])
            case "get_desk_notes":
                result = .ok([
                    "camera": deskCamera.isRunning ? "running" : "off",
                    "notes": deskObserver.recentNotes()
                ])
            case "assign_task":
                let kind = arguments.optionalString("kind").flatMap(TaskKind.init(rawValue:)) ?? .practice
                overlay.clear()
                let task = deskObserver.assignTask(
                    title: try arguments.string("title"),
                    prompt: try arguments.string("task"),
                    expectedEvidence: try arguments.string("expected_evidence"),
                    kind: kind,
                    topic: arguments.optionalString("topic"),
                    subskill: arguments.optionalString("subskill")
                )
                if !deskObserver.isWatching, settings.observerEnabled {
                    await deskObserver.startWatching()
                }
                result = .ok([
                    "task_id": task.id.uuidString,
                    "kind": kind.rawValue,
                    "board": "pinned",
                    "observer": deskObserver.isWatching ? "watching the desk" : "camera not running",
                    "rule": kind.isUnaided
                        ? "No hints or cues until the learner says they are done; if they ask for help, help, then finish it as assisted."
                        : "Help with the least support that unlocks progress."
                ])
            case "finish_task":
                overlay.clear()
                let outcome = try arguments.string("outcome")
                if outcome == "assisted", workspace.mode == .exam { try workspace.setMode(.practice) }
                let note = arguments.optionalString("note") ?? ""
                var fields = ["status": "closed"]
                if let task = deskObserver.finishTask(outcome: outcome, note: note) {
                    try workspace.presentArtifact(id: "task-\(task.id.uuidString)", title: task.title,
                        markdown: task.prompt + "\n\n**\(outcome.capitalized)** — \(note)", section: "Checked work")
                    let change = learner.recordTaskOutcome(
                        kind: task.taskKind, outcome: outcome, topic: task.topic, subskill: task.subskill, note: note
                    )
                    if let change {
                        fields["level"] = "\(change.subskill): \(change.from) → \(change.to)/5"
                    }
                    fields["scoreboard"] = LearnerReport.scoreboards(learner.currentSession)
                }
                result = .ok(fields)
            case "show_visual":
                try requireTeachingHintsAllowed()
                let title = try arguments.string("title")
                let id = arguments.optionalString("artifact_id") ?? "visual-\(LearnerRules.slug(title))"
                try workspace.presentArtifact(id: id, title: title, markdown: arguments.string("markdown"),
                    section: arguments.optionalString("section") ?? "Concepts")
                result = .ok(["artifact_id": id, "status": "shown_inline_and_on_canvas"])
            case "open_url":
                let url = try desktopActions.openURL(try arguments.string("url"))
                result = .ok(["opened": url.absoluteString])
            case "open_application":
                let appName = try await desktopActions.openApplication(named: try arguments.string("name"))
                result = .ok(["opened": appName])
            case "create_document":
                let format = DocumentFormat(rawValue: arguments.optionalString("format") ?? "docx") ?? .word
                let url = try desktopActions.createDocument(
                    title: try arguments.string("title"),
                    markdown: try arguments.string("markdown"),
                    format: format
                )
                result = .ok(["saved": "~/Downloads/ScreenTutor/\(url.lastPathComponent)", "opened": "true"])
            default:
                return false
            }
        } catch {
            result = .failure(code: "\(name)_failed", message: error.localizedDescription)
        }

        try await completeDeskToolCall(
            item,
            result: result,
            image: image,
            userItemID: userItemID,
            turn: turn,
            generation: generation,
            connectionID: connectionID
        )
        return true
    }

    func completeDeskToolCall(
        _ item: RealtimeItem,
        result: ToolResult,
        image: (data: Data, description: String)?,
        userItemID: String?,
        turn: Int,
        generation: Int,
        connectionID: RealtimeConnectionID
    ) async throws {
        guard let callID = item.callID else { throw ScreenToolCallError.missingCallID }
        guard isCurrentTurn(turn, generation: generation, connectionID: connectionID) else {
            try await sendTurnCancelledOutput(for: item, connectionID: connectionID)
            return
        }
        recordToolActivity(name: item.name, status: result.succeeded ? .succeeded : .failed, turn: turn)
        phase = .thinking
        try await realtimeClient.send(
            FunctionCallOutputEvent(callID: callID, output: result.json, previousItemID: item.id),
            connectionID: connectionID
        )
        guard isCurrentTurn(turn, generation: generation, connectionID: connectionID) else { return }
        if let image {
            try await realtimeClient.send(
                DeskContextItemEvent(
                    text: image.description + " Use it for the current turn.",
                    jpegData: image.data,
                    previousItemID: userItemID
                ),
                connectionID: connectionID
            )
            guard isCurrentTurn(turn, generation: generation, connectionID: connectionID) else { return }
        }
        try await requestResponse(for: turn, generation: generation, connectionID: connectionID)
    }

    /// Lets the tutor speak first when the desk observer flags something worth
    /// interrupting for. Only fires while the conversation is idle and listening,
    /// so it never talks over the learner or an ongoing answer.
    func deliverDeskInterjection(_ observation: DeskObservation, jpeg: Data) async -> Bool {
        guard let interjection = observation.payload.interjection else { return false }
        // During a warm-up or exit ticket the tutor gives no help; only "looks finished" may speak.
        if deskObserver.activeTask?.taskKind.isUnaided == true, interjection.kind != .completed { return true }
        let text = """
            <desk_observer> Automated note, not spoken by the learner. \
            Reason to consider speaking: \(interjection.kind.rawValue) — \(interjection.reason). \
            Suggested move: \(interjection.suggestedMove).
            \(observation.tutorNote)
            The attached image is the current desk. Respond in one or two short spoken sentences \
            following the teaching policy (cue or question, not the answer), or stay brief if \
            interrupting would not help.
            """
        let delivered = await deliverAutomatedNote(text: text, jpeg: jpeg)
        if delivered { lastInjectedDeskObservationID = observation.id }
        return delivered
    }

    /// Starts a tutor-initiated turn from an automated note (desk observer or
    /// computer agent). Only fires while the conversation is idle and listening,
    /// so it never talks over the learner or an ongoing answer.
    func deliverAutomatedNote(text: String, jpeg: Data?) async -> Bool {
        guard
            let connectionID = realtimeConnectionID,
            phase == .listening,
            !userIsSpeaking,
            activeResponseID == nil,
            activeAudioResponseID == nil,
            screenToolTask == nil
        else { return false }

        let generation = sessionGeneration
        let turn = turnTracker.advance()
        liveToolActivities.removeAll()
        latestUserTranscript = ""
        assistantTranscript = ""
        clearTeachingPointer?()
        let itemID = DeskContextItemEvent.makeItemID()
        do {
            try await realtimeClient.send(
                DeskContextItemEvent(itemID: itemID, text: text, jpegData: jpeg),
                connectionID: connectionID
            )
            guard isCurrentTurn(turn, generation: generation, connectionID: connectionID) else {
                return false
            }
            currentUserItemID = itemID
            currentUserItemTurn = turn
            phase = .thinking
            idleTimer.cancel()
            try await requestResponse(for: turn, generation: generation, connectionID: connectionID)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Adds the observer's newest text note after a spoken turn so the tutor
    /// knows what is on the paper without an extra tool call or image.
    func attachDeskContext(after userItemID: String, connectionID: RealtimeConnectionID) async throws {
        guard
            deskObserver.isWatching,
            let observation = deskObserver.latest,
            observation.id != lastInjectedDeskObservationID,
            Date().timeIntervalSince(observation.capturedAt) < 600
        else { return }
        lastInjectedDeskObservationID = observation.id
        var text = "<desk_observer> Automated desk context, not spoken by the learner. "
            + "It may lag behind the paper; call look_at_desk to verify details.\n"
            + observation.tutorNote
        if let task = deskObserver.activeTask {
            text += "\nActive task: \(task.title)"
        }
        try await realtimeClient.send(
            DeskContextItemEvent(text: text, previousItemID: userItemID),
            connectionID: connectionID
        )
    }

    /// Short transcript context for the desk observer.
    func observerConversationContext() -> String {
        var lines: [String] = []
        if !latestUserTranscript.isEmpty { lines.append("Learner: \(latestUserTranscript.prefix(400))") }
        if !assistantTranscript.isEmpty { lines.append("Tutor: \(assistantTranscript.prefix(400))") }
        return lines.joined(separator: "\n")
    }
}

enum ToolResult {
    case ok([String: String])
    case failure(code: String, message: String)

    var succeeded: Bool {
        if case .ok = self { return true }
        return false
    }

    var json: String {
        var object: [String: Any]
        switch self {
        case .ok(let fields):
            object = fields
            object["ok"] = true
        case .failure(let code, let message):
            object = ["ok": false, "error": ["code": code, "message": message]]
        }
        guard
            let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
            let text = String(data: data, encoding: .utf8)
        else { return #"{"ok":false}"# }
        return text
    }
}

struct ToolArguments {
    let values: [String: Any]

    init(json: String?) {
        values = json
            .flatMap { $0.data(using: .utf8) }
            .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
    }

    func string(_ key: String) throws -> String {
        guard let value = optionalString(key), !value.isEmpty else {
            throw DeskToolError.missingArgument(key)
        }
        return value
    }

    func number(_ key: String) -> Double? {
        if let value = values[key] as? Double { return value }
        if let value = values[key] as? Int { return Double(value) }
        if let value = values[key] as? String { return Double(value) }
        return nil
    }

    func optionalString(_ key: String) -> String? {
        (values[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum DeskToolError: LocalizedError {
    case missingArgument(String)

    var errorDescription: String? {
        switch self {
        case .missingArgument(let key): "Missing required argument “\(key)”."
        }
    }
}
