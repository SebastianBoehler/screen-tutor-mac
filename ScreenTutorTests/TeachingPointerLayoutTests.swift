import AppKit
import XCTest
@testable import ScreenTutor

@MainActor
final class TeachingPointerLayoutTests: XCTestCase {
    func testConvertsGlobalAppKitCoordinatesForTheSwiftUIOverlay() {
        let layout = TeachingPointerLayout(
            globalTarget: CGPoint(x: 200, y: 250),
            screenFrame: CGRect(x: -100, y: 0, width: 1_000, height: 800),
            mouseLocation: CGPoint(x: 0, y: 700),
            previousTarget: nil
        )

        XCTAssertEqual(layout.targetPoint, CGPoint(x: 300, y: 550))
        XCTAssertEqual(layout.startPoint, CGPoint(x: 100, y: 100))
    }

    func testPreviousTutorTargetWinsWhenItIsOnTheSameScreen() {
        let layout = TeachingPointerLayout(
            globalTarget: CGPoint(x: 550, y: 350),
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
        let pointer = try TeachingPointer(
            argumentsJSON: #"{"x":0.5,"y":0.5,"label":"test target"}"#,
            windowFrame: screen.visibleFrame
        )

        try controller.show(pointer)

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
        let visiblePointer = try TeachingPointer(
            argumentsJSON: #"{"x":0.5,"y":0.5,"label":"visible"}"#,
            windowFrame: screen.visibleFrame
        )
        let disconnectedPointer = try TeachingPointer(
            argumentsJSON: #"{"x":0.5,"y":0.5,"label":"invalid"}"#,
            windowFrame: CGRect(x: 1_000_000, y: 1_000_000, width: 800, height: 600)
        )

        try controller.show(visiblePointer)
        XCTAssertThrowsError(try controller.show(disconnectedPointer))

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

    private func highlightOnMainScreen() throws -> TeachingPointer {
        let screen = try XCTUnwrap(NSScreen.main)
        return try TeachingPointer(
            argumentsJSON: #"{"x":0.5,"y":0.5,"label":"target"}"#,
            windowFrame: screen.visibleFrame
        )
    }
}
