import AppKit
import ApplicationServices

/// Resolves actual AX objects; screen coordinates are never used to activate a control.
@MainActor
final class AccessibilityAppBackend: NativeAppBackend {
    private struct Entry {
        let element: AXUIElement
        let role: String
        let label: String
    }
    private var entries: [String: Entry] = [:]
    private var window: AXUIElement?
    private var identity: NativeAppIdentity?

    func read() throws -> NativeAppSnapshot {
        entries.removeAll()
        identity = nil
        let (app, focusedWindow) = try focusedApp()
        let identity = NativeAppIdentity(
            processID: app.processIdentifier,
            windowToken: UUID().uuidString,
            application: app.localizedName ?? app.bundleIdentifier ?? "Mac app",
            windowTitle: AccessibilityElement.attribute(focusedWindow, kAXTitleAttribute) ?? ""
        )
        self.identity = identity
        window = focusedWindow
        var queue: [(AXUIElement, Int)] = [(focusedWindow, 0)]
        var index = 0
        var controls: [NativeAppControl] = []
        let roles: Set<String> = [
            "AXButton", "AXLink", "AXTextField", "AXTextArea", "AXCheckBox", "AXRadioButton",
            "AXPopUpButton", "AXTab", "AXMenuItem", "AXMenuButton", "AXSlider", "AXImage",
            "AXHeading", "AXComboBox", "AXSearchField", "AXStaticText", "AXRow", "AXCell"
        ]
        while index < queue.count, index < 800, controls.count < 120 {
            let (element, depth) = queue[index]
            index += 1
            guard !AccessibilityElement.isSecure(element) else { continue }
            if let role: String = AccessibilityElement.attribute(element, kAXRoleAttribute), roles.contains(role) {
                let label = AccessibilityElement.label(element)
                if !label.isEmpty, let frame = visibleFrame(element, window: focusedWindow) {
                    let id = "native-\(UUID().uuidString)"
                    entries[id] = Entry(element: element, role: role, label: label)
                    controls.append(control(id: id, element: element, role: role, label: label, frame: frame))
                }
            }
            if depth < 30, let children: [AXUIElement] = AccessibilityElement.attribute(element, kAXChildrenAttribute) {
                queue.append(contentsOf: children.map { ($0, depth + 1) })
            }
        }
        let root = AXUIElementCreateApplication(app.processIdentifier)
        let focused: AXUIElement? = AccessibilityElement.attribute(root, kAXFocusedUIElementAttribute)
        let selection: String? = focused.flatMap { element in
            guard !AccessibilityElement.isSecure(element) else { return nil }
            return AccessibilityElement.attribute(element, kAXSelectedTextAttribute)
        }
        return NativeAppSnapshot(app: identity, controls: controls,
                                 selectedText: selection.map { String($0.prefix(2_000)) }, truncated: index < queue.count)
    }

    func currentControl(id: String, in app: NativeAppIdentity) throws -> NativeAppControl {
        guard identity == app, let entry = entries[id], let window else { throw NativeAppError.staleControl }
        let (frontmost, focusedWindow) = try focusedApp()
        guard frontmost.processIdentifier == app.processID, CFEqual(focusedWindow, window) else {
            throw NativeAppError.focusChanged
        }
        guard !AccessibilityElement.isSecure(entry.element),
              let role: String = AccessibilityElement.attribute(entry.element, kAXRoleAttribute), role == entry.role,
              AccessibilityElement.label(entry.element) == entry.label
        else { throw NativeAppError.staleControl }
        guard let frame = visibleFrame(entry.element, window: window) else { throw NativeAppError.disabledControl }
        return control(id: id, element: entry.element, role: role, label: entry.label, frame: frame)
    }

    func perform(_ action: NativeControlAction, controlID: String, in app: NativeAppIdentity) throws {
        let current = try currentControl(id: controlID, in: app)
        guard current.enabled else { throw NativeAppError.disabledControl }
        guard current.actions.contains(action), let entry = entries[controlID] else { throw NativeAppError.unsupportedAction }
        let status = AXUIElementPerformAction(entry.element, action.accessibilityName as CFString)
        guard status == .success else {
            throw NativeAppError.unavailable("macOS rejected the native action (Accessibility error \(status.rawValue)).")
        }
    }

    private func focusedApp() throws -> (NSRunningApplication, AXUIElement) {
        guard AXIsProcessTrusted() else { throw NativeAppError.permissionDenied }
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier
        else { throw NativeAppError.noWindow }
        let root = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 0.15)
        guard let window: AXUIElement = AccessibilityElement.attribute(root, kAXFocusedWindowAttribute) else {
            throw NativeAppError.noWindow
        }
        return (app, window)
    }

    private func control(id: String, element: AXUIElement, role: String, label: String, frame: CGRect) -> NativeAppControl {
        NativeAppControl(id: id, role: role, label: label, frame: frame,
                         enabled: AccessibilityElement.attribute(element, kAXEnabledAttribute) ?? true,
                         actions: AccessibilityElement.actions(element))
    }

    private func visibleFrame(_ element: AXUIElement, window: AXUIElement) -> CGRect? {
        guard let rect = AccessibilityElement.frame(element), let windowFrame = AccessibilityElement.frame(window),
              AccessibilityElement.attribute(window, kAXMinimizedAttribute) as Bool? != true,
              AccessibilityElement.attribute(element, "AXHidden") as Bool? != true
        else { return nil }
        var clipped = rect.intersection(windowFrame)
        // Intersect scroll-area ancestors so offscreen content cannot retain a visible mark.
        var parent: AXUIElement? = AccessibilityElement.attribute(element, kAXParentAttribute)
        for _ in 0..<30 {
            guard let ancestor = parent, !CFEqual(ancestor, window) else { break }
            let role: String? = AccessibilityElement.attribute(ancestor, kAXRoleAttribute)
            if role == "AXScrollArea", let viewport = AccessibilityElement.frame(ancestor) {
                clipped = clipped.intersection(viewport)
            }
            parent = AccessibilityElement.attribute(ancestor, kAXParentAttribute)
        }
        return !clipped.isNull && clipped.width >= 2 && clipped.height >= 2 ? clipped : nil
    }
}
