import Foundation

struct TeachingHighlight: Sendable {
    let globalFrame: CGRect
    let label: String

    init(argumentsJSON: String, windowFrame: CGRect) throws {
        guard let data = argumentsJSON.data(using: .utf8) else {
            throw TeachingHighlightError.invalidArguments
        }
        let arguments = try JSONDecoder().decode(Arguments.self, from: data)
        guard
            arguments.x.isFinite,
            arguments.y.isFinite,
            arguments.width.isFinite,
            arguments.height.isFinite,
            arguments.x >= 0,
            arguments.y >= 0,
            arguments.width > 0,
            arguments.height > 0,
            arguments.x + arguments.width <= 1,
            arguments.y + arguments.height <= 1
        else {
            throw TeachingHighlightError.outOfBounds
        }
        let trimmedLabel = arguments.label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLabel.isEmpty, trimmedLabel.count <= 48 else {
            throw TeachingHighlightError.invalidLabel
        }

        globalFrame = CGRect(
            x: windowFrame.minX + arguments.x * windowFrame.width,
            y: windowFrame.maxY - (arguments.y + arguments.height) * windowFrame.height,
            width: arguments.width * windowFrame.width,
            height: arguments.height * windowFrame.height
        )
        label = trimmedLabel
    }

    private struct Arguments: Decodable {
        let x: Double
        let y: Double
        let width: Double
        let height: Double
        let label: String
    }
}

enum TeachingHighlightError: LocalizedError {
    case invalidArguments
    case outOfBounds
    case invalidLabel
    case noWindowContext

    var errorDescription: String? {
        switch self {
        case .invalidArguments: "The tutor returned invalid highlight coordinates."
        case .outOfBounds: "The tutor returned a highlight outside the captured window."
        case .invalidLabel: "The tutor returned an invalid highlight label."
        case .noWindowContext: "There is no captured window available to highlight."
        }
    }
}
