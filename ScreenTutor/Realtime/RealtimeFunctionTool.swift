import Foundation

struct RealtimeFunctionTool: Encodable, Sendable {
    let type: String
    let name: String
    let description: String
    let parameters: Parameters

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

    static let highlightScreenRegion = RealtimeFunctionTool(
        type: "function",
        name: "highlight_screen_region",
        description: "Move ScreenTutor's visible teaching cursor to one region and highlight it. Always use this after capture_window when the user explicitly asks to point, show where, direct them, or highlight something.",
        parameters: Parameters(
            type: "object",
            properties: [
                "x": Property(
                    type: "number",
                    description: "Left edge, normalized from 0 to 1 in the screenshot.",
                    minimum: 0,
                    maximum: 1
                ),
                "y": Property(
                    type: "number",
                    description: "Top edge, normalized from 0 to 1 in the screenshot.",
                    minimum: 0,
                    maximum: 1
                ),
                "width": Property(
                    type: "number",
                    description: "Region width, normalized from 0 to 1.",
                    minimum: 0.01,
                    maximum: 1
                ),
                "height": Property(
                    type: "number",
                    description: "Region height, normalized from 0 to 1.",
                    minimum: 0.01,
                    maximum: 1
                ),
                "label": Property(
                    type: "string",
                    description: "A short label of at most four words.",
                    minimum: nil,
                    maximum: nil
                )
            ],
            required: ["x", "y", "width", "height", "label"],
            additionalProperties: false
        )
    )

    struct Parameters: Encodable, Sendable {
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
    }
}
