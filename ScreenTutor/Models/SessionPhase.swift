import Foundation

enum SessionPhase: Equatable, Sendable {
    case idle
    case requestingPermissions
    case connecting
    case listening
    case thinking
    case speaking
    case stopping

    var title: String {
        switch self {
        case .idle: "Ready"
        case .requestingPermissions: "Requesting access"
        case .connecting: "Connecting"
        case .listening: "Listening"
        case .thinking: "Looking and thinking"
        case .speaking: "Speaking"
        case .stopping: "Stopping"
        }
    }

    var symbolName: String {
        switch self {
        case .idle: "waveform.circle"
        case .requestingPermissions: "lock.shield"
        case .connecting: "ellipsis.circle"
        case .listening: "mic.fill"
        case .thinking: "eye.fill"
        case .speaking: "waveform"
        case .stopping: "stop.circle"
        }
    }

    var isActive: Bool {
        self != .idle && self != .stopping
    }
}
