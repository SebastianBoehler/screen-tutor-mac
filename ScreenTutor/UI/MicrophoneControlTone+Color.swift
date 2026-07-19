import SwiftUI

extension MicrophoneControlState.Tone {
    var color: Color {
        switch self {
        case .accent: .accentColor
        case .live: .green
        case .muted: .orange
        case .unavailable: .secondary
        }
    }
}
