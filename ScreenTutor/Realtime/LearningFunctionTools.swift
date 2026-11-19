import Foundation

extension RealtimeFunctionTool {
    static let startTopic = RealtimeFunctionTool(
        type: "function",
        name: "start_topic",
        description: "Open or extend a topic in the learner model: 4–8 concrete subskills it breaks into. Returns the current skill map. For new subskills, run a short diagnostic next.",
        parameters: Parameters(
            type: "object",
            properties: [
                "topic": .string("Topic name, e.g. 'Gradient descent'."),
                "subskills": Property(
                    type: "array",
                    description: "Concrete subskills, ordered from prerequisite to advanced.",
                    minimum: nil,
                    maximum: nil,
                    items: .init(type: "string")
                )
            ],
            required: ["topic", "subskills"],
            additionalProperties: false
        )
    )

    static let recordEvidence = RealtimeFunctionTool(
        type: "function",
        name: "record_evidence",
        description: "Record what one check showed about one subskill. ScreenTutor computes levels and review dates; never state a level yourself.",
        parameters: Parameters(
            type: "object",
            properties: [
                "topic": .string("Topic name from start_topic."),
                "subskill": .string("Subskill name."),
                "kind": .string(
                    "diagnostic (placement question), prompted (correct with a hint or right after you explained), unprompted (correct from memory, no help), teach_back (explained it clearly or handled an edge case), incorrect, assisted (needed a worked step or asked to be told).",
                    enumValues: EvidenceKind.allCases.map(\.rawValue)
                ),
                "placed_level": Property(type: "number", description: "diagnostic only: 0 unaware, 1 heard of it, 2 can follow along, 3 can do with help.", minimum: 0, maximum: 3),
                "note": .string("Short evidence, e.g. 'derived the update rule from memory'.")
            ],
            required: ["topic", "subskill", "kind"],
            additionalProperties: false
        )
    )

    static let showProgress = RealtimeFunctionTool(
        type: "function",
        name: "show_progress",
        description: "Show the skill map and this session's scoreboards (with help vs without help) on the Tutor Board.",
        parameters: Parameters(
            type: "object",
            properties: ["topic": .string("Optional topic; default the most recent ones.")],
            required: [],
            additionalProperties: false
        )
    )

    static let reviewDue = RealtimeFunctionTool(
        type: "function",
        name: "review_due",
        description: "List subskills due for spaced review, interleaved across topics, for a warm-up.",
        parameters: .empty
    )
}
