import AppKit
import Carbon.HIToolbox
import CoreGraphics

/// Posts synthetic mouse and keyboard events. Coordinates are CoreGraphics
/// global points (origin at the top-left of the primary display).
///
/// Safety: every action first checks whether the learner moved the mouse away
/// from where ScreenTutor last left it. If they did, the action is refused, so
/// grabbing the mouse always takes control back.
@MainActor
final class InputController {
    private var lastPostedLocation: CGPoint?
    private let takeoverDistance: CGFloat = 60

    var hasPermission: Bool { CGPreflightPostEventAccess() }

    @discardableResult
    func requestPermission() -> Bool { CGRequestPostEventAccess() }

    /// Forget the last pointer position (start of a new task).
    func resetTakeoverTracking() { lastPostedLocation = nil }

    func click(at point: CGPoint, button: MouseButton = .left, clickCount: Int = 1) throws {
        try preflight()
        let (downType, upType, cgButton) = button.eventTypes
        post(mouseEvent(.mouseMoved, at: point, button: cgButton))
        for count in 1...max(1, min(clickCount, 3)) {
            let down = mouseEvent(downType, at: point, button: cgButton)
            let up = mouseEvent(upType, at: point, button: cgButton)
            down?.setIntegerValueField(.mouseEventClickState, value: Int64(count))
            up?.setIntegerValueField(.mouseEventClickState, value: Int64(count))
            post(down)
            post(up)
        }
        lastPostedLocation = point
    }

    func moveMouse(to point: CGPoint) throws {
        try preflight()
        post(mouseEvent(.mouseMoved, at: point, button: .left))
        lastPostedLocation = point
    }

    func scroll(at point: CGPoint?, lines: Int) throws {
        try preflight()
        if let point {
            post(mouseEvent(.mouseMoved, at: point, button: .left))
            lastPostedLocation = point
        }
        let clamped = Int32(max(-30, min(30, lines)))
        let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .line,
            wheelCount: 1,
            wheel1: clamped,
            wheel2: 0,
            wheel3: 0
        )
        post(event)
    }

    /// Types text into the focused field. Newlines press Return.
    func type(_ text: String) async throws {
        try preflight()
        let lines = text.components(separatedBy: "\n")
        for (lineIndex, line) in lines.enumerated() {
            if lineIndex > 0 { try press(KeyCombo(key: "return", flags: [])) }
            let characters = Array(line.utf16)
            var index = 0
            while index < characters.count {
                let chunk = Array(characters[index..<min(index + 16, characters.count)])
                for keyDown in [true, false] {
                    let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: keyDown)
                    event?.flags = []
                    chunk.withUnsafeBufferPointer { buffer in
                        event?.keyboardSetUnicodeString(
                            stringLength: buffer.count,
                            unicodeString: buffer.baseAddress
                        )
                    }
                    post(event)
                }
                index += 16
                try await Task.sleep(for: .milliseconds(12))
            }
        }
    }

    func press(_ combo: KeyCombo) throws {
        try preflight()
        guard let keyCode = KeyboardLayout.keyCode(for: combo.key) else {
            throw InputControlError.unknownKey(combo.key)
        }
        let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
        let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        down?.flags = combo.flags
        up?.flags = combo.flags
        post(down)
        post(up)
    }

    /// Converts an AppKit global point (bottom-left origin) to CoreGraphics global space.
    static func coreGraphicsPoint(fromAppKit point: CGPoint) -> CGPoint {
        let primaryHeight = NSScreen.screens.first?.frame.maxY ?? 0
        return CGPoint(x: point.x, y: primaryHeight - point.y)
    }

    static func appKitPoint(fromCoreGraphics point: CGPoint) -> CGPoint {
        coreGraphicsPoint(fromAppKit: point)
    }

    private func preflight() throws {
        guard hasPermission else { throw InputControlError.permissionDenied }
        if
            let lastPostedLocation,
            let current = CGEvent(source: nil)?.location,
            hypot(current.x - lastPostedLocation.x, current.y - lastPostedLocation.y) > takeoverDistance
        {
            self.lastPostedLocation = nil
            throw InputControlError.userTookOver
        }
    }

    private func mouseEvent(_ type: CGEventType, at point: CGPoint, button: CGMouseButton) -> CGEvent? {
        CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: button)
    }

    private func post(_ event: CGEvent?) {
        event?.post(tap: .cghidEventTap)
    }
}

enum MouseButton: String, Sendable {
    case left, right

