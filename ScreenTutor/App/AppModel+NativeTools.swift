import Foundation

extension AppModel {
    static let nativeToolNames: Set<String> = ["inspect_app", "activate_control", "highlight_control", "set_learning_goal"]

    var tutorSupportContext: TutorSupportContext {
        let skill = learningGoal.flatMap { goal in
            learner.state.topics.first { $0.id == LearnerRules.slug(goal.topic) }?
                .subskills.first { $0.id == LearnerRules.slug(goal.subskill) }
        }
        return .make(goal: learningGoal, skill: skill,
                     taskKind: workspace.mode == .exam ? .exitTicket : deskObserver.activeTask?.taskKind)
    }

    func handleNativeToolCall(
        _ item: RealtimeItem, userItemID: String?, turn: Int, generation: Int, connectionID: RealtimeConnectionID
    ) async throws -> Bool {
        guard let name = item.name, Self.nativeToolNames.contains(name) else { return false }
        let result = executeNativeTool(name, arguments: ToolArguments(json: item.arguments))
        try await completeDeskToolCall(item, result: result, image: nil, userItemID: userItemID,
                                      turn: turn, generation: generation, connectionID: connectionID)
        return true
    }

    func executeNativeTool(_ name: String, arguments: ToolArguments) -> ToolResult {
        do {
            var fields: [String: String]
            switch name {
            case "inspect_app":
                overlay.clear()
                fields = ["app_state": try nativeApps.inspect().json()]
            case "activate_control":
                guard settings.computerControlEnabled else { throw InputControlError.disabled }
                guard let action = arguments.optionalString("action").flatMap(NativeControlAction.init(rawValue:)) else {
                    throw NativeAppError.unsupportedAction
                }
                overlay.clear()
                let state = try nativeApps.activate(controlID: arguments.string("control_id"), action: action)
                fields = ["status": "action_dispatched", "app_state": try state.json(),
                          "verification": "Read the updated state before claiming the intended result. Old control IDs are invalid."]
            case "highlight_control":
                fields = try highlightNativeControl(arguments)
            case "set_learning_goal":
                let goal = LearningGoal(objective: try arguments.string("objective"), topic: try arguments.string("topic"),
                                        subskill: try arguments.string("subskill"))
                guard let topic = learner.state.topics.first(where: { $0.id == LearnerRules.slug(goal.topic) }),
                      topic.subskills.contains(where: { $0.id == LearnerRules.slug(goal.subskill) })
                else { throw NativeAppError.unavailable("Call start_topic with this topic and subskill before setting the learning goal.") }
                try workspace.setLearningGoal(goal)
                learningGoal = goal
                overlay.clear()
                fields = ["status": "goal_set"]
            default:
                throw NativeAppError.unavailable("Unknown native tool: \(name).")
            }
            fields["learning_context"] = try tutorSupportContext.json()
            return .ok(fields)
        } catch {
            return .failure(code: "\(name)_failed", message: error.localizedDescription)
        }
    }

    func requireTeachingHintsAllowed() throws {
        guard tutorSupportContext.allowsHints else {
            throw NativeAppError.unavailable("This is an unaided check. If the learner asks for help, close the check as assisted before showing teaching cues.")
        }
    }

    private func highlightNativeControl(_ arguments: ToolArguments) throws -> [String: String] {
        let purpose = try arguments.string("purpose")
        guard ["hint", "navigation"].contains(purpose) else { throw DeskToolError.missingArgument("purpose") }
        if purpose == "hint" { try requireTeachingHintsAllowed() }
        let id = try arguments.string("control_id")
        let anchor = try nativeApps.anchor(controlID: id)
        let control = try nativeApps.currentControl(id: id)
        if purpose == "navigation", control.actions.isEmpty { throw NativeAppError.unsupportedAction }
        let kindName = arguments.optionalString("kind") ?? "box"
        guard let kind = OverlayMarkKind(rawValue: kindName) else { throw DeskToolError.missingArgument("kind") }
        let seconds = arguments.number("seconds") ?? 14
        guard seconds.isFinite else { throw DeskToolError.missingArgument("seconds") }
        let label = arguments.optionalString("label").map { String($0.split(whereSeparator: \.isWhitespace).prefix(8).joined(separator: " ").prefix(80)) }
        if kind == .note, label?.isEmpty != false { throw DeskToolError.missingArgument("label") }
        overlay.show(OverlayScene(marks: [OverlayMark(kind: kind, rect: control.frame, label: label, anchor: anchor)],
                                  duration: min(max(seconds, 4), 60)))
        return ["status": "drawn", "tracking": "native_control", "target": control.label,
                "note": "The mark follows this control locally and hides when the target is not visible."]
    }
}
