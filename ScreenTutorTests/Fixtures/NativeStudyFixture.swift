import AppKit

/// A separate test app: all native-action and scrolling checks operate on disposable UI.
@main
struct NativeStudyFixture {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = StudyFixtureDelegate()
        app.setActivationPolicy(.regular)
        app.delegate = delegate
        app.run()
        withExtendedLifetime(delegate) {}
    }
}

@MainActor
final class StudyFixtureDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private let status = NSTextField(labelWithString: "Your attempt first")
    private let scroll = NSScrollView()
    private let term = NSTextField(labelWithString: "Learning target: update rule")

    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: NSRect(x: 220, y: 220, width: 620, height: 480),
                          styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "Native Study Fixture"
        window.isReleasedWhenClosed = false
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 620, height: 480))
        window.contentView = content
        let button = NSButton(title: "Check step", target: self, action: #selector(checkStep))
        button.frame = NSRect(x: 24, y: 420, width: 140, height: 32)
        button.setAccessibilityIdentifier("check-step")
        content.addSubview(button)
        status.frame = NSRect(x: 190, y: 425, width: 350, height: 24)
        content.addSubview(status)

        scroll.frame = NSRect(x: 24, y: 80, width: 570, height: 320)
        scroll.hasVerticalScroller = true
        let document = FlippedStudyView(frame: NSRect(x: 0, y: 0, width: 540, height: 1_600))
        term.frame = NSRect(x: 20, y: 70, width: 440, height: 30)
        term.font = .systemFont(ofSize: 22)
        document.addSubview(term)
        scroll.documentView = document
        content.addSubview(scroll)

        let move = NSButton(title: "Move window", target: self, action: #selector(moveWindow))
        move.frame = NSRect(x: 24, y: 24, width: 140, height: 32)
        content.addSubview(move)
        let down = NSButton(title: "Scroll target away", target: self, action: #selector(scrollAway))
        down.frame = NSRect(x: 180, y: 24, width: 170, height: 32)
        content.addSubview(down)
        let up = NSButton(title: "Return to target", target: self, action: #selector(scrollBack))
        up.frame = NSRect(x: 370, y: 24, width: 170, height: 32)
        content.addSubview(up)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func checkStep() { status.stringValue = "Next step is yours" }
    @objc private func moveWindow() { window.setFrameOrigin(window.frame.origin.applying(CGAffineTransform(translationX: 80, y: 40))) }
    @objc private func scrollAway() {
        scroll.contentView.scroll(to: NSPoint(x: 0, y: 600))
        scroll.reflectScrolledClipView(scroll.contentView)
    }
    @objc private func scrollBack() {
        scroll.contentView.scroll(to: .zero)
        scroll.reflectScrolledClipView(scroll.contentView)
    }
}

final class FlippedStudyView: NSView {
    override var isFlipped: Bool { true }
    override func isAccessibilityElement() -> Bool { false }
}
