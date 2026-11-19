import AppKit
import XCTest
@testable import ScreenTutor

@MainActor
final class LiveOverlayTests: XCTestCase {
    func testTargetMovesAndTemporarilyDisappearsWithoutLosingIdentity() {
        let anchor = NativeOverlayAnchor(controlID: "button", app: app)
        let mark = OverlayMark(kind: .box, rect: CGRect(x: 10, y: 20, width: 80, height: 30), anchor: anchor)
        let scene = OverlayScene(marks: [mark], duration: 14)
        let moved = CGRect(x: 300, y: 400, width: 100, height: 40)
        let visible = LiveOverlayTracking.refreshed(scene) { _ in moved }
        XCTAssertEqual(visible.marks[0].rect, moved)
        XCTAssertEqual(visible.marks[0].id, mark.id)
        XCTAssertEqual(visible.duration, scene.duration)
        XCTAssertTrue(LiveOverlayTracking.refreshed(scene) { _ in nil }.marks.isEmpty)
        XCTAssertEqual(LiveOverlayTracking.refreshed(scene) { _ in moved }.marks[0].id, mark.id)
    }

    func testMissingNativeTargetDoesNotRemoveIndependentVisualMarks() {
        let native = OverlayMark(kind: .arrow, rect: .zero, anchor: NativeOverlayAnchor(controlID: "gone", app: app))
        let visual = OverlayMark(kind: .circle, rect: CGRect(x: 20, y: 30, width: 60, height: 40))
        let scene = LiveOverlayTracking.refreshed(OverlayScene(marks: [native, visual], duration: 12)) { _ in nil }
        XCTAssertEqual(scene.marks, [visual])
    }

    func testControllerReusesPanelAndHostingViewWhenTargetMoves() throws {
        let screen = try XCTUnwrap(NSScreen.screens.first)
        let frame = CGDisplayBounds(try XCTUnwrap(screen.displayID))
        var target: CGRect? = CGRect(x: frame.minX + 100, y: frame.minY + 100, width: 80, height: 30)
        let controller = OverlayController()
        controller.resolveAnchor = { _ in target }
        controller.show(OverlayScene(marks: [OverlayMark(kind: .box, rect: try XCTUnwrap(target),
            anchor: NativeOverlayAnchor(controlID: "button", app: app))], duration: 30))
        defer { controller.clear() }
        let panel = try XCTUnwrap(NSApp.windows.first { $0 is NSPanel && $0.isVisible && $0.frame == screen.frame })
        let content = try XCTUnwrap(panel.contentView)
        target = target?.offsetBy(dx: 50, dy: 80)
        controller.refreshAnchors()
        XCTAssertTrue(panel.contentView === content)
        XCTAssertEqual(controller.current?.marks.first?.rect, target)
        target = nil
        controller.refreshAnchors()
        XCTAssertFalse(panel.isVisible)
        target = CGRect(x: frame.minX + 200, y: frame.minY + 200, width: 80, height: 30)
        controller.refreshAnchors()
        XCTAssertTrue(panel.isVisible)
        controller.clear()
        controller.refreshAnchors()
        XCTAssertNil(controller.current)
        XCTAssertFalse(panel.isVisible)
    }

    func testTrackingDoesNotExtendExpiry() async throws {
        let controller = OverlayController()
        let target = CGRect(x: 100, y: 100, width: 80, height: 30)
        controller.resolveAnchor = { _ in target }
        controller.show(OverlayScene(marks: [OverlayMark(kind: .box, rect: target,
            anchor: NativeOverlayAnchor(controlID: "button", app: app))], duration: 0.02))
        defer { controller.clear() }
        try await Task.sleep(for: .milliseconds(550))
        XCTAssertNil(controller.current)
    }

    func testLateAnnotationCannotReplaceClearedOrNewerMarks() {
        let controller = OverlayController()
        let revision = controller.revision
        let scene = OverlayScene(marks: [OverlayMark(kind: .box,
            rect: CGRect(x: 100, y: 100, width: 80, height: 30))], duration: 30)
        controller.clear()
        XCTAssertFalse(controller.show(scene, ifRevisionMatches: revision))
        XCTAssertNil(controller.current)
        XCTAssertTrue(controller.show(scene, ifRevisionMatches: controller.revision))
        let current = controller.current
        XCTAssertFalse(controller.show(scene, ifRevisionMatches: revision))
        XCTAssertEqual(controller.current, current)
        controller.clear()
    }

    private var app: NativeAppIdentity {
        NativeAppIdentity(processID: 42, windowToken: "window", application: "Preview", windowTitle: "Lecture")
    }
}
