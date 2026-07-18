import Foundation

enum TeachingPointerPresentationError: LocalizedError {
    case targetOutsideConnectedDisplays
    case panelPresentationFailed

    var errorDescription: String? {
        switch self {
        case .targetOutsideConnectedDisplays:
            "The teaching pointer target is not on a connected display."
        case .panelPresentationFailed:
            "The teaching pointer overlay could not be presented."
        }
    }
}
