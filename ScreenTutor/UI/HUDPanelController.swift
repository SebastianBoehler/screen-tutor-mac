import AppKit
import Observation
import SwiftUI

@MainActor
final class HUDPanelController {
    private let model: AppModel
    private let panel: HUDPanel

    init(model: AppModel) {
        self.model = model
        panel = HUDPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 76),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        configurePanel()
        observeModel()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenConfigurationChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(screenConfigurationChanged),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    private func configurePanel() {
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .transient,
            .ignoresCycle
        ]
        panel.contentViewController = NSHostingController(rootView: HUDView(model: model))
        positionPanel()
    }

    private func observeModel() {
        withObservationTracking {
            _ = model.phase
            _ = model.errorMessage
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.refreshVisibility()
                self?.observeModel()
            }
        }
        refreshVisibility()
    }

    private func refreshVisibility() {
        positionPanel()
        if model.phase.isActive || model.errorMessage != nil {
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
        }
    }

    private func positionPanel() {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouseLocation) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen else { return }
        let frame = panel.frame
        panel.setFrameOrigin(
            NSPoint(
                x: screen.visibleFrame.midX - frame.width / 2,
                y: screen.visibleFrame.maxY - frame.height - 8
            )
        )
    }

    @objc
    private func screenConfigurationChanged() {
        positionPanel()
    }
}
