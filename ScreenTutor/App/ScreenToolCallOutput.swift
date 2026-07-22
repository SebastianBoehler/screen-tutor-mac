import Foundation

struct TeachingPointerSuccessOutput: Encodable {
    let ok: Bool
    let status: String
}

struct ToolFailureOutput: Encodable {
    let ok: Bool
    let error: ToolFailure
}

struct ToolFailure: Encodable {
    let code: String
    let message: String
}

enum ScreenToolCallError: LocalizedError {
    case missingCallID
    case outputEncodingFailed

    var errorDescription: String? {
        switch self {
        case .missingCallID: "The Realtime screen tool call was missing its call ID."
        case .outputEncodingFailed: "The screen tool result could not be encoded."
        }
    }
}
