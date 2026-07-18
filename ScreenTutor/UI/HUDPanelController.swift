import AppKit
import Observation
import SwiftUI

@MainActor
final class HUDPanelController: NSObject, NSWindowDelegate {
    private let model: AppModel
    private let panel: HUDPanel
    private var screenAnchor = HUDScreenAnchorPolicy<NSScreen>()
    private var placement = HUDPanelPlacementPolicy()
    private var isApplyingAutomaticFrame = false

    init(model: AppModel) {
        self.model = model
        panel = HUDPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 76),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()
        panel.delegate = self
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
        panel.ignoresMouseEvents = false
        panel.isMovableByWindowBackground = true
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
        isApplyingAutomaticFrame = true
        panel.setContentSize(
            NSSize(width: 420, height: model.ambientTranscriptPresentation.panelHeight)
        )
        isApplyingAutomaticFrame = false
        positionPanel(
            on: screenAnchor.resolve(isVisible: isVisible, candidate: preferredScreen())
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

    private func preferredScreen() -> NSScreen? {
        if let userCenter = placement.userCenter {
            return NSScreen.screens.first { $0.frame.contains(userCenter) }
                ?? panel.screen
                ?? candidateScreen()
        }
        return candidateScreen()
    }

    private func positionPanel(on screen: NSScreen?) {
        guard let screen else { return }
        let frame = panel.frame
        let automaticOrigin = NSPoint(
            x: screen.visibleFrame.midX - frame.width / 2,
            y: screen.visibleFrame.maxY - frame.height - 8
        )
        let origin = placement.origin(
            for: frame.size,
            automaticOrigin: automaticOrigin,
            visibleFrame: screen.visibleFrame
        )
        isApplyingAutomaticFrame = true
        panel.setFrameOrigin(origin)
        isApplyingAutomaticFrame = false
    }

    @objc
    private func screenConfigurationChanged() {
        let isVisible = model.phase.isActive || model.errorMessage != nil
        let screen = isVisible ? preferredScreen() : nil
        screenAnchor.retarget(to: screen)
        positionPanel(on: screen)
    }

    func windowDidMove(_ notification: Notification) {
        guard panel.isVisible, !isApplyingAutomaticFrame else { return }
        placement.recordUserFrame(panel.frame)
        let screen = NSScreen.screens.first { $0.frame.contains(panel.frame.center) }
            ?? panel.screen
        screenAnchor.retarget(to: screen)
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

struct HUDPanelPlacementPolicy {
    private(set) var userCenter: CGPoint?

    mutating func recordUserFrame(_ frame: CGRect) {
        userCenter = frame.center
    }

    func origin(
        for size: CGSize,
        automaticOrigin: CGPoint,
        visibleFrame: CGRect
    ) -> CGPoint {
        guard let userCenter else { return automaticOrigin }
        let proposed = CGPoint(
            x: userCenter.x - size.width / 2,
            y: userCenter.y - size.height / 2
        )
        let margin: CGFloat = 8
        let minimumX = visibleFrame.minX + margin
        let minimumY = visibleFrame.minY + margin
        let maximumX = max(minimumX, visibleFrame.maxX - margin - size.width)
        let maximumY = max(minimumY, visibleFrame.maxY - margin - size.height)
        return CGPoint(
            x: min(max(proposed.x, minimumX), maximumX),
            y: min(max(proposed.y, minimumY), maximumY)
        )
    }
}

private extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}
