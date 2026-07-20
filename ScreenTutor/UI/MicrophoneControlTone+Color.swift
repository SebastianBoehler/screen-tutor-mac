import SwiftUI

extension MicrophoneControlState.Tone {
    var color: Color {
        switch self {
        case .accent: .accentColor
        case .reconnecting: .blue
        case .live: .green
        case .muted: .orange
        case .unavailable: .secondary
        }
    }

    var foregroundColor: Color {
        self == .unavailable ? .secondary : .white
    }
}
