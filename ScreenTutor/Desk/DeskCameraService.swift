@preconcurrency import AVFoundation
import CoreImage
import Foundation
import Observation

struct DeskCameraDevice: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let kind: String
}

enum DeskRotation: Int, CaseIterable, Identifiable, Sendable {
    case none = 0
    case clockwise90 = 90
    case upsideDown = 180
    case counterClockwise90 = 270

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .none: "Upright"
        case .clockwise90: "Rotate 90° right"
        case .upsideDown: "Rotate 180°"
        case .counterClockwise90: "Rotate 90° left"
        }
    }

    var orientation: CGImagePropertyOrientation {
        switch self {
        case .none: .up
        case .clockwise90: .right
        case .upsideDown: .down
        case .counterClockwise90: .left
        }
    }
}

/// Keeps one continuous capture session running for an overhead desk camera
/// (an iPhone through Continuity Camera or Desk View, a USB document camera, or
/// the built-in camera). Frames stay on the Mac; callers pull the newest frame
/// when the observer or the tutor needs one.
@MainActor
@Observable
final class DeskCameraService {
    private(set) var devices: [DeskCameraDevice] = []
    private(set) var isRunning = false
    private(set) var isStarting = false
    private(set) var activeDeviceName: String?
    private(set) var previewImage: CGImage?
    private(set) var errorMessage: String?
    private(set) var selectedDeviceID: String?
    private(set) var rotation: DeskRotation

    @ObservationIgnored private let sink = DeskFrameSink()
    @ObservationIgnored private let encoder = ScreenImageEncoder()
    @ObservationIgnored private var session: AVCaptureSession?
    @ObservationIgnored private var previewTask: Task<Void, Never>?
    @ObservationIgnored private let queue = DispatchQueue(
        label: "com.sebastianboehler.ScreenTutor.desk-camera"
    )
    @ObservationIgnored private let userDefaults: UserDefaults

