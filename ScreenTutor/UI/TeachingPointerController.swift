import AppKit
import SwiftUI

@MainActor
final class TeachingPointerController: NSObject {
    private let panel: NSPanel
    private let applicationNotificationCenter: NotificationCenter
    private let workspaceNotificationCenter: NotificationCenter
    private var hideTask: Task<Void, Never>?
    private var previousTarget: CGPoint?

    init(
        panel: NSPanel? = nil,
        applicationNotificationCenter: NotificationCenter = .default,
        workspaceNotificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter
    ) {
        self.panel = panel ?? NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.applicationNotificationCenter = applicationNotificationCenter
        self.workspaceNotificationCenter = workspaceNotificationCenter
        super.init()
        self.panel.level = .statusBar
        self.panel.isOpaque = false
        self.panel.backgroundColor = .clear
        self.panel.hasShadow = false
        self.panel.hidesOnDeactivate = false
        self.panel.ignoresMouseEvents = true
        self.panel.isReleasedWhenClosed = false
        self.panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        applicationNotificationCenter.addObserver(
            self,
            selector: #selector(presentationContextChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        workspaceNotificationCenter.addObserver(
            self,
            selector: #selector(presentationContextChanged),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
    }

    deinit {
        applicationNotificationCenter.removeObserver(self)
        workspaceNotificationCenter.removeObserver(self)
    }

    func show(_ highlight: TeachingHighlight) throws {
        hide()
        guard let screen = NSScreen.screens.first(where: {
            $0.frame.contains(
                CGPoint(x: highlight.globalFrame.midX, y: highlight.globalFrame.midY)
            )
        }) else {
            throw TeachingPointerPresentationError.targetOutsideConnectedDisplays
        }

        hideTask?.cancel()
        let layout = TeachingPointerLayout(
            globalHighlightFrame: highlight.globalFrame,
            screenFrame: screen.frame,
            mouseLocation: NSEvent.mouseLocation,
            previousTarget: previousTarget
        )
        panel.contentViewController = NSHostingController(
            rootView: TeachingHighlightView(layout: layout, label: highlight.label)
        )
        panel.setFrame(screen.frame, display: true)
        panel.orderFrontRegardless()
        guard panel.isVisible, panel.frame == screen.frame else {
            panel.orderOut(nil)
            throw TeachingPointerPresentationError.panelPresentationFailed
        }
        previousTarget = CGPoint(
            x: highlight.globalFrame.midX,
            y: highlight.globalFrame.midY
        )
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else { return }
            self?.hide()
        }
    }

    func hide() {
        hideTask?.cancel()
        hideTask = nil
        panel.orderOut(nil)
    }

    @objc
    private func presentationContextChanged() {
        previousTarget = nil
        hide()
    }
}
