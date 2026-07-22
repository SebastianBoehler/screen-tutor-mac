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

    static let captureCamera = RealtimeFunctionTool(
        type: "function",
        name: "capture_camera",
        description: "Take one photo from the Mac camera and add it to the current turn. Use only when the user explicitly asks you to look through or inspect the camera.",
        parameters: Parameters(
            type: "object",
            properties: [:],
            required: [],
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
