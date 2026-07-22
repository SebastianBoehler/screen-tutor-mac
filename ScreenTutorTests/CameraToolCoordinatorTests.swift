import Foundation
import XCTest
@testable import ScreenTutor

@MainActor
final class CameraToolCoordinatorTests: XCTestCase {
    func testCaptureReturnsBoundedPhotoAndDeviceMetadata() async throws {
        let service = StubCameraCaptureService()
        service.snapshot = CameraSnapshot(
            jpegData: Data([0x01, 0x02]),
            deviceName: "FaceTime HD Camera"
        )
        let coordinator = CameraToolCoordinator(captureService: service)

        let resolution = try await coordinator.capture(callID: "call-camera")
        let output = try jsonObject(resolution.output)

        XCTAssertTrue(resolution.succeeded)
        XCTAssertEqual(resolution.snapshot?.jpegData, Data([0x01, 0x02]))
        XCTAssertEqual(output["ok"] as? Bool, true)
        XCTAssertEqual(output["device"] as? String, "FaceTime HD Camera")
    }

    func testDeniedPermissionIsRecoverableToolFailure() async throws {
        let service = StubCameraCaptureService()
        service.error = CameraCaptureError.permissionDenied
        let coordinator = CameraToolCoordinator(captureService: service)

        let resolution = try await coordinator.capture(callID: "call-camera")
        let output = try jsonObject(resolution.output)
        let error = try XCTUnwrap(output["error"] as? [String: Any])

        XCTAssertFalse(resolution.succeeded)
        XCTAssertNil(resolution.snapshot)
        XCTAssertEqual(error["code"] as? String, "permission_denied")
    }

    private func jsonObject(_ json: String) throws -> [String: Any] {
        try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
        )
    }
}

@MainActor
private final class StubCameraCaptureService: CameraCaptureServing {
    var snapshot: CameraSnapshot?
    var error: Error?

    func capturePhoto() async throws -> CameraSnapshot {
        if let error { throw error }
        return try XCTUnwrap(snapshot)
    }
}
