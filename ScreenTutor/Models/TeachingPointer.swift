import Foundation

struct TeachingPointer: Sendable {
    let globalPoint: CGPoint
    let label: String

    init(argumentsJSON: String, windowFrame: CGRect) throws {
        guard let data = argumentsJSON.data(using: .utf8) else {
            throw TeachingPointerError.invalidArguments
        }
        let arguments = try JSONDecoder().decode(Arguments.self, from: data)
        guard
            arguments.x.isFinite,
            arguments.y.isFinite,
            (0...1).contains(arguments.x),
            (0...1).contains(arguments.y)
        else {
            throw TeachingPointerError.outOfBounds
        }
        let trimmedLabel = arguments.label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLabel.isEmpty, trimmedLabel.count <= 48 else {
            throw TeachingPointerError.invalidLabel
        }

        globalPoint = CGPoint(
            x: windowFrame.minX + arguments.x * windowFrame.width,
            y: windowFrame.maxY - arguments.y * windowFrame.height
        )
        label = trimmedLabel
    }

    private struct Arguments: Decodable {
        let x: Double
        let y: Double
        let label: String
    }
}

enum TeachingPointerError: LocalizedError {
    case invalidArguments
    case outOfBounds
    case invalidLabel
    case noWindowContext

    var errorDescription: String? {
        switch self {
        case .invalidArguments: "The tutor returned invalid pointer coordinates."
        case .outOfBounds: "The tutor pointed outside the captured window."
        case .invalidLabel: "The tutor returned an invalid pointer label."
        case .noWindowContext: "There is no captured window available to point at."
        }
    }
}