    var eventTypes: (CGEventType, CGEventType, CGMouseButton) {
        switch self {
        case .left: (.leftMouseDown, .leftMouseUp, .left)
        case .right: (.rightMouseDown, .rightMouseUp, .right)
        }
    }
}

enum InputControlError: LocalizedError, Equatable {
    case permissionDenied
    case userTookOver
    case unknownKey(String)
    case disabled

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "ScreenTutor needs Accessibility permission to control the mouse and keyboard. Grant it in Settings > Permissions."
        case .userTookOver:
            "The learner moved the mouse, so ScreenTutor stopped controlling the Mac."
        case .unknownKey(let key):
            "Unknown key “\(key)”."
        case .disabled:
            "Computer control is off. The learner can enable it in ScreenTutor Settings > Computer control."
        }
    }
}

/// A parsed key combination such as "cmd+shift+t" or "return".
struct KeyCombo: Equatable, Sendable {
    let key: String
    let flags: CGEventFlags

    init(key: String, flags: CGEventFlags) {
        self.key = key
        self.flags = flags
    }

    init(parsing raw: String) throws {
        let parts = raw.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .split(separator: "+", omittingEmptySubsequences: false)
            .map(String.init)
        guard let last = parts.last else { throw InputControlError.unknownKey(raw) }
        // "cmd++" means command plus the "+" key.
        let keyName = last.isEmpty && parts.count >= 2 ? "+" : last
        let modifierParts = last.isEmpty ? parts.dropLast(2) : parts.dropLast()
        var flags: CGEventFlags = []
        for modifier in modifierParts {
            switch modifier {
            case "cmd", "command", "⌘", "meta", "super": flags.insert(.maskCommand)
            case "shift", "⇧": flags.insert(.maskShift)
            case "opt", "option", "alt", "⌥": flags.insert(.maskAlternate)
            case "ctrl", "control", "⌃": flags.insert(.maskControl)
            case "fn": flags.insert(.maskSecondaryFn)
            default: throw InputControlError.unknownKey(modifier)
            }
        }
        guard !keyName.isEmpty else { throw InputControlError.unknownKey(raw) }
        key = keyName
        self.flags = flags
    }
}

/// Maps key names and characters to virtual key codes, honouring the current
/// keyboard layout (so "cmd+z" is correct on a German QWERTZ keyboard too).
enum KeyboardLayout {
    static let namedKeys: [String: CGKeyCode] = [
        "return": 36, "enter": 36, "tab": 48, "space": 49, "delete": 51, "backspace": 51,
        "escape": 53, "esc": 53, "forwarddelete": 117, "home": 115, "end": 119,
        "pageup": 116, "pagedown": 121, "left": 123, "right": 124, "down": 125, "up": 126,
        "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97, "f7": 98, "f8": 100,
        "f9": 101, "f10": 109, "f11": 103, "f12": 111
    ]

    private static let ansiFallback: [Character: CGKeyCode] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
        "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "1": 18, "2": 19,
        "3": 20, "4": 21, "6": 22, "5": 23, "=": 24, "9": 25, "7": 26, "-": 27, "8": 28,
        "0": 29, "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "l": 37, "j": 38,
        "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44, "n": 45, "m": 46, ".": 47,
        "`": 50
    ]

    static func keyCode(for key: String) -> CGKeyCode? {
        if let named = namedKeys[key] { return named }
        guard key.count == 1, let character = key.first else { return nil }
        return layoutMap()[character] ?? ansiFallback[character]
    }

    private static func layoutMap() -> [Character: CGKeyCode] {
        guard
            let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
            let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return [:] }
        let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
        var map: [Character: CGKeyCode] = [:]
        data.withUnsafeBytes { raw in
            guard let layout = raw.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else {
                return
            }
            for code in 0..<CGKeyCode(128) {
                var deadKeyState: UInt32 = 0
                var length = 0
                var characters = [UniChar](repeating: 0, count: 4)
                let status = UCKeyTranslate(
                    layout,
                    code,
                    UInt16(kUCKeyActionDisplay),
                    0,
                    UInt32(LMGetKbdType()),
                    OptionBits(kUCKeyTranslateNoDeadKeysBit),
                    &deadKeyState,
                    characters.count,
                    &length,
                    &characters
                )
                guard status == noErr, length == 1 else { continue }
                let string = String(utf16CodeUnits: characters, count: length).lowercased()
                if let character = string.first, map[character] == nil {
                    map[character] = code
                }
            }
        }
        return map
    }
}
