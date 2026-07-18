import Foundation

enum SessionPhase: Equatable, Sendable {
    case idle
    case requestingPermissions
    case connecting
    case listening
    case thinking
    case speaking
    case pausing
    case paused
    case resuming
    case stopping

    var title: String {
        switch self {
        case .idle: "Ready"
        case .requestingPermissions: "Requesting access"
        case .connecting: "Connecting"
        case .listening: "Listening"
        case .thinking: "Thinking"
        case .speaking: "Speaking"
        case .pausing: "Pausing"
        case .paused: "Paused"
        case .resuming: "Resuming"
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
        case .pausing: "pause.circle"
        case .paused: "pause.circle.fill"
        case .resuming: "play.circle"
        case .stopping: "stop.circle"
        }
    }

    var primaryActionLabel: String {
        switch self {
        case .idle: "Start conversation"
        case .paused: "Resume listening"
        case .listening, .thinking, .speaking: "Pause listening"
        case .requestingPermissions: "Requesting access"
        case .connecting: "Connecting"
        case .pausing: "Pausing"
        case .resuming: "Resuming"
        case .stopping: "Stopping"
        }
    }

    var primaryActionSymbolName: String {
        switch self {
        case .idle: "mic.fill"
        case .paused: "play.fill"
        case .listening, .thinking, .speaking: "pause.fill"
        case .requestingPermissions, .connecting, .pausing, .resuming, .stopping: symbolName
        }
    }

    var isPrimaryActionEnabled: Bool {
        switch self {
        case .idle, .listening, .thinking, .speaking, .paused: true
        case .requestingPermissions, .connecting, .pausing, .resuming, .stopping: false
        }
    }

    var hasConversation: Bool {
        switch self {
        case .listening, .thinking, .speaking, .paused: true
        case .idle, .requestingPermissions, .connecting, .pausing, .resuming, .stopping: false
        }
    }

    var needsTeardown: Bool {
        self != .idle
    }

    var isStopActionEnabled: Bool {
        self != .idle && self != .stopping
    }

    var isActive: Bool {
        self != .idle && self != .stopping
    }
}
