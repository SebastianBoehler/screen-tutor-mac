import AppKit
import XCTest
@testable import ScreenTutor

@MainActor
final class TeachingPointerLayoutTests: XCTestCase {
    func testConvertsGlobalAppKitCoordinatesForTheSwiftUIOverlay() {
        let layout = TeachingPointerLayout(
            globalHighlightFrame: CGRect(x: 100, y: 200, width: 200, height: 100),
            screenFrame: CGRect(x: -100, y: 0, width: 1_000, height: 800),
            mouseLocation: CGPoint(x: 0, y: 700),
            previousTarget: nil
        )

        XCTAssertEqual(layout.localHighlightFrame, CGRect(x: 200, y: 500, width: 200, height: 100))
        XCTAssertEqual(layout.targetPoint, CGPoint(x: 300, y: 550))
        XCTAssertEqual(layout.startPoint, CGPoint(x: 100, y: 100))
    }

    func testPreviousTutorTargetWinsWhenItIsOnTheSameScreen() {
        let layout = TeachingPointerLayout(
            globalHighlightFrame: CGRect(x: 500, y: 300, width: 100, height: 100),
            screenFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800),
            mouseLocation: CGPoint(x: 50, y: 50),
            previousTarget: CGPoint(x: 250, y: 600)
        )

        XCTAssertEqual(layout.startPoint, CGPoint(x: 250, y: 200))
    }

    func testShowKeepsPanelScreenSizedAfterInstallingHostingContent() throws {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        let controller = TeachingPointerController(panel: panel)
        let screen = try XCTUnwrap(NSScreen.main)
        let highlight = try TeachingHighlight(
            argumentsJSON: #"{"x":0.4,"y":0.4,"width":0.2,"height":0.2,"label":"test target"}"#,
            windowFrame: screen.visibleFrame
        )

        try controller.show(highlight)

        XCTAssertTrue(panel.isVisible)
        XCTAssertEqual(panel.frame, screen.frame)
        controller.hide()
    }

    func testInvalidReplacementClearsThePreviousPointer() throws {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        let controller = TeachingPointerController(panel: panel)
        let screen = try XCTUnwrap(NSScreen.main)
        let visibleHighlight = try TeachingHighlight(
            argumentsJSON: #"{"x":0.4,"y":0.4,"width":0.2,"height":0.2,"label":"visible"}"#,
            windowFrame: screen.visibleFrame
        )
        let disconnectedHighlight = try TeachingHighlight(
            argumentsJSON: #"{"x":0.4,"y":0.4,"width":0.2,"height":0.2,"label":"invalid"}"#,
            windowFrame: CGRect(x: 1_000_000, y: 1_000_000, width: 800, height: 600)
        )

        try controller.show(visibleHighlight)
        XCTAssertThrowsError(try controller.show(disconnectedHighlight))

        XCTAssertFalse(panel.isVisible)
    }

    func testActiveSpaceChangeClearsThePointer() throws {
        let applicationCenter = NotificationCenter()
        let workspaceCenter = NotificationCenter()
        let panel = makePanel()
        let controller = TeachingPointerController(
            panel: panel,
            applicationNotificationCenter: applicationCenter,
            workspaceNotificationCenter: workspaceCenter
        )

        try controller.show(highlightOnMainScreen())
        workspaceCenter.post(name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)

        XCTAssertFalse(panel.isVisible)
    }

    func testDisplayConfigurationChangeClearsThePointer() throws {
        let applicationCenter = NotificationCenter()
        let workspaceCenter = NotificationCenter()
        let panel = makePanel()
        let controller = TeachingPointerController(
            panel: panel,
            applicationNotificationCenter: applicationCenter,
            workspaceNotificationCenter: workspaceCenter
        )

        try controller.show(highlightOnMainScreen())
        applicationCenter.post(
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        XCTAssertFalse(panel.isVisible)
    }

    private func makePanel() -> NSPanel {
        NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
    }

    private func highlightOnMainScreen() throws -> TeachingHighlight {
        let screen = try XCTUnwrap(NSScreen.main)
        return try TeachingHighlight(
            argumentsJSON: #"{"x":0.4,"y":0.4,"width":0.2,"height":0.2,"label":"target"}"#,
            windowFrame: screen.visibleFrame
        )
    }
}
