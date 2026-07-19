import Foundation

enum MicrophoneControlState: Equatable, Sendable {
    enum Tone: Equatable, Sendable {
        case accent
        case live
        case muted
        case unavailable
    }

    case ready
    case reconnect
    case live
    case muted
    case busy
    case unavailable

    init(phase: SessionPhase, isMuted: Bool, canReconnect: Bool) {
        switch phase {
        case .idle:
            self = canReconnect ? .reconnect : .ready
        case .listening, .thinking, .speaking:
            self = isMuted ? .muted : .live
        case .paused:
            self = .muted
        case .requestingPermissions, .connecting, .pausing, .resuming:
            self = .busy
        case .stopping:
            self = .unavailable
        }
    }

    var label: String {
        switch self {
        case .ready: "Start conversation"
        case .reconnect: "Reconnect microphone"
        case .live: "Mute ScreenTutor microphone"
        case .muted: "Unmute ScreenTutor microphone"
        case .busy: "Connecting microphone"
        case .unavailable: "Microphone unavailable"
        }
    }

    var symbolName: String {
        switch self {
        case .ready, .reconnect, .live: "mic.fill"
        case .muted: "mic.slash.fill"
        case .busy: "ellipsis.circle"
        case .unavailable: "mic.slash"
        }
    }

    var tone: Tone {
        switch self {
        case .ready, .reconnect: .accent
        case .live: .live
        case .muted: .muted
        case .busy, .unavailable: .unavailable
        }
    }

    var isEnabled: Bool {
        switch self {
        case .ready, .reconnect, .live, .muted: true
        case .busy, .unavailable: false
        }
    }

    var accessibilityHint: String {
        switch self {
        case .live:
            "Mutes only ScreenTutor. The conversation and other microphone apps stay active."
        case .muted:
            "Resumes microphone input for ScreenTutor without starting a new conversation."
        case .reconnect:
            "Reconnects and restores the saved conversation after a network interruption."
        case .ready:
            "Starts a new screen-aware voice conversation."
        case .busy, .unavailable:
            "The microphone control is temporarily unavailable."
        }
    }
}
