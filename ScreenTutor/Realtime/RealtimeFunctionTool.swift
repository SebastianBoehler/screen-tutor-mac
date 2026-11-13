import Foundation

struct RealtimeFunctionTool: Encodable, Sendable {
    let type: String
    let name: String
    let description: String
    let parameters: Parameters

    static let all: [RealtimeFunctionTool] = [
        .lookAtDesk, .getDeskNotes, .assignTask, .finishTask, .showVisual,
        .startTopic, .recordEvidence, .showProgress, .reviewDue,
        .listWindows, .captureWindow, .pointAtScreenPosition,
        .annotateScreen, .clearAnnotations, .findVideos, .playVideo, .controlVideo,
        .openURL, .openApplication, .createDocument,
        .clickInWindow, .typeText, .pressKeys, .scrollWindow, .doOnComputer, .stopComputerTask
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

    static let annotateScreen = RealtimeFunctionTool(
        type: "function",
        name: "annotate_screen",
        description: "Draw teaching marks over the learner's screen: box, circle, underline, arrow, spotlight, or a short note next to something visible. Describe in words what to mark; a fast vision agent finds it on screen and draws in about a second.",
        parameters: Parameters(
            type: "object",
            properties: [
                "instruction": .string("What to mark and how, in order, e.g. 'circle the η in the update rule and label it learning rate'."),
                "seconds": Property(type: "number", description: "How long the marks stay (default 14).", minimum: 4, maximum: 60)
            ],
            required: ["instruction"],
            additionalProperties: false
        )
    )

    static let clearAnnotations = RealtimeFunctionTool(
        type: "function",
        name: "clear_annotations",
        description: "Remove all marks from the learner's screen.",
        parameters: .empty
    )

    static let findVideos = RealtimeFunctionTool(
        type: "function",
        name: "find_videos",
        description: "Search YouTube and return the top results (id, title, channel, length) without opening anything.",
        parameters: Parameters(
            type: "object",
            properties: ["query": .string("Precise search query, e.g. '3blue1brown eigenvectors'.")],
            required: ["query"],
            additionalProperties: false
        )
    )

    static let playVideo = RealtimeFunctionTool(
        type: "function",
        name: "play_video",
        description: "Open a YouTube video in ScreenTutor's lesson player and start playing. Returns its chapters.",
        parameters: Parameters(
            type: "object",
            properties: [
                "video_id": .string("The 11-character id from find_videos."),
                "start_seconds": Property(type: "number", description: "Where to start, e.g. a chapter start.", minimum: 0, maximum: nil),
                "pause_at_seconds": Property(
                    type: "array",
                    description: "Times where the player pauses itself for a recall question. Default: chapter ends.",
                    minimum: nil,
                    maximum: nil,
                    items: .init(type: "number")
                ),
                "auto_pause": Property(type: "boolean", description: "Pause at chapter ends when no times are given (default true).", minimum: nil, maximum: nil)
            ],
            required: ["video_id"],
            additionalProperties: false
        )
    )

    static let controlVideo = RealtimeFunctionTool(
        type: "function",
        name: "control_video",
        description: "Control the lesson player: play, pause, seek to a time, jump back or forward, change speed, loop a section, or report where it is.",
        parameters: Parameters(
            type: "object",
            properties: [
                "action": .string(
                    "What to do.",
                    enumValues: ["play", "pause", "seek", "back", "forward", "speed", "loop", "clear_loop", "status", "close"]
                ),
                "seconds": Property(type: "number", description: "seek: target time; back/forward: amount (default 10); loop: start.", minimum: 0, maximum: nil),
                "end_seconds": Property(type: "number", description: "loop: end of the section.", minimum: 0, maximum: nil),
                "rate": Property(type: "number", description: "speed: 0.25 to 2.", minimum: 0.25, maximum: 2)
            ],
            required: ["action"],
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

    static let clickInWindow = RealtimeFunctionTool(
        type: "function",
        name: "click_in_window",
        description: "Click a point in the window most recently returned by capture_window, after the learner asked you to do something on their Mac. Capture again afterwards to verify.",
        parameters: Parameters(
            type: "object",
            properties: [
                "x": Property(type: "number", description: "Horizontal target, normalized 0 to 1 in the screenshot.", minimum: 0, maximum: 1),
                "y": Property(type: "number", description: "Vertical target from the top, normalized 0 to 1 in the screenshot.", minimum: 0, maximum: 1),
                "click": .string("single, double, or right.", enumValues: ["single", "double", "right"])
            ],
            required: ["x", "y", "click"],
            additionalProperties: false
        )
    )

    static let typeText = RealtimeFunctionTool(
        type: "function",
        name: "type_text",
        description: "Type text into the currently focused field of the frontmost app (click the field first). A newline presses Return.",
        parameters: Parameters(
            type: "object",
            properties: ["text": .string("Exact text to type.")],
            required: ["text"],
            additionalProperties: false
        )
    )

    static let pressKeys = RealtimeFunctionTool(
        type: "function",
        name: "press_keys",
        description: "Press a key or shortcut in the frontmost app, e.g. return, escape, tab, cmd+t, cmd+shift+z.",
        parameters: Parameters(
            type: "object",
            properties: ["keys": .string("Key combination joined with +.")],
            required: ["keys"],
            additionalProperties: false
        )
    )

    static let scrollWindow = RealtimeFunctionTool(
        type: "function",
        name: "scroll_window",
        description: "Scroll the window most recently returned by capture_window.",
        parameters: Parameters(
            type: "object",
            properties: [
                "direction": .string("up or down.", enumValues: ["up", "down"]),
                "amount": Property(type: "number", description: "Lines to scroll, 1 to 20.", minimum: 1, maximum: 20)
            ],
            required: ["direction", "amount"],
            additionalProperties: false
        )
    )

    static let doOnComputer = RealtimeFunctionTool(
        type: "function",
        name: "do_on_computer",
        description: "Hand a multi-step goal on the Mac to the background computer agent (for example 'open the linear algebra lecture PDF in Downloads and go to the page on eigenvalues', 'start a new Word document titled Week 3 notes'). Only after the learner asked or agreed. It runs while you keep talking and reports back with a <computer_agent> note.",
        parameters: Parameters(
            type: "object",
            properties: ["goal": .string("Concrete, self-contained goal including any names, titles, or URLs.")],
            required: ["goal"],
            additionalProperties: false
        )
    )

    static let stopComputerTask = RealtimeFunctionTool(
        type: "function",
        name: "stop_computer_task",
        description: "Stop the background computer agent immediately, e.g. when the learner says stop.",
        parameters: .empty
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
        var items: Items? = nil

        struct Items: Encodable, Sendable {
            let type: String
        }

        enum CodingKeys: String, CodingKey {
            case type, description, minimum, maximum, items
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
