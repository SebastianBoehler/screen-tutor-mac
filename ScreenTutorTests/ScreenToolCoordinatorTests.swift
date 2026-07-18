import Foundation
import XCTest
@testable import ScreenTutor

@MainActor
final class ScreenToolCoordinatorTests: XCTestCase {
    func testListReturnsMetadataAsRecoverableToolOutput() async throws {
        let service = StubWindowCaptureService()
        service.windows = [
            AvailableWindow(
                id: "opaque-window",
                applicationName: "Google Chrome",
                title: "Research notebook"
            )
        ]
        let coordinator = ScreenToolCoordinator(captureService: service)

        let resolution = try await coordinator.handle(
            functionCall(name: "list_windows", callID: "call-list")
        )
        let result = try XCTUnwrap(resolution)
        let output = try jsonObject(result.output)
        let windows = try XCTUnwrap(output["windows"] as? [[String: Any]])

        XCTAssertEqual(result.callID, "call-list")
        XCTAssertNil(result.snapshot)
        XCTAssertEqual(output["ok"] as? Bool, true)
        XCTAssertEqual(windows.first?["window_id"] as? String, "opaque-window")
        XCTAssertNil(windows.first?["process_id"])
    }

    func testCapturePassesSelectionAndReturnsSnapshot() async throws {
        let service = StubWindowCaptureService()
        service.snapshot = ActiveWindowSnapshot(
            jpegData: Data([0x01, 0x02]),
            applicationName: "JupyterLab",
            windowTitle: "Paper.ipynb",
            windowFrame: CGRect(x: 10, y: 20, width: 800, height: 600)
        )
        let coordinator = ScreenToolCoordinator(captureService: service)
        let call = functionCall(
            name: "capture_window",
            callID: "call-capture",
            arguments: #"{"window_id":"opaque-window"}"#
        )

        let resolution = try await coordinator.handle(call)
        let result = try XCTUnwrap(resolution)
        let output = try jsonObject(result.output)

        XCTAssertEqual(service.capturedWindowID, "opaque-window")
        XCTAssertEqual(result.snapshot?.jpegData, Data([0x01, 0x02]))
        XCTAssertEqual(output["ok"] as? Bool, true)
        XCTAssertEqual(output["application"] as? String, "JupyterLab")
        XCTAssertEqual(output["title"] as? String, "Paper.ipynb")
    }

    func testClosedWindowBecomesToolErrorInsteadOfThrownSessionError() async throws {
        let service = StubWindowCaptureService()
        service.captureError = ScreenCaptureError.windowUnavailable
        let coordinator = ScreenToolCoordinator(captureService: service)
        let call = functionCall(
            name: "capture_window",
            callID: "call-capture",
            arguments: #"{"window_id":"stale-window"}"#
        )

        let resolution = try await coordinator.handle(call)
        let result = try XCTUnwrap(resolution)
        let output = try jsonObject(result.output)
        let error = try XCTUnwrap(output["error"] as? [String: Any])

        XCTAssertNil(result.snapshot)
        XCTAssertEqual(output["ok"] as? Bool, false)
        XCTAssertEqual(error["code"] as? String, "window_not_available")
    }

    private func functionCall(
        name: String,
        callID: String,
        arguments: String = "{}"
    ) -> RealtimeItem {
        RealtimeItem(
            id: nil,
            type: "function_call",
            name: name,
            callID: callID,
            arguments: arguments
        )
    }

    private func jsonObject(_ json: String) throws -> [String: Any] {
        try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
        )
    }
}

@MainActor
private final class StubWindowCaptureService: WindowCaptureServing {
    var windows: [AvailableWindow] = []
    var snapshot: ActiveWindowSnapshot?
    var captureError: Error?
    private(set) var capturedWindowID: String?

    func listWindows() async throws -> [AvailableWindow] {
        windows
    }

    func captureWindow(selectionID: String) async throws -> ActiveWindowSnapshot {
        capturedWindowID = selectionID
        if let captureError { throw captureError }
        return try XCTUnwrap(snapshot)
    }

    func invalidateWindowCatalog() {}
}
