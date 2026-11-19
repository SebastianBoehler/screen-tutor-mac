import CoreGraphics
import Foundation

enum NativeControlAction: String, Codable, Sendable, CaseIterable {
    case press, showMenu = "show_menu", increment, decrement

    var accessibilityName: String {
        switch self {
        case .press: "AXPress"
        case .showMenu: "AXShowMenu"
        case .increment: "AXIncrement"
        case .decrement: "AXDecrement"
        }
    }
}

struct NativeAppIdentity: Codable, Equatable, Sendable {
    let processID: Int32
    let windowToken: String
    let application: String
    let windowTitle: String
}

struct NativeAppControl: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let role: String
    let label: String
    let frame: CGRect
    let enabled: Bool
    let actions: [NativeControlAction]
}

struct NativeAppSnapshot: Codable, Equatable, Sendable {
    let app: NativeAppIdentity
    let controls: [NativeAppControl]
    let selectedText: String?
    let truncated: Bool

    func json() throws -> String {
        let data = try JSONEncoder().encode(self)
        guard let text = String(data: data, encoding: .utf8) else {
            throw NativeAppError.unavailable("The native app state could not be encoded.")
        }
        return text
    }
}

struct NativeOverlayAnchor: Equatable, Sendable {
    let controlID: String
    let app: NativeAppIdentity
}

enum NativeAppError: LocalizedError {
    case permissionDenied, noWindow, focusChanged, staleControl, disabledControl, unsupportedAction
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied: "Allow ScreenTutor in System Settings > Privacy & Security > Accessibility to read native controls."
        case .noWindow: "There is no focused app window to inspect. Bring the study app to the front."
        case .focusChanged: "The focused app or window changed. Inspect the app again before acting."
        case .staleControl: "This control is no longer available. Inspect the app again."
        case .disabledControl: "This control is disabled or no longer visible."
        case .unsupportedAction: "The control does not support this native action."
        case .unavailable(let message): message
        }
    }
}

@MainActor
protocol NativeAppBackend {
    func read() throws -> NativeAppSnapshot
    func currentControl(id: String, in app: NativeAppIdentity) throws -> NativeAppControl
    func perform(_ action: NativeControlAction, controlID: String, in app: NativeAppIdentity) throws
}
