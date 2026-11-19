import Foundation

extension RealtimeFunctionTool {
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
}
