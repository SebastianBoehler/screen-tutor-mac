import AppKit
import ApplicationServices
import XCTest
@testable import ScreenTutor

@MainActor
final class NativeAccessibilityLiveTests: XCTestCase {
    func testNativeActionAndOverlayTrackWindowAndScrollViewport() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["NATIVE_LIVE"] == "1",
                          "Set TEST_RUNNER_NATIVE_LIVE=1 for the disposable native app test.")
        try XCTSkipUnless(AXIsProcessTrusted(), "The test host needs macOS Accessibility permission.")
        let fixtureURL = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("NativeStudyFixture.app")
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = true
        let fixture = try await NSWorkspace.shared.openApplication(at: fixtureURL, configuration: configuration)
        let backend = AccessibilityAppBackend()
        let service = NativeAppService(backend: backend)
        let overlay = OverlayController()
        overlay.resolveAnchor = { service.resolve($0) }
        defer {
            overlay.clear()
            fixture.terminate()
        }
        try await waitUntil { NSWorkspace.shared.frontmostApplication?.processIdentifier == fixture.processIdentifier }
        var state = try service.inspect()
        XCTAssertEqual(state.app.windowTitle, "Native Study Fixture")
        let check = try control("Check step", in: state)
        state = try service.activate(controlID: check.id, action: .press)
        try await waitUntil {
            state = try service.inspect()
            return state.controls.contains { $0.label == "Next step is yours" }
        }
        let target = try control("Learning target: update rule", in: state)
        // Keep the backend anchor alive while a separate inspection/action service navigates.
        let anchor = try service.anchor(controlID: target.id)
        overlay.show(OverlayScene(marks: [OverlayMark(kind: .underline, rect: target.frame,
            label: "Explain this step", anchor: anchor)], duration: 30))
        let navigation = NativeAppService()
        try activate("Move window", using: navigation)
        try await waitUntil {
            overlay.refreshAnchors()
            return overlay.current?.marks.first?.rect.minX == target.frame.minX + 80
        }
        try activate("Scroll target away", using: navigation)
        try await waitUntil {
            overlay.refreshAnchors()
            return overlay.current?.marks.isEmpty == true
        }
        try activate("Return to target", using: navigation)
        try await waitUntil {
            overlay.refreshAnchors()
            return overlay.current?.marks.first?.id != nil
        }
        print("NATIVE_LIVE: native press verified; overlay followed window movement, hid outside the scroll viewport, and returned with the target.")
    }

    private func control(_ label: String, in snapshot: NativeAppSnapshot) throws -> NativeAppControl {
        try XCTUnwrap(snapshot.controls.first { $0.label == label }, "Missing native control: \(label)")
    }

    private func activate(_ label: String, using service: NativeAppService) throws {
        let state = try service.inspect()
        _ = try service.activate(controlID: control(label, in: state).id, action: .press)
    }

    private func waitUntil(_ condition: () throws -> Bool) async throws {
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if try condition() { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTFail("Native study app did not reach the expected state within five seconds.")
    }
}
