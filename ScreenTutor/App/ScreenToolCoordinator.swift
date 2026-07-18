import Foundation

@MainActor
protocol WindowCaptureServing: AnyObject {
    func listWindows() async throws -> [AvailableWindow]
    func captureWindow(selectionID: String) async throws -> ActiveWindowSnapshot
    func resolveWindowFrame(context: CapturedWindowContext) async throws -> CGRect
    func invalidateWindowCatalog()
}

struct ScreenToolResolution: Sendable {
    let callID: String
    let output: String
    let snapshot: ActiveWindowSnapshot?
    let succeeded: Bool
}

@MainActor
final class ScreenToolCoordinator {
    private let captureService: any WindowCaptureServing
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(captureService: any WindowCaptureServing) {
        self.captureService = captureService
    }

    func handle(_ item: RealtimeItem) async throws -> ScreenToolResolution? {
        guard item.type == "function_call", let name = item.name, let callID = item.callID else {
            throw ScreenToolCoordinatorError.invalidFunctionCall
        }

        switch name {
        case "list_windows":
            return try await listWindows(callID: callID)
        case "capture_window":
            return try await captureWindow(item.arguments, callID: callID)
        default:
            return nil
        }
    }

    func invalidateWindowCatalog() {
        captureService.invalidateWindowCatalog()
    }

    func resolveWindowFrame(for context: CapturedWindowContext) async throws -> CGRect {
        try await captureService.resolveWindowFrame(context: context)
    }

    private func listWindows(callID: String) async throws -> ScreenToolResolution {
        do {
            let windows = try await captureService.listWindows()
            return ScreenToolResolution(
                callID: callID,
                output: try encode(WindowListOutput(ok: true, windows: windows)),
                snapshot: nil,
                succeeded: true
            )
        } catch {
            return try failure(error, callID: callID)
        }
    }

    private func captureWindow(
        _ argumentsJSON: String?,
        callID: String
    ) async throws -> ScreenToolResolution {
        do {
            guard let argumentsJSON else { throw ScreenToolCoordinatorError.invalidArguments }
            let arguments = try decoder.decode(
                CaptureWindowArguments.self,
                from: Data(argumentsJSON.utf8)
            )
            let snapshot = try await captureService.captureWindow(
                selectionID: arguments.windowID
            )
            return ScreenToolResolution(
                callID: callID,
                output: try encode(
                    WindowCaptureOutput(
                        ok: true,
                        applicationName: snapshot.applicationName,
                        title: snapshot.windowTitle
                    )
                ),
                snapshot: snapshot,
                succeeded: true
            )
        } catch {
            return try failure(error, callID: callID)
        }
    }

    private func failure(_ error: Error, callID: String) throws -> ScreenToolResolution {
        let code: String
        switch error {
        case ScreenCaptureError.permissionDenied:
            code = "permission_denied"
        case ScreenCaptureError.windowUnavailable:
            code = "window_not_available"
        case is DecodingError, ScreenToolCoordinatorError.invalidArguments:
            code = "invalid_arguments"
        default:
            code = "capture_failed"
        }
        let output = WindowToolFailureOutput(
            ok: false,
            error: WindowToolError(code: code, message: error.localizedDescription)
        )
        return ScreenToolResolution(
            callID: callID,
            output: try encode(output),
            snapshot: nil,
            succeeded: false
        )
    }

    private func encode<T: Encodable>(_ value: T) throws -> String {
        let data = try encoder.encode(value)
        guard let json = String(data: data, encoding: .utf8) else {
            throw ScreenToolCoordinatorError.outputEncodingFailed
        }
        return json
    }
}

private struct WindowListOutput: Encodable {
    let ok: Bool
    let windows: [AvailableWindow]
}

private struct WindowCaptureOutput: Encodable {
    let ok: Bool
    let applicationName: String
    let title: String?

    enum CodingKeys: String, CodingKey {
        case ok, title
        case applicationName = "application"
    }
}

private struct WindowToolFailureOutput: Encodable {
    let ok: Bool
    let error: WindowToolError
}

private struct WindowToolError: Encodable {
    let code: String
    let message: String
}

private enum ScreenToolCoordinatorError: LocalizedError {
    case invalidFunctionCall
    case invalidArguments
    case outputEncodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidFunctionCall: "The Realtime tool call was incomplete."
        case .invalidArguments: "The window tool arguments were invalid."
        case .outputEncodingFailed: "The window tool output could not be encoded."
        }
    }
}