    private static let deviceKey = "com.sebastianboehler.ScreenTutor.deskCameraDevice"
    private static let rotationKey = "com.sebastianboehler.ScreenTutor.deskCameraRotation"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        selectedDeviceID = userDefaults.string(forKey: Self.deviceKey)
        rotation = DeskRotation(rawValue: userDefaults.integer(forKey: Self.rotationKey)) ?? .none
        sink.setRotation(rotation)
    }

    func refreshDevices() {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.continuityCamera, .deskViewCamera, .external, .builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        )
        devices = discovery.devices.map { device in
            DeskCameraDevice(
                id: device.uniqueID,
                name: device.localizedName,
                kind: Self.kind(of: device)
            )
        }
        if selectedDeviceID == nil || !devices.contains(where: { $0.id == selectedDeviceID }) {
            // Prefer a phone or Desk View over the built-in display camera.
            selectedDeviceID = devices.first { $0.kind != "Built-in" }?.id ?? devices.first?.id
        }
    }

    func selectDevice(_ id: String) {
        selectedDeviceID = id
        userDefaults.set(id, forKey: Self.deviceKey)
        guard isRunning else { return }
        Task {
            stop()
            await start()
        }
    }

    func setRotation(_ rotation: DeskRotation) {
        self.rotation = rotation
        userDefaults.set(rotation.rawValue, forKey: Self.rotationKey)
        sink.setRotation(rotation)
    }

    func start() async {
        guard !isRunning, !isStarting else { return }
        isStarting = true
        defer { isStarting = false }
        errorMessage = nil
        guard await CameraPermissionService.request() else {
            errorMessage = "Camera access is disabled. Enable ScreenTutor in Privacy & Security > Camera."
            return
        }
        refreshDevices()
        guard
            let id = selectedDeviceID,
            let device = AVCaptureDevice(uniqueID: id)
        else {
            errorMessage = "No camera found. Connect your iPhone (Continuity Camera) or a USB camera."
            return
        }

        let session = AVCaptureSession()
        do {
            let input = try AVCaptureDeviceInput(device: device)
            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            output.setSampleBufferDelegate(sink, queue: queue)
            session.beginConfiguration()
            if session.canSetSessionPreset(.hd1920x1080) {
                session.sessionPreset = .hd1920x1080
            } else {
                session.sessionPreset = .high
            }
            guard session.canAddInput(input), session.canAddOutput(output) else {
                session.commitConfiguration()
                errorMessage = "\(device.localizedName) could not be configured for video."
                return
            }
            session.addInput(input)
            session.addOutput(output)
            session.commitConfiguration()
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        sink.reset()
        let runner = DeskSessionRunner(session: session, queue: queue)
        await runner.start()
        self.session = session
        activeDeviceName = device.localizedName
        isRunning = true
        startPreviewUpdates()
    }

    func stop() {
        previewTask?.cancel()
        previewTask = nil
        if let session {
            let runner = DeskSessionRunner(session: session, queue: queue)
            Task { await runner.stop() }
        }
        session = nil
        isRunning = false
        activeDeviceName = nil
        previewImage = nil
        sink.reset()
    }

    /// Newest rotated frame and its capture time.
    func latestFrame() -> (image: CGImage, capturedAt: Date)? {
        sink.latest()
    }

    /// Starts the camera if necessary and waits briefly for the first frame.
    func currentSnapshot() async throws -> CameraSnapshot {
        if !isRunning { await start() }
        guard isRunning else {
            throw DeskCameraError.unavailable(errorMessage ?? "The desk camera is not running.")
        }
        for _ in 0..<40 {
            if let frame = latestFrame(), let jpeg = encoder.jpegData(from: frame.image) {
                return CameraSnapshot(jpegData: jpeg, deviceName: activeDeviceName ?? "Desk camera")
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw DeskCameraError.noFrame
    }

    func jpegData(for image: CGImage) -> Data? {
        encoder.jpegData(from: image)
    }

    private func startPreviewUpdates() {
        previewTask?.cancel()
        previewTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if let frame = self.sink.latest() { self.previewImage = frame.image }
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
    }

    private static func kind(of device: AVCaptureDevice) -> String {
        switch device.deviceType {
        case .continuityCamera: "iPhone"
        case .deskViewCamera: "Desk View"
        case .external: "External"
        default: "Built-in"
        }
    }
}

enum DeskCameraError: LocalizedError {
    case unavailable(String)
    case noFrame

    var errorDescription: String? {
        switch self {
        case .unavailable(let message): message
        case .noFrame: "The desk camera did not deliver a frame yet."
        }
    }
}

private final class DeskSessionRunner: @unchecked Sendable {
    private let session: AVCaptureSession
    private let queue: DispatchQueue

    init(session: AVCaptureSession, queue: DispatchQueue) {
        self.session = session
        self.queue = queue
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

/// Receives camera frames on the capture queue and keeps only the newest one,
/// converted and rotated at most a few times per second.
final class DeskFrameSink: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate,
    @unchecked Sendable
{
    private let lock = NSLock()
    private let context = CIContext(options: [.cacheIntermediates: false])
    private var image: CGImage?
    private var capturedAt: Date?
    private var lastConversion = Date.distantPast
    private var orientation: CGImagePropertyOrientation = .up
    private let minimumInterval: TimeInterval = 0.2

    func setRotation(_ rotation: DeskRotation) {
        lock.withLock { orientation = rotation.orientation }
    }

    func reset() {
        lock.withLock {
            image = nil
            capturedAt = nil
            lastConversion = .distantPast
        }
    }

    func latest() -> (image: CGImage, capturedAt: Date)? {
        lock.withLock {
            guard let image, let capturedAt else { return nil }
            return (image, capturedAt)
        }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = Date()
        let orientation: CGImagePropertyOrientation? = lock.withLock {
            guard now.timeIntervalSince(lastConversion) >= minimumInterval else { return nil }
            lastConversion = now
            return self.orientation
        }
        guard
            let orientation,
            let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer).oriented(orientation)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        lock.withLock {
            image = cgImage
            capturedAt = now
        }
    }
}
