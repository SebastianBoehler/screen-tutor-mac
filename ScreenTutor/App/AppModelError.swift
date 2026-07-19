import Foundation

enum AppModelError: LocalizedError {
    case missingAPIKey
    case microphonePermissionDenied
    case screenPermissionRequiresRestart
    case missingCommittedItemID
    case responseFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "Add an OpenAI API key in Settings first."
        case .microphonePermissionDenied:
            "Microphone permission is required for a voice conversation."
        case .screenPermissionRequiresRestart:
            "Screen Recording access changed. Restart ScreenTutor, then try again."
        case .missingCommittedItemID:
            "The Realtime server did not identify the committed voice turn."
        case .responseFailed(let status):
            "The Realtime response ended with status: \(status)."
        }
    }
}
