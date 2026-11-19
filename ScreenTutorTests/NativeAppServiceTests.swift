import CoreGraphics
import XCTest
@testable import ScreenTutor

@MainActor
final class NativeAppServiceTests: XCTestCase {
    func testActionUsesLatestControlAndReturnsFreshState() throws {
        let backend = NativeBackendFixture()
        let service = NativeAppService(backend: backend)
        let first = try service.inspect()
        let after = try service.activate(controlID: first.controls[0].id, action: .press)
        XCTAssertEqual(backend.actions, [.press])
        XCTAssertEqual(after.controls[0].label, "Page 2")
        XCTAssertThrowsError(try service.activate(controlID: first.controls[0].id, action: .press))
        XCTAssertEqual(backend.actions.count, 1)
    }

    func testChangedFocusRejectsActionWithoutDispatch() throws {
        let backend = NativeBackendFixture()
        let service = NativeAppService(backend: backend)
        let state = try service.inspect()
        backend.isCurrent = false
        XCTAssertThrowsError(try service.activate(controlID: state.controls[0].id, action: .press))
        XCTAssertTrue(backend.actions.isEmpty)
    }

    func testDisabledAndUnsupportedControlsDoNotDispatch() throws {
        let backend = NativeBackendFixture()
        let service = NativeAppService(backend: backend)
        let state = try service.inspect()
        backend.enabled = false
        XCTAssertThrowsError(try service.activate(controlID: state.controls[0].id, action: .press))
        backend.enabled = true
        XCTAssertThrowsError(try service.activate(controlID: state.controls[0].id, action: .increment))
        XCTAssertTrue(backend.actions.isEmpty)
    }

    func testAnchorUsesLiveFrameAndHidesWhenFocusChanges() throws {
        let backend = NativeBackendFixture()
        let service = NativeAppService(backend: backend)
        let state = try service.inspect()
        let anchor = try service.anchor(controlID: state.controls[0].id)
        backend.rect.origin.y += 200
        XCTAssertEqual(service.resolve(anchor), backend.rect)
        backend.isCurrent = false
        XCTAssertNil(service.resolve(anchor))
        backend.isCurrent = true
        XCTAssertEqual(service.resolve(anchor), backend.rect)
        service.invalidate()
        XCTAssertNil(service.resolve(anchor))
    }

    func testPostActionReadFailureDoesNotPermitRepeatingAnOldAction() throws {
        let backend = NativeBackendFixture()
        let service = NativeAppService(backend: backend)
        let state = try service.inspect()
        backend.failRead = true
        XCTAssertThrowsError(try service.activate(controlID: state.controls[0].id, action: .press))
        XCTAssertThrowsError(try service.activate(controlID: state.controls[0].id, action: .press))
        XCTAssertEqual(backend.actions.count, 1)
    }
}

@MainActor
final class NativeBackendFixture: NativeAppBackend {
    let app = NativeAppIdentity(processID: 42, windowToken: "window", application: "Preview", windowTitle: "Lecture")
    var isCurrent = true
    var enabled = true
    var rect = CGRect(x: 100, y: 120, width: 160, height: 40)
    var actions: [NativeControlAction] = []
    var reads = 0
    var failRead = false

    func read() throws -> NativeAppSnapshot {
        if failRead { throw NativeAppError.unavailable("Fixture read failed") }
        reads += 1
        return NativeAppSnapshot(app: app, controls: [control(id: "read-\(reads)")], selectedText: nil, truncated: false)
    }

    func currentControl(id: String, in app: NativeAppIdentity) throws -> NativeAppControl {
        guard isCurrent else { throw NativeAppError.focusChanged }
        return control(id: id)
    }

    func perform(_ action: NativeControlAction, controlID: String, in app: NativeAppIdentity) throws {
        actions.append(action)
    }

    private func control(id: String) -> NativeAppControl {
        NativeAppControl(id: id, role: "AXButton", label: actions.isEmpty ? "Next page" : "Page 2",
                         frame: rect, enabled: enabled, actions: [.press])
    }
}
