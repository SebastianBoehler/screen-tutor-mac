import Foundation

struct RealtimeFunctionTool: Encodable, Sendable {
    let type: String
    let name: String
    let description: String
    let parameters: Parameters

    static let highlightScreenRegion = RealtimeFunctionTool(
        type: "function",
        name: "highlight_screen_region",
        description: "Highlight one visible region when pointing will materially improve the explanation.",
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
