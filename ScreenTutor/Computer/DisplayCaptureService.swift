import AppKit
import CoreGraphics
@preconcurrency import ScreenCaptureKit

struct DisplaySnapshot: Sendable {
    let jpegData: Data
    /// Display bounds in CoreGraphics global points (top-left origin).
    let displayFrame: CGRect

    /// Maps a 0–1000 normalized point on the screenshot to global CG points.
    func globalPoint(normalizedX: Double, normalizedY: Double) -> CGPoint {
        CGPoint(
            x: displayFrame.minX + min(max(normalizedX, 0), 1000) / 1000 * displayFrame.width,
            y: displayFrame.minY + min(max(normalizedY, 0), 1000) / 1000 * displayFrame.height
        )
    }
}

/// Captures the display under the mouse pointer, hiding ScreenTutor's own
/// windows (HUD, board, pointer) so the agent sees only the learner's apps.
@MainActor
final class DisplayCaptureService {
    private let encoder = ScreenImageEncoder()

    func captureCurrentDisplay() async throws -> DisplaySnapshot {
        guard CGPreflightScreenCaptureAccess() else { throw ScreenCaptureError.permissionDenied }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let mouse = CGEvent(source: nil)?.location ?? .zero
        guard let display = content.displays.first(where: { $0.frame.contains(mouse) })
            ?? content.displays.first
        else { throw ScreenCaptureError.displayMappingFailed }

        let ownPID = ProcessInfo.processInfo.processIdentifier
        let ownApps = content.applications.filter { $0.processID == ownPID }
        let filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])
        let configuration = SCStreamConfiguration()
        let longest = max(display.frame.width, display.frame.height)
        let scale = min(2, 1_600 / max(longest, 1))
        configuration.width = max(1, Int(display.frame.width * scale))
        configuration.height = max(1, Int(display.frame.height * scale))
        configuration.showsCursor = true
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        guard let jpeg = encoder.jpegData(from: image) else { throw ScreenCaptureError.imageEncodingFailed }
        return DisplaySnapshot(jpegData: jpeg, displayFrame: display.frame)
    }
}
