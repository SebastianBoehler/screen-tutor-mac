import Foundation

extension RealtimeFunctionTool {
    static let inspectApp = RealtimeFunctionTool(
        type: "function", name: "inspect_app",
        description: "Read the frontmost app's native controls, visible text and selection through macOS Accessibility. "
            + "Use first for native navigation or questions about accessible app content. Returns opaque control IDs and supported actions; no screenshot or vision model call.",
        parameters: .empty
    )

    static let activateControl = RealtimeFunctionTool(
        type: "function", name: "activate_control",
        description: "Perform an action supported by a control from the latest inspect_app. Prefer this to coordinate clicks. "
            + "Requires computer control enabled and the learner's request or agreement. Returns freshly inspected app state; all old IDs expire. "
            + "An action being dispatched does not prove the learner's goal was achieved.",
        parameters: Parameters(type: "object", properties: [
            "control_id": .string("Exact opaque ID from the latest native app state."),
            "action": .string("An action listed by this control.", enumValues: NativeControlAction.allCases.map(\.rawValue))
        ], required: ["control_id", "action"], additionalProperties: false)
    )

    static let highlightControl = RealtimeFunctionTool(
        type: "function", name: "highlight_control",
        description: "Attach one teaching mark to a native control from inspect_app. Draws immediately and follows the control as it moves or scrolls. "
            + "No screenshot or model call. Choose hint for a learning cue, navigation only to identify an app control. Hints are withheld during unaided checks.",
        parameters: Parameters(type: "object", properties: [
            "control_id": .string("Exact opaque ID from the latest native app state."),
            "purpose": .string("Why this mark is needed.", enumValues: ["hint", "navigation"]),
            "kind": .string("Mark style; default box.", enumValues: OverlayMarkKind.allCases.map(\.rawValue)),
            "label": .string("Optional short cue, at most eight words. Never reveal the exercise answer."),
            "seconds": Property(type: "number", description: "Visible duration, default 14 seconds.", minimum: 4, maximum: 60)
        ], required: ["control_id", "purpose"], additionalProperties: false)
    )

    static let setLearningGoal = RealtimeFunctionTool(
        type: "function", name: "set_learning_goal",
        description: "Set the learner's stated goal for this conversation, tied to a topic and subskill from start_topic. "
            + "Returns the next teaching move derived from recorded evidence and the active task. Keep cues and native actions relevant to this goal.",
        parameters: Parameters(type: "object", properties: [
            "objective": .string("The concrete outcome the learner wants to understand or perform independently."),
            "topic": .string("Exact topic name from start_topic."),
            "subskill": .string("Exact subskill name from that topic.")
        ], required: ["objective", "topic", "subskill"], additionalProperties: false)
    )
}
