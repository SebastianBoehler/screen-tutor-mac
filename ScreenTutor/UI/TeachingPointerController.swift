import AppKit
import SwiftUI

@MainActor
final class TeachingPointerController {
    private let panel: NSPanel
    private var hideTask: Task<Void, Never>?

    init() {
        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
    }

    func show(_ highlight: TeachingHighlight) {
        guard let screen = NSScreen.screens.first(where: {
            $0.frame.contains(
                CGPoint(x: highlight.globalFrame.midX, y: highlight.globalFrame.midY)
            )
        }) else { return }

        hideTask?.cancel()
        let localFrame = CGRect(
            x: highlight.globalFrame.minX - screen.frame.minX,
            y: screen.frame.maxY - highlight.globalFrame.maxY,
            width: highlight.globalFrame.width,
            height: highlight.globalFrame.height
        )
        panel.setFrame(screen.frame, display: true)
        panel.contentViewController = NSHostingController(
            rootView: TeachingHighlightView(frame: localFrame, label: highlight.label)
        )
        panel.orderFrontRegardless()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(7))
            guard !Task.isCancelled else { return }
            self?.hide()
        }
    }

    func hide() {
        hideTask?.cancel()
        hideTask = nil
        panel.orderOut(nil)
    }
}
