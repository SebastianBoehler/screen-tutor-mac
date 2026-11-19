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
        case "inspect_app": "Reading app controls"
        case "activate_control": "Using app control"
        case "highlight_control": "Highlighting app control"
        case "set_learning_goal": "Setting learning goal"
        case "search_course_materials": "Reading course sources"
        case "present_flashcard": "Creating recall card"
        case "organize_workspace": "Organizing learning canvas"
        case "record_learning_insight": "Remembering your reasoning"
        case "capture_camera": "Taking camera photo"
        case "look_at_desk": "Looking at desk"
        case "get_desk_notes": "Reading desk notes"
        case "assign_task": "Setting a task"
        case "finish_task": "Closing task"
        case "show_visual": "Drawing on board"
        case "open_url": "Opening link"
        case "start_topic": "Mapping the topic"
        case "record_evidence": "Updating progress"
        case "show_progress": "Showing progress"
        case "review_due": "Checking reviews"
        case "annotate_screen": "Drawing on screen"
        case "clear_annotations": "Clearing marks"
        case "find_videos": "Finding videos"
        case "play_video": "Opening video"
        case "control_video": "Controlling video"
        case "open_application": "Opening app"
        case "create_document": "Writing document"
        case "click_in_window": "Clicking"
        case "type_text": "Typing"
        case "press_keys": "Pressing keys"
        case "scroll_window": "Scrolling"
        case "do_on_computer": "Starting computer task"
        case "stop_computer_task": "Stopping computer task"
        default: name.replacing("_", with: " ").capitalized
        }
    }

    var symbolName: String {
        switch name {
        case "list_windows": "macwindow.on.rectangle"
        case "capture_window": "camera.viewfinder"
        case "point_at_screen_position": "cursorarrow.motionlines"
        case "inspect_app", "activate_control": "macwindow"
        case "highlight_control": "pencil.and.outline"
        case "set_learning_goal": "target"
        case "search_course_materials": "doc.text.magnifyingglass"
        case "present_flashcard": "rectangle.on.rectangle"
        case "organize_workspace": "square.grid.2x2"
        case "record_learning_insight": "brain"
        case "capture_camera", "look_at_desk": "camera.fill"
        case "get_desk_notes": "note.text"
        case "assign_task", "finish_task": "checklist"
        case "show_visual": "rectangle.and.pencil.and.ellipsis"
        case "open_url": "safari"
        case "start_topic", "record_evidence", "show_progress", "review_due": "chart.bar.doc.horizontal"
        case "annotate_screen", "clear_annotations": "pencil.and.outline"
        case "find_videos", "play_video", "control_video": "play.rectangle"
        case "open_application": "app.badge"
        case "create_document": "doc.richtext"
        case "click_in_window": "cursorarrow.click"
        case "type_text", "press_keys": "keyboard"
        case "scroll_window": "scroll"
        case "do_on_computer", "stop_computer_task": "desktopcomputer"
        default: "wrench.and.screwdriver"
        }
    }
}
