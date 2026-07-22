@preconcurrency import AVFoundation
import CoreGraphics
import Foundation
import ImageIO

@MainActor
protocol CameraCaptureServing: AnyObject {
    func capturePhoto() async throws -> CameraSnapshot
}

@MainActor
final class CameraCaptureService: CameraCaptureServing {
    private let imageEncoder = ScreenImageEncoder()
    private var activeDelegate: CameraPhotoDelegate?

    func capturePhoto() async throws -> CameraSnapshot {
        guard await CameraPermissionService.request() else {
            throw CameraCaptureError.permissionDenied
        }
        guard let device = AVCaptureDevice.default(for: .video) else {
            throw CameraCaptureError.cameraUnavailable
        }

        let session = AVCaptureSession()
        let input = try AVCaptureDeviceInput(device: device)
        let output = AVCapturePhotoOutput()
        session.beginConfiguration()
        session.sessionPreset = .photo
        guard session.canAddInput(input), session.canAddOutput(output) else {
            session.commitConfiguration()
            throw CameraCaptureError.configurationFailed
        }
        session.addInput(input)
        session.addOutput(output)
        session.commitConfiguration()
        let runner = CameraSessionRunner(session: session)
        await runner.start()

        let sourceData: Data
        do {
            sourceData = try await capturePhotoData(from: output)
        } catch {
            await runner.stop()
            throw error
        }
        await runner.stop()
        guard
            let source = CGImageSourceCreateWithData(sourceData as CFData, nil),
            let image = CGImageSourceCreateThumbnailAtIndex(
                source,
                0,
                [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 1_920
                ] as CFDictionary
            ),
            let jpegData = imageEncoder.jpegData(from: image)
        else {
            throw CameraCaptureError.imageEncodingFailed
        }
        return CameraSnapshot(jpegData: jpegData, deviceName: device.localizedName)
    }

    private func capturePhotoData(from output: AVCapturePhotoOutput) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            let delegate = CameraPhotoDelegate { [weak self] result in
                continuation.resume(with: result)
                Task { @MainActor in self?.activeDelegate = nil }
            }
            activeDelegate = delegate
            output.capturePhoto(with: AVCapturePhotoSettings(), delegate: delegate)
        }
    }
}

private final class CameraSessionRunner: @unchecked Sendable {
    private let session: AVCaptureSession
    private let queue = DispatchQueue(label: "com.sebastianboehler.ScreenTutor.camera")

    init(session: AVCaptureSession) {
        self.session = session
    }

    func start() async {
        await withCheckedContinuation { continuation in
            queue.async { [session] in
                session.startRunning()
                continuation.resume()
            }
        }
    }

    func stop() async {
        await withCheckedContinuation { continuation in
            queue.async { [session] in
                session.stopRunning()
                continuation.resume()
            }
        }
    }
}

private final class CameraPhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate,
    @unchecked Sendable
{
    private let completion: @Sendable (Result<Data, Error>) -> Void
    private var result: Result<Data, Error>?

    init(completion: @escaping @Sendable (Result<Data, Error>) -> Void) {
        self.completion = completion
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            result = .failure(error)
        } else if let data = photo.fileDataRepresentation() {
            result = .success(data)
        } else {
            result = .failure(CameraCaptureError.captureFailed)
        }
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
        error: Error?
    ) {
        if let error { completion(.failure(error)); return }
        completion(result ?? .failure(CameraCaptureError.captureFailed))
    }
}

enum CameraCaptureError: LocalizedError {
    case permissionDenied
    case cameraUnavailable
    case configurationFailed
    case captureFailed
    case imageEncodingFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Camera permission is required to take a photo."
        case .cameraUnavailable:
            "No camera is currently available."
        case .configurationFailed:
            "The camera could not be configured for a still photo."
        case .captureFailed:
            "The camera did not return a photo."
        case .imageEncodingFailed:
            "The camera photo could not be encoded."
        }
    }
}
