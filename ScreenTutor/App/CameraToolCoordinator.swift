import Foundation

struct CameraToolResolution: Sendable {
    let callID: String
    let output: String
    let snapshot: CameraSnapshot?
    let succeeded: Bool
}

@MainActor
final class CameraToolCoordinator {
    private let captureService: any CameraCaptureServing
    private let encoder = JSONEncoder()

    init(captureService: any CameraCaptureServing) {
        self.captureService = captureService
    }

    func capture(callID: String) async throws -> CameraToolResolution {
        do {
            let snapshot = try await captureService.capturePhoto()
            return CameraToolResolution(
                callID: callID,
                output: try encode(
                    CameraCaptureOutput(ok: true, device: snapshot.deviceName)
                ),
                snapshot: snapshot,
                succeeded: true
            )
        } catch {
            let code = switch error {
            case CameraCaptureError.permissionDenied: "permission_denied"
            case CameraCaptureError.cameraUnavailable: "camera_unavailable"
            default: "capture_failed"
            }
            return CameraToolResolution(
                callID: callID,
                output: try encode(
                    CameraToolFailureOutput(
                        ok: false,
                        error: CameraToolError(code: code, message: error.localizedDescription)
                    )
                ),
                snapshot: nil,
                succeeded: false
            )
        }
    }

    private func encode<T: Encodable>(_ value: T) throws -> String {
        let data = try encoder.encode(value)
        guard let json = String(data: data, encoding: .utf8) else {
            throw CameraToolCoordinatorError.outputEncodingFailed
        }
        return json
    }
}

private struct CameraCaptureOutput: Encodable {
    let ok: Bool
    let device: String
}

private struct CameraToolFailureOutput: Encodable {
    let ok: Bool
    let error: CameraToolError
}

private struct CameraToolError: Encodable {
    let code: String
    let message: String
}

private enum CameraToolCoordinatorError: LocalizedError {
    case outputEncodingFailed

    var errorDescription: String? {
        "The camera tool output could not be encoded."
    }
}
