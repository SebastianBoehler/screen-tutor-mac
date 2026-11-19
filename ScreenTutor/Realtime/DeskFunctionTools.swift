import Foundation

extension RealtimeFunctionTool {
    static let lookAtDesk = RealtimeFunctionTool(
        type: "function",
        name: "look_at_desk",
        description: "Look at the current overhead desk camera frame (paper, notebook, book) before discussing handwritten or physical work. Returns the newest frame plus the desk observer's latest notes.",
        parameters: .empty
    )

    static let getDeskNotes = RealtimeFunctionTool(
        type: "function",
        name: "get_desk_notes",
        description: "Read the desk observer's recent text notes (transcribed work, progress, possible issues) without sending a new image. Cheap; use for quick context.",
        parameters: .empty
    )

    static let assignTask = RealtimeFunctionTool(
        type: "function",
        name: "assign_task",
        description: "Give the learner one concrete task to do on paper. It is pinned on the Tutor Board and the desk observer watches the paper against it. Replaces any active task.",
        parameters: Parameters(
            type: "object",
            properties: [
                "title": .string("Short task title, at most six words."),
                "task": .string("The exact task in Markdown with LaTeX math, as the learner should see it."),
                "expected_evidence": .string("What finished work on the paper must show, for the observer."),
                "kind": .string(
                    "practice (help allowed, default), warm_up (spaced review from memory, no help) or exit_ticket (unseen problem at the end of a block, no help).",
                    enumValues: TaskKind.allCases.map(\.rawValue)
                ),
                "topic": .string("Learner-model topic this task checks, if any."),
                "subskill": .string("Learner-model subskill this task checks, if any.")
            ],
            required: ["title", "task", "expected_evidence"],
            additionalProperties: false
        )
    )

    static let finishTask = RealtimeFunctionTool(
        type: "function",
        name: "finish_task",
        description: "Close the active desk task after you checked the learner's work.",
        parameters: Parameters(
            type: "object",
            properties: [
                "outcome": .string(
                    "independent, assisted, or abandoned. Use independent only if the learner solved it without worked steps from you.",
                    enumValues: ["independent", "assisted", "abandoned"]
                ),
                "note": .string("One sentence on what was secure or still missing.")
            ],
            required: ["outcome", "note"],
            additionalProperties: false
        )
    )

    static let showVisual = RealtimeFunctionTool(
        type: "function",
        name: "show_visual",
        description: "Create or update one rich learning artifact inline and on the canvas. Explain one concept or mechanism per artifact. Markdown supports LaTeX math, Mermaid diagrams, tables, code and sanitized SVG. Keep it short; use a stable artifact_id to update it in place.",
        parameters: Parameters(
            type: "object",
            properties: [
                "title": .string("Short board title."),
                "markdown": .string("One clear concept with a visual or short explanation, not a lecture dump. Cite exact course source links when grounded in imported material."),
                "artifact_id": .string("Stable id; reuse it when refining an existing artifact."),
                "section": .string("Canvas section, e.g. First principles, Your turn, or Review.")
            ],
            required: ["title", "markdown"],
            additionalProperties: false
        )
    )

    static let openURL = RealtimeFunctionTool(
        type: "function",
        name: "open_url",
        description: "Open an http or https URL in the learner's default browser. Use only when the learner asks or agrees.",
        parameters: Parameters(
            type: "object",
            properties: ["url": .string("Complete http or https URL.")],
            required: ["url"],
            additionalProperties: false
        )
    )

    static let openApplication = RealtimeFunctionTool(
        type: "function",
        name: "open_application",
        description: "Open an installed Mac application by name (e.g. Calculator, Word, Preview, Notes).",
        parameters: Parameters(
            type: "object",
            properties: ["name": .string("Application name or bundle identifier.")],
            required: ["name"],
            additionalProperties: false
        )
    )

    static let createDocument = RealtimeFunctionTool(
        type: "function",
        name: "create_document",
        description: "Write a document (summary, study notes, exercise sheet, outline) into ~/Downloads/ScreenTutor and open it. Use when the learner asks you to write something down for them.",
        parameters: Parameters(
            type: "object",
            properties: [
                "title": .string("Document title, also used as file name."),
                "markdown": .string("Full document body in Markdown (headings, lists, bold, code). Write math as readable LaTeX."),
                "format": .string(
                    "docx for Word (default), md for Markdown, rtf for TextEdit/Pages.",
                    enumValues: ["docx", "md", "rtf"]
                )
            ],
            required: ["title", "markdown", "format"],
            additionalProperties: false
        )
    )
}
