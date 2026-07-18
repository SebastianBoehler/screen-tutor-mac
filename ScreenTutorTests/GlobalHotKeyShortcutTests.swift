import AppKit
import Carbon
import XCTest
@testable import ScreenTutor

final class GlobalHotKeyShortcutTests: XCTestCase {
    func testDefaultShortcutMatchesTheExistingCommandShiftSpaceBehavior() {
        let shortcut = GlobalHotKeyShortcut.defaultShortcut

        XCTAssertEqual(shortcut.keyCode, UInt32(kVK_Space))
        XCTAssertEqual(shortcut.modifiers, [.shift, .command])
        XCTAssertEqual(shortcut.displayName, "⇧⌘Space")
        XCTAssertEqual(shortcut.accessibilityName, "Shift-Command-Space")
        XCTAssertEqual(shortcut.carbonModifiers, UInt32(shiftKey | cmdKey))
    }

    func testShortcutRequiresAtLeastOneModifier() {
        XCTAssertThrowsError(
            try GlobalHotKeyShortcut(
                keyCode: UInt32(kVK_ANSI_K),
                modifiers: [],
                keyLabel: "K"
            )
        ) { error in
            XCTAssertEqual(error as? GlobalHotKeyShortcutError, .modifierRequired)
        }
    }

    func testShortcutCodableRoundTripPreservesRegistrationData() throws {
        let original = try GlobalHotKeyShortcut(
            keyCode: UInt32(kVK_ANSI_T),
            modifiers: [.control, .option, .command],
            keyLabel: "T"
        )

        let decoded = try JSONDecoder().decode(
            GlobalHotKeyShortcut.self,
            from: JSONEncoder().encode(original)
        )

        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.displayName, "⌃⌥⌘T")
    }

    func testRecorderConvertsAKeyboardEventIntoRegistrationData() throws {
        let event = try XCTUnwrap(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [.option, .command],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: "k",
                charactersIgnoringModifiers: "k",
                isARepeat: false,
                keyCode: UInt16(kVK_ANSI_K)
            )
        )

        let shortcut = try GlobalHotKeyShortcut(event: event)

        XCTAssertEqual(shortcut.keyCode, UInt32(kVK_ANSI_K))
        XCTAssertEqual(shortcut.modifiers, [.option, .command])
        XCTAssertEqual(shortcut.displayName, "⌥⌘K")
    }

    @MainActor
    func testControllerCanReplaceARegisteredShortcut() throws {
        let controller = GlobalHotKeyController(action: {})
        defer { controller.unregister() }
        let first = try GlobalHotKeyShortcut(
            keyCode: UInt32(kVK_F19),
            modifiers: [.control, .option, .shift, .command],
            keyLabel: "F19"
        )
        let second = try GlobalHotKeyShortcut(
            keyCode: UInt32(kVK_F20),
            modifiers: [.control, .option, .shift, .command],
            keyLabel: "F20"
        )

        try controller.register(first)
        try controller.register(second)
    }
}
