import AppKit
import CoreGraphics
@preconcurrency import ScreenCaptureKit

@MainActor
final class ActiveWindowCaptureService: WindowCaptureServing {
    private let maximumPixelDimension = 1_920
    private let imageEncoder = ScreenImageEncoder()
    private var catalogState = CaptureWindowCatalogState()

    var hasPermission: Bool {
        CGPreflightScreenCaptureAccess()
    }

    func requestPermission() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    func listWindows() async throws -> [AvailableWindow] {
        let revision = catalogState.beginListing()
        guard hasPermission else { throw ScreenCaptureError.permissionDenied }

        let content = try await shareableContent()
        guard catalogState.isCurrent(revision) else {
            throw ScreenCaptureError.windowUnavailable
        }
        let candidates = orderedCaptureableWindows(in: content.windows)
            .enumerated()
            .compactMap { element -> CaptureWindowCandidate? in
                let (rank, window) = element
                guard let application = window.owningApplication else { return nil }
                return CaptureWindowCandidate(
                    windowID: window.windowID,
                    processID: application.processID,
                    applicationName: application.applicationName,
                    title: window.title,
                    frame: window.frame,
                    layer: window.windowLayer,
                    frontToBackRank: rank
                )
            }
        let catalog = CaptureWindowCatalog(
            candidates: candidates,
            excludingProcessID: ProcessInfo.processInfo.processIdentifier,
            tokenProvider: {
                UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
            }
        )
        guard catalogState.publish(catalog, for: revision) else {
            throw ScreenCaptureError.windowUnavailable
        }
        return catalog.windows
    }

    func captureWindow(selectionID: String) async throws -> ActiveWindowSnapshot {
        guard hasPermission else {
            catalogState.invalidate()
            throw ScreenCaptureError.permissionDenied
        }
        guard let operation = catalogState.consume(selectionID: selectionID) else {
            throw ScreenCaptureError.windowUnavailable
        }

        let content = try await shareableContent()
        guard catalogState.isCurrent(operation.revision) else {
            throw ScreenCaptureError.windowUnavailable
        }
        guard let window = orderedCaptureableWindows(in: content.windows).first(where: {
            $0.windowID == operation.selection.windowID
                && $0.owningApplication?.processID == operation.selection.processID
        }) else {
            throw ScreenCaptureError.windowUnavailable
        }
        return try await capture(
            window: window,
            displays: content.displays,
            revision: operation.revision
        )
    }

    func resolveWindowFrame(context: CapturedWindowContext) async throws -> CGRect {
        guard hasPermission else { throw ScreenCaptureError.permissionDenied }
        let content: SCShareableContent
        do {
            content = try await shareableContent()
        } catch {
            throw ScreenCaptureError.windowUnavailable
        }
        guard let window = orderedCaptureableWindows(in: content.windows).first(where: {
            $0.windowID == context.windowID
                && $0.owningApplication?.processID == context.processID
        }) else {
            throw ScreenCaptureError.windowUnavailable
        }
        guard let frame = appKitFrame(for: window.frame, displays: content.displays) else {
            throw ScreenCaptureError.displayMappingFailed
        }
        return try context.revalidatedFrame(currentFrame: frame)
    }

    func invalidateWindowCatalog() {
        catalogState.invalidate()
    }

    private func shareableContent() async throws -> SCShareableContent {
        try await SCShareableContent.excludingDesktopWindows(
            true,
            onScreenWindowsOnly: true
        )
    }

    private func capture(
        window: SCWindow,
        displays: [SCDisplay],
        revision: UInt64
    ) async throws -> ActiveWindowSnapshot {
        guard catalogState.isCurrent(revision) else {
            throw ScreenCaptureError.windowUnavailable
        }
        guard let windowFrame = appKitFrame(for: window.frame, displays: displays) else {
            throw ScreenCaptureError.displayMappingFailed
        }

        let configuration = configuration(for: window.frame.size)
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )
        guard catalogState.isCurrent(revision) else {
            throw ScreenCaptureError.windowUnavailable
        }
        guard let jpegData = imageEncoder.jpegData(from: image) else {
            throw ScreenCaptureError.imageEncodingFailed
        }
        guard let processID = window.owningApplication?.processID else {
            throw ScreenCaptureError.windowUnavailable
        }

        return ActiveWindowSnapshot(
            jpegData: jpegData,
            applicationName: window.owningApplication?.applicationName
                ?? "Active application",
            windowTitle: window.title,
            windowContext: CapturedWindowContext(
                windowID: window.windowID,
                processID: processID,
                capturedFrame: windowFrame
            )
        )
    }

    private func orderedCaptureableWindows(in windows: [SCWindow]) -> [SCWindow] {
        let ownProcessID = ProcessInfo.processInfo.processIdentifier
        let candidates = Dictionary(
            uniqueKeysWithValues: windows
                .filter {
                    $0.isOnScreen
                        && $0.owningApplication != nil
                        && $0.owningApplication?.processID != ownProcessID
                        && $0.windowLayer == 0
                        && $0.frame.width >= 240
                        && $0.frame.height >= 160
                }
                .map { ($0.windowID, $0) }
        )
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        let windowInfo = CGWindowListCopyWindowInfo(options, kCGNullWindowID)
            as? [[String: Any]] ?? []

        var ordered: [SCWindow] = []
        for details in windowInfo {
            guard
                let ownerPID = details[kCGWindowOwnerPID as String] as? Int,
                let layer = details[kCGWindowLayer as String] as? Int,
                layer == 0,
                let rawID = details[kCGWindowNumber as String] as? UInt32,
                let window = candidates[CGWindowID(rawID)],
                ownerPID == Int(window.owningApplication?.processID ?? -1)
            else { continue }
            ordered.append(window)
        }
        return ordered
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

}

struct CaptureWindowCatalogState {
    private var revision: UInt64 = 0
    private var catalog: CaptureWindowCatalog?

    mutating func beginListing() -> UInt64 {
        advance()
        catalog = nil
        return revision
    }

    mutating func publish(
        _ catalog: CaptureWindowCatalog,
        for revision: UInt64
    ) -> Bool {
        guard isCurrent(revision) else { return false }
        self.catalog = catalog
        return true
    }

    mutating func consume(
        selectionID: String
    ) -> (selection: CaptureWindowSelection, revision: UInt64)? {
        let selection = catalog?.selection(for: selectionID)
        advance()
        catalog = nil
        guard let selection else { return nil }
        return (selection, revision)
    }

    mutating func invalidate() {
        advance()
        catalog = nil
    }

    func isCurrent(_ revision: UInt64) -> Bool {
        self.revision == revision
    }

    private mutating func advance() {
        revision &+= 1
    }
}

enum ScreenCaptureError: LocalizedError, Equatable {
    case permissionDenied
    case windowUnavailable
    case windowGeometryChanged
    case displayMappingFailed
    case imageEncodingFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Screen Recording permission is required for screen-aware answers."
        case .windowUnavailable:
            "That window is no longer available. List the visible windows again."
        case .windowGeometryChanged:
            "That window changed size. Capture it again before pointing."
        case .displayMappingFailed:
            "The selected window could not be mapped to a connected display."
        case .imageEncodingFailed:
            "The selected-window screenshot could not be encoded."
        }
    }
}
