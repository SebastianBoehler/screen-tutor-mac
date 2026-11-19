import AppKit
import SwiftUI

/// Full-screen, click-through panels (one per display) that draw teaching marks
/// over whatever the learner is looking at. They are ScreenTutor windows, so
/// screen capture for the tutor and agents never sees them.
@MainActor
final class OverlayController {
    private var panels: [CGDirectDisplayID: NSPanel] = [:]
    private var hideTask: Task<Void, Never>?
    private var trackingTask: Task<Void, Never>?
    private var sourceScene: OverlayScene?
    private(set) var revision = UUID()
    private(set) var current: OverlayScene?
    var resolveAnchor: (@MainActor (NativeOverlayAnchor) -> CGRect?)?

    @discardableResult
    func show(_ scene: OverlayScene, ifRevisionMatches expected: UUID? = nil) -> Bool {
        if let expected, expected != revision { return false }
        hideTask?.cancel()
        trackingTask?.cancel()
        revision = UUID()
        guard scene.duration.isFinite, scene.duration > 0, !scene.marks.isEmpty else {
            clear()
            return false
        }
        sourceScene = scene
        current = nil
        let visible = LiveOverlayTracking.refreshed(scene) { resolveAnchor?($0) }
        render(visible, animated: true)
        if scene.marks.contains(where: { $0.anchor != nil }) {
            refreshAnchors()
            trackingTask = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
                    guard let self, self.sourceScene != nil else { return }
                    self.refreshAnchors()
                }
            }
        }
        hideTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(scene.duration)) } catch { return }
            self?.fadeOut()
        }
        return true
    }

    func refreshAnchors() {
        guard let sourceScene else { return }
        let refreshed = LiveOverlayTracking.refreshed(sourceScene) { resolveAnchor?($0) }
        guard refreshed != current else { return }
        render(refreshed, animated: false)
    }

    private func render(_ scene: OverlayScene, animated: Bool) {
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
            let view = OverlayCanvasView(marks: marks, bounds: localBounds, animated: animated)
            if let hosting = panel.contentView as? NSHostingView<OverlayCanvasView> {
                hosting.rootView = view
            } else {
                panel.contentView = NSHostingView(rootView: view)
            }
            panel.setFrame(screen.frame, display: true)
            panel.alphaValue = 1
            panel.orderFrontRegardless()
        }
        for (id, panel) in panels where !used.contains(id) { panel.orderOut(nil) }

    }

    func clear() {
        hideTask?.cancel()
        hideTask = nil
        trackingTask?.cancel()
        trackingTask = nil
        sourceScene = nil
        revision = UUID()
        current = nil
        for panel in panels.values { panel.orderOut(nil) }
    }

    private func fadeOut() {
        trackingTask?.cancel()
        trackingTask = nil
        sourceScene = nil
        let fadingID = revision
        let visible = panels.values.filter(\.isVisible)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.4
            for panel in visible { panel.animator().alphaValue = 0 }
        } completionHandler: { [weak self] in
            Task { @MainActor in
                guard self?.revision == fadingID else { return }
                self?.clear()
            }
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
