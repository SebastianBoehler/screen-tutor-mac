import AppKit
import Carbon
import SwiftUI

struct GlobalHotKeyShortcutRecorder: NSViewRepresentable {
    let shortcut: GlobalHotKeyShortcut
    let onChange: (GlobalHotKeyShortcut) -> Bool
    let onError: (Error) -> Void

    func makeNSView(context: Context) -> ShortcutRecorderButton {
        ShortcutRecorderButton(
            shortcut: shortcut,
            onChange: onChange,
            onError: onError
        )
    }

    func updateNSView(_ button: ShortcutRecorderButton, context: Context) {
        button.onChange = onChange
        button.onError = onError
        button.updateShortcut(shortcut)
    }
}

@MainActor
final class ShortcutRecorderButton: NSButton {
    var onChange: (GlobalHotKeyShortcut) -> Bool
    var onError: (Error) -> Void

    private var shortcut: GlobalHotKeyShortcut
    private var isRecording = false

    init(
        shortcut: GlobalHotKeyShortcut,
        onChange: @escaping (GlobalHotKeyShortcut) -> Bool,
        onError: @escaping (Error) -> Void
    ) {
        self.shortcut = shortcut
        self.onChange = onChange
        self.onError = onError
        super.init(frame: .zero)
        target = self
        action = #selector(beginRecording)
        bezelStyle = .rounded
        controlSize = .regular
        focusRingType = .default
        setButtonType(.momentaryPushIn)
        refreshPresentation()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override var acceptsFirstResponder: Bool { true }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 160, height: 28)
    }

    func updateShortcut(_ shortcut: GlobalHotKeyShortcut) {
        guard !isRecording else { return }
        self.shortcut = shortcut
        refreshPresentation()
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        capture(event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording else { return super.performKeyEquivalent(with: event) }
        capture(event)
        return true
    }

    override func resignFirstResponder() -> Bool {
        cancelRecording()
        return super.resignFirstResponder()
    }

    @objc
    private func beginRecording() {
        isRecording = true
        title = "Type shortcut…"
        toolTip = "Press a key combination, or Escape to cancel"
        setAccessibilityLabel("Recording global shortcut")
        window?.makeFirstResponder(self)
    }

    private func capture(_ event: NSEvent) {
        if Int(event.keyCode) == kVK_Escape {
            cancelRecording()
            return
        }

        do {
            let candidate = try GlobalHotKeyShortcut(event: event)
            if onChange(candidate) {
                shortcut = candidate
                finishRecording()
            } else {
                NSSound.beep()
                cancelRecording()
            }
        } catch {
            NSSound.beep()
            onError(error)
        }
    }

    private func cancelRecording() {
        guard isRecording else { return }
        finishRecording()
    }

    private func finishRecording() {
        isRecording = false
        refreshPresentation()
        window?.makeFirstResponder(nil)
    }

    private func refreshPresentation() {
        title = shortcut.displayName
        toolTip = "Click to record a new global shortcut"
        setAccessibilityLabel("Global shortcut, \(shortcut.accessibilityName)")
    }
}
