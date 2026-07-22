@preconcurrency import AVFoundation

@MainActor
enum CameraPermissionService {
    static var isGranted: Bool {
        AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    static var canRequest: Bool {
        AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined
    }

    static func request() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }
}
