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
        case "point_at_screen_position": "Pointing on screen"
        case "capture_camera": "Taking camera photo"
        case "look_at_desk": "Looking at desk"
        case "get_desk_notes": "Reading desk notes"
        case "assign_task": "Setting a task"
        case "finish_task": "Closing task"
        case "show_visual": "Drawing on board"
        case "open_url": "Opening link"
        case "search_youtube": "Searching YouTube"
        case "open_application": "Opening app"
        case "create_document": "Writing document"
        default: name.replacing("_", with: " ").capitalized
        }
    }

    var symbolName: String {
        switch name {
        case "list_windows": "macwindow.on.rectangle"
        case "capture_window": "camera.viewfinder"
        case "point_at_screen_position": "cursorarrow.motionlines"
        case "capture_camera", "look_at_desk": "camera.fill"
        case "get_desk_notes": "note.text"
        case "assign_task", "finish_task": "checklist"
        case "show_visual": "rectangle.and.pencil.and.ellipsis"
        case "open_url": "safari"
        case "search_youtube": "play.rectangle"
        case "open_application": "app.badge"
        case "create_document": "doc.richtext"
        default: "wrench.and.screwdriver"
        }
    }
}
