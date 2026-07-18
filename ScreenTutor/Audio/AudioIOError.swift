import Foundation

enum AudioIOError: LocalizedError, Sendable {
    case microphonePermissionDenied
    case alreadyRunning
    case noInputDevice
    case invalidInputFormat
    case voiceProcessingUnavailable(String)
    case converterCreationFailed
    case conversionFailed(String)
    case inputBackpressure
    case malformedOutputPCM
    case engineStartFailed(String)
    case deviceConfigurationChanged

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            "Microphone permission is required for a voice conversation."
        case .alreadyRunning:
            "The audio engine is already running."
        case .noInputDevice:
            "No microphone is available."
        case .invalidInputFormat:
            "The selected microphone has an unsupported audio format."
        case .voiceProcessingUnavailable(let message):
            "Echo cancellation could not start: \(message)"
        case .converterCreationFailed:
            "The microphone audio converter could not be created."
        case .conversionFailed(let message):
            "Microphone audio conversion failed: \(message)"
        case .inputBackpressure:
            "The network could not keep up with microphone audio."
        case .malformedOutputPCM:
            "The tutor returned malformed PCM audio."
        case .engineStartFailed(let message):
            "The audio engine could not start: \(message)"
        case .deviceConfigurationChanged:
            "The audio device changed. Reconnect the conversation."
        }
    }
}
