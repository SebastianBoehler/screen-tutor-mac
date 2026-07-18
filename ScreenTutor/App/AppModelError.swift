import Foundation

enum AppModelError: LocalizedError {
    case missingAPIKey
    case screenPermissionRequiresRestart
    case noExternalApplication
    case missingSnapshot
    case responseFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "Add an OpenAI API key in Settings first."
        case .screenPermissionRequiresRestart:
            "Screen Recording access changed. Restart ScreenTutor, then try again."
        case .noExternalApplication:
            "Open the notebook or document you want ScreenTutor to see."
        case .missingSnapshot:
            "The active-window snapshot was not ready for this voice turn."
        case .responseFailed(let status):
            "The Realtime response ended with status: \(status)."
        }
    }
}
