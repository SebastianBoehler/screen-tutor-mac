import CoreGraphics
import Foundation

/// Keeps model-visible control IDs scoped to the latest explicit inspection.
@MainActor
final class NativeAppService {
    private let backend: any NativeAppBackend
    private(set) var snapshot: NativeAppSnapshot?

    init(backend: any NativeAppBackend = AccessibilityAppBackend()) {
        self.backend = backend
    }

    func inspect() throws -> NativeAppSnapshot {
        invalidate()
        let state = try backend.read()
        snapshot = state
        return state
    }

    func activate(controlID: String, action: NativeControlAction) throws -> NativeAppSnapshot {
        let anchor = try anchor(controlID: controlID)
        let control = try backend.currentControl(id: controlID, in: anchor.app)
        guard control.enabled, !control.frame.isEmpty else { throw NativeAppError.disabledControl }
        guard control.actions.contains(action) else { throw NativeAppError.unsupportedAction }
        // Dispatch only once: an error during the following inspection cannot make this ID reusable.
        invalidate()
        try backend.perform(action, controlID: controlID, in: anchor.app)
        do {
            return try inspect()
        } catch {
            throw NativeAppError.unavailable(
                "The native action was dispatched, but the updated app state could not be read: \(error.localizedDescription) "
                    + "Inspect the app before deciding whether another action is needed."
            )
        }
    }

    func anchor(controlID: String) throws -> NativeOverlayAnchor {
        guard let snapshot, snapshot.controls.contains(where: { $0.id == controlID }) else {
            throw NativeAppError.staleControl
        }
        return NativeOverlayAnchor(controlID: controlID, app: snapshot.app)
    }

    func currentControl(id: String) throws -> NativeAppControl {
        let target = try anchor(controlID: id)
        return try backend.currentControl(id: id, in: target.app)
    }

    func resolve(_ anchor: NativeOverlayAnchor) -> CGRect? {
        guard snapshot?.app == anchor.app,
              snapshot?.controls.contains(where: { $0.id == anchor.controlID }) == true
        else { return nil }
        // A hidden, removed or background target must never leave a mark at its old coordinates.
        return try? backend.currentControl(id: anchor.controlID, in: anchor.app).frame
    }

    func invalidate() { snapshot = nil }
}
