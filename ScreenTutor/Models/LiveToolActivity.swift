import Foundation

enum LiveToolActivityStatus: Equatable, Sendable {
    case started
    case succeeded
    case failed

    init(_ status: ConversationToolStatus) {
        switch status {
        case .succeeded: self = .succeeded
        case .failed: self = .failed
        }
    }
}

struct LiveToolActivity: Identifiable, Equatable, Sendable {
    let name: String
    let status: LiveToolActivityStatus
    let turn: Int

    var id: String { "\(turn):\(name)" }

    var displayName: String {
        switch name {
        case "list_windows": "Reading windows"
        case "capture_window": "Capturing window"
        case "highlight_screen_region": "Highlighting"
        default: name.replacing("_", with: " ").capitalized
        }
    }

    var symbolName: String {
        switch name {
        case "list_windows": "macwindow.on.rectangle"
        case "capture_window": "camera.viewfinder"
        case "highlight_screen_region": "scope"
        default: "wrench.and.screwdriver"
        }
    }
}
