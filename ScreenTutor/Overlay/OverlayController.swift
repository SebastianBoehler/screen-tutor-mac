import AppKit
import SwiftUI

/// Full-screen, click-through panels (one per display) that draw teaching marks
/// over whatever the learner is looking at. They are ScreenTutor windows, so
/// screen capture for the tutor and agents never sees them.
@MainActor
final class OverlayController {
    private var panels: [CGDirectDisplayID: NSPanel] = [:]
    private var hideTask: Task<Void, Never>?
    private(set) var current: OverlayScene?

    func show(_ scene: OverlayScene) {
        hideTask?.cancel()
        current = scene
        var used = Set<CGDirectDisplayID>()
        for screen in NSScreen.screens {
            guard let displayID = screen.displayID else { continue }
            let displayBounds = CGDisplayBounds(displayID)
            let marks = scene.marks
                .filter { displayBounds.contains(CGPoint(x: $0.rect.midX, y: $0.rect.midY)) }
                .map { mark -> OverlayMark in
                    var local = mark
                    local.rect = mark.rect.offsetBy(dx: -displayBounds.minX, dy: -displayBounds.minY)
                    return local
                }
            guard !marks.isEmpty else { continue }
            used.insert(displayID)
            let panel = panels[displayID] ?? makePanel()
            panels[displayID] = panel
            let localBounds = CGRect(origin: .zero, size: displayBounds.size)
            panel.contentView = NSHostingView(rootView: OverlayCanvasView(marks: marks, bounds: localBounds))
            panel.setFrame(screen.frame, display: true)
            panel.alphaValue = 1
            panel.orderFrontRegardless()
        }
        for (id, panel) in panels where !used.contains(id) { panel.orderOut(nil) }

        let duration = scene.duration
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self?.fadeOut()
        }
    }

    func clear() {
        hideTask?.cancel()
        hideTask = nil
        current = nil
        for panel in panels.values { panel.orderOut(nil) }
    }

    private func fadeOut() {
        let visible = panels.values.filter(\.isVisible)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.4
            for panel in visible { panel.animator().alphaValue = 0 }
        } completionHandler: { [weak self] in
            Task { @MainActor in self?.clear() }
        }
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        return panel
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
