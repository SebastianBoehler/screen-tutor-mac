import AppKit
import Carbon
import Foundation

enum GlobalHotKeyModifier: String, Codable, CaseIterable, Sendable {
    case control
    case option
    case shift
    case command

    var symbol: String {
        switch self {
        case .control: "⌃"
        case .option: "⌥"
        case .shift: "⇧"
        case .command: "⌘"
        }
    }

    var accessibilityName: String { rawValue.capitalized }
}

struct GlobalHotKeyShortcut: Codable, Equatable, Sendable {
    let keyCode: UInt32
    let modifiers: Set<GlobalHotKeyModifier>
    let keyLabel: String

    static let defaultShortcut = GlobalHotKeyShortcut(
        uncheckedKeyCode: UInt32(kVK_Space),
        modifiers: [.shift, .command],
        keyLabel: "Space"
    )

    init(
        keyCode: UInt32,
        modifiers: Set<GlobalHotKeyModifier>,
        keyLabel: String
    ) throws {
        let normalizedLabel = keyLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !modifiers.isEmpty else { throw GlobalHotKeyShortcutError.modifierRequired }
        guard keyCode <= UInt16.max, !normalizedLabel.isEmpty else {
            throw GlobalHotKeyShortcutError.invalidKey
        }
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.keyLabel = normalizedLabel
    }

    init(event: NSEvent) throws {
        try self.init(
            keyCode: UInt32(event.keyCode),
            modifiers: Self.modifiers(from: event.modifierFlags),
            keyLabel: Self.keyLabel(
                for: UInt32(event.keyCode),
                characters: event.charactersIgnoringModifiers
            )
        )
    }

    var displayName: String {
        GlobalHotKeyModifier.allCases
            .filter(modifiers.contains)
            .map(\.symbol)
            .joined() + keyLabel
    }

    var accessibilityName: String {
        (GlobalHotKeyModifier.allCases
            .filter(modifiers.contains)
            .map(\.accessibilityName) + [keyLabel])
            .joined(separator: "-")
    }

    var carbonModifiers: UInt32 {
        modifiers.reduce(into: UInt32(0)) { value, modifier in
            switch modifier {
            case .control: value |= UInt32(controlKey)
            case .option: value |= UInt32(optionKey)
            case .shift: value |= UInt32(shiftKey)
            case .command: value |= UInt32(cmdKey)
            }
        }
    }

    private init(
        uncheckedKeyCode: UInt32,
        modifiers: Set<GlobalHotKeyModifier>,
        keyLabel: String
    ) {
        keyCode = uncheckedKeyCode
        self.modifiers = modifiers
        self.keyLabel = keyLabel
    }

    private enum CodingKeys: String, CodingKey {
        case keyCode = "key_code"
        case modifiers
        case keyLabel = "key_label"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            keyCode: container.decode(UInt32.self, forKey: .keyCode),
            modifiers: container.decode(Set<GlobalHotKeyModifier>.self, forKey: .modifiers),
            keyLabel: container.decode(String.self, forKey: .keyLabel)
        )
    }

    private static func modifiers(from flags: NSEvent.ModifierFlags) -> Set<GlobalHotKeyModifier> {
        var modifiers = Set<GlobalHotKeyModifier>()
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.command) { modifiers.insert(.command) }
        return modifiers
    }

    private static func keyLabel(for keyCode: UInt32, characters: String?) -> String {
        switch Int(keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return: return "Return"
        case kVK_Tab: return "Tab"
        case kVK_Delete: return "Delete"
        case kVK_ForwardDelete: return "Forward Delete"
        case kVK_Home: return "Home"
        case kVK_End: return "End"
        case kVK_PageUp: return "Page Up"
        case kVK_PageDown: return "Page Down"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_DownArrow: return "↓"
        case kVK_UpArrow: return "↑"
        case kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8,
             kVK_F9, kVK_F10, kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15,
             kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20:
            return functionKeyLabel(for: Int(keyCode))
        default:
            return characters?.uppercased() ?? ""
        }
    }

    private static func functionKeyLabel(for keyCode: Int) -> String {
        let functionKeys = [
            kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8,
            kVK_F9, kVK_F10, kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15,
            kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20,
        ]
        guard let index = functionKeys.firstIndex(of: keyCode) else { return "" }
        return "F\(index + 1)"
    }
}

enum GlobalHotKeyShortcutError: LocalizedError, Equatable {
    case modifierRequired
    case invalidKey

    var errorDescription: String? {
        switch self {
        case .modifierRequired: "Use at least one modifier key in the global shortcut."
        case .invalidKey: "That key cannot be used as a global shortcut."
        }
    }
}
