import AppKit
import CoreGraphics
import ScreenCaptureKit

@MainActor
final class ActiveWindowCaptureService {
    private let maximumPixelDimension = 1_920

    var hasPermission: Bool {
        CGPreflightScreenCaptureAccess()
    }

    func requestPermission() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    func capture(processID: pid_t, applicationName: String?) async throws -> ActiveWindowSnapshot {
        guard hasPermission else { throw ScreenCaptureError.permissionDenied }

        let content = try await SCShareableContent.excludingDesktopWindows(
            true,
            onScreenWindowsOnly: true
        )
        guard let window = frontmostWindow(in: content.windows, processID: processID) else {
            throw ScreenCaptureError.noShareableWindow(applicationName)
        }
        guard let windowFrame = appKitFrame(for: window.frame, displays: content.displays) else {
            throw ScreenCaptureError.displayMappingFailed
        }

        let configuration = configuration(for: window.frame.size)
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )
        guard let jpegData = jpegData(from: image) else {
            throw ScreenCaptureError.imageEncodingFailed
        }

        return ActiveWindowSnapshot(
            jpegData: jpegData,
            applicationName: applicationName ?? window.owningApplication?.applicationName
                ?? "Active application",
            windowTitle: window.title,
            windowFrame: windowFrame
        )
    }

    private func frontmostWindow(in windows: [SCWindow], processID: pid_t) -> SCWindow? {
        let candidates = Dictionary(
            uniqueKeysWithValues: windows
                .filter {
                    $0.owningApplication?.processID == processID
                        && $0.windowLayer == 0
                        && $0.frame.width >= 240
                        && $0.frame.height >= 160
                }
                .map { ($0.windowID, $0) }
        )
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        let windowInfo = CGWindowListCopyWindowInfo(options, kCGNullWindowID)
            as? [[String: Any]] ?? []

        for details in windowInfo {
            guard
                let ownerPID = details[kCGWindowOwnerPID as String] as? Int,
                ownerPID == Int(processID),
                let layer = details[kCGWindowLayer as String] as? Int,
                layer == 0,
                let rawID = details[kCGWindowNumber as String] as? UInt32,
                let window = candidates[CGWindowID(rawID)]
            else { continue }
            return window
        }
        return nil
    }

    private func configuration(for size: CGSize) -> SCStreamConfiguration {
        let configuration = SCStreamConfiguration()
        let longestSide = max(size.width, size.height)
        let scale = min(2, CGFloat(maximumPixelDimension) / max(longestSide, 1))
        configuration.width = max(1, Int(size.width * scale))
        configuration.height = max(1, Int(size.height * scale))
        configuration.showsCursor = false
        configuration.captureResolution = .best
        return configuration
    }

    private func appKitFrame(for frame: CGRect, displays: [SCDisplay]) -> CGRect? {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        guard
            let display = displays.first(where: { $0.frame.contains(center) }),
            let screen = NSScreen.screens.first(where: { screen in
                (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
                    as? CGDirectDisplayID) == display.displayID
            })
        else { return nil }

        let localX = frame.minX - display.frame.minX
        let localTop = frame.minY - display.frame.minY
        return CGRect(
            x: screen.frame.minX + localX,
            y: screen.frame.maxY - localTop - frame.height,
            width: frame.width,
            height: frame.height
        )
    }

    private func jpegData(from image: CGImage) -> Data? {
        NSBitmapImageRep(cgImage: image).representation(
            using: .jpeg,
            properties: [.compressionFactor: 0.82]
        )
    }
}

enum ScreenCaptureError: LocalizedError {
    case permissionDenied
    case noShareableWindow(String?)
    case displayMappingFailed
    case imageEncodingFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Screen Recording permission is required for screen-aware answers."
        case .noShareableWindow(let applicationName):
            "No visible window could be captured for \(applicationName ?? "the active application")."
        case .displayMappingFailed:
            "The active window could not be mapped to a connected display."
        case .imageEncodingFailed:
            "The active-window screenshot could not be encoded."
        }
    }
}
