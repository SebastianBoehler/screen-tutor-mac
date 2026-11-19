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
        .inspectApp, .activateControl, .highlightControl, .setLearningGoal,
        .searchCourseMaterials, .presentFlashcard, .organizeWorkspace, .recordLearningInsight,
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
        description: "Move ScreenTutor's compact teaching cursor to one precise screenshot point after capture_window. For a native element from inspect_app, prefer highlight_control so the mark follows it.",
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
