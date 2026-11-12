import Foundation

struct RealtimeFunctionTool: Encodable, Sendable {
    let type: String
    let name: String
    let description: String
    let parameters: Parameters

    static let all: [RealtimeFunctionTool] = [
        .lookAtDesk, .getDeskNotes, .assignTask, .finishTask, .showVisual,
        .listWindows, .captureWindow, .pointAtScreenPosition,
        .openURL, .searchYouTube, .openApplication, .createDocument
    ]

    static let listWindows = RealtimeFunctionTool(
        type: "function",
        name: "list_windows",
        description: "List visible windows that are currently available for one-shot capture.",
        parameters: Parameters(
            type: "object",
            properties: [:],
            required: [],
            additionalProperties: false
        )
    )

    static let captureWindow = RealtimeFunctionTool(
        type: "function",
        name: "capture_window",
        description: "Capture one window returned by list_windows before discussing its contents.",
        parameters: Parameters(
            type: "object",
            properties: [
                "window_id": Property(
                    type: "string",
                    description: "Opaque window ID returned by the latest list_windows call.",
                    minimum: nil,
                    maximum: nil
                )
            ],
            required: ["window_id"],
            additionalProperties: false
        )
    )

    static let pointAtScreenPosition = RealtimeFunctionTool(
        type: "function",
        name: "point_at_screen_position",
        description: "Move ScreenTutor's compact teaching cursor to one precise point. Always use this after capture_window when the user explicitly asks to point, show where, direct them, or highlight something.",
        parameters: Parameters(
            type: "object",
            properties: [
                "x": Property(
                    type: "number",
                    description: "Horizontal target, normalized from 0 to 1 in the screenshot.",
                    minimum: 0,
                    maximum: 1
                ),
                "y": Property(
                    type: "number",
                    description: "Vertical target from the top, normalized from 0 to 1 in the screenshot.",
                    minimum: 0,
                    maximum: 1
                ),
                "label": Property(
                    type: "string",
                    description: "A short label of at most four words.",
                    minimum: nil,
                    maximum: nil
                )
            ],
            required: ["x", "y", "label"],
            additionalProperties: false
        )
    )

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
                "expected_evidence": .string("What finished work on the paper must show, for the observer.")
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
        description: "Show a visual on the floating Tutor Board: Markdown with LaTeX math ($...$ or $$...$$), tables, and ```mermaid diagrams. Use for formulas, derivations, diagrams and comparisons that are hard to say aloud.",
        parameters: Parameters(
            type: "object",
            properties: [
                "title": .string("Short board title."),
                "markdown": .string("Board content in Markdown. Keep it focused on one idea.")
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

    static let searchYouTube = RealtimeFunctionTool(
        type: "function",
        name: "search_youtube",
        description: "Open YouTube search results for a query in the browser, for example a short explainer video on a concept. Use when the learner asks for a video or agrees to one.",
        parameters: Parameters(
            type: "object",
            properties: ["query": .string("Precise search query, e.g. '3blue1brown eigenvectors'.")],
            required: ["query"],
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

    struct Parameters: Encodable, Sendable {
        static let empty = Parameters(
            type: "object",
            properties: [:],
            required: [],
            additionalProperties: false
        )

        let type: String
        let properties: [String: Property]
        let required: [String]
        let additionalProperties: Bool

        enum CodingKeys: String, CodingKey {
            case type, properties, required
            case additionalProperties = "additionalProperties"
        }
    }

    struct Property: Encodable, Sendable {
        let type: String
        let description: String
        let minimum: Double?
        let maximum: Double?
        var enumValues: [String]? = nil

        enum CodingKeys: String, CodingKey {
            case type, description, minimum, maximum
            case enumValues = "enum"
        }

        static func string(_ description: String, enumValues: [String]? = nil) -> Property {
            Property(
                type: "string",
                description: description,
                minimum: nil,
                maximum: nil,
                enumValues: enumValues
            )
        }
    }
}
