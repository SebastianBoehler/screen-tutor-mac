extension RealtimeFunctionTool {
    static let searchCourseMaterials = RealtimeFunctionTool(
        type: "function", name: "search_course_materials",
        description: "Search the selected course's locally imported materials. Returns relevant excerpts with exact material/page source links. "
            + "Use before explaining course-specific content or preparing practice/exams. No results means no supporting excerpt, not that the claim is false.",
        parameters: Parameters(type: "object", properties: ["query": .string("Precise topic, term or concept to look up.")],
                               required: ["query"], additionalProperties: false)
    )

    static let presentFlashcard = RealtimeFunctionTool(
        type: "function", name: "present_flashcard",
        description: "Create an inline retrieval-practice card for one concept. The answer stays hidden until the learner reveals it. "
            + "Self-ratings never establish mastery. Use the same id to revise a card; keep the question answerable from the course material.",
        parameters: Parameters(type: "object", properties: [
            "id": .string("Stable artifact id."), "title": .string("One concept."),
            "question": .string("One recall or application question, Markdown/math supported."),
            "answer": .string("A brief, source-grounded answer, shown only after reveal."),
            "section": .string("Workspace section, e.g. Retrieval practice.")
        ], required: ["id", "title", "question", "answer", "section"], additionalProperties: false)
    )

    static let organizeWorkspace = RealtimeFunctionTool(
        type: "function", name: "organize_workspace",
        description: "Move existing learning artifacts into a named section, in the given order. Leaves other artifacts intact. "
            + "Use to organize the learner's evolving understanding without replacing their notes.",
        parameters: Parameters(type: "object", properties: [
            "artifact_ids": Property(type: "array", description: "Existing artifact IDs in teaching order.", minimum: nil, maximum: nil, items: .init(type: "string")),
            "section": .string("A short descriptive section name.")
        ], required: ["artifact_ids", "section"], additionalProperties: false)
    )

    static let recordLearningInsight = RealtimeFunctionTool(
        type: "function", name: "record_learning_insight",
        description: "Remember an observed feature of the learner's reasoning for future teaching. Cite their actual explanation or response. "
            + "Record useful connections, misconceptions or successful approaches; never infer a fixed learning style or unsupported personal traits.",
        parameters: Parameters(type: "object", properties: [
            "observation": .string("What the learner's reasoning showed."),
            "evidence": .string("The learner's actual wording or the concrete observed response."),
            "teaching_implication": .string("How to adapt the next explanation; a hypothesis to check, not a permanent label.")
        ], required: ["observation", "evidence", "teaching_implication"], additionalProperties: false)
    )
}
