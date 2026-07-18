import AppKit
import Observation
import SwiftUI

@MainActor
final class HUDPanelController {
    private let model: AppModel
    private let panel: HUDPanel
    private var screenAnchor = HUDScreenAnchorPolicy<NSScreen>()

    init(model: AppModel) {
        self.model = model
        panel = HUDPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 76),
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
        positionPanel(on: candidateScreen())
    }

    private func observeModel() {
        withObservationTracking {
            _ = model.phase
            _ = model.errorMessage
            _ = model.latestUserTranscript
            _ = model.assistantTranscript
            _ = model.showsTranscriptOverlay
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.refreshVisibility()
                self?.observeModel()
            }
        }
        refreshVisibility()
    }

    private func refreshVisibility() {
        let isVisible = model.phase.isActive || model.errorMessage != nil
        panel.setContentSize(
            NSSize(width: 420, height: model.ambientTranscriptPresentation.panelHeight)
        )
        positionPanel(
            on: screenAnchor.resolve(isVisible: isVisible, candidate: candidateScreen())
        )
        if isVisible {
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
        }
    }

    private func candidateScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouseLocation) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }

    private func positionPanel(on screen: NSScreen?) {
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
        let isVisible = model.phase.isActive || model.errorMessage != nil
        let screen = isVisible ? candidateScreen() : nil
        screenAnchor.retarget(to: screen)
        positionPanel(on: screen)
    }
}

struct HUDScreenAnchorPolicy<ScreenID> {
    private(set) var anchor: ScreenID?

    mutating func resolve(isVisible: Bool, candidate: ScreenID?) -> ScreenID? {
        guard isVisible else {
            anchor = nil
            return nil
        }
        if anchor == nil { anchor = candidate }
        return anchor
    }

    mutating func retarget(to candidate: ScreenID?) {
        anchor = candidate
    }
}
