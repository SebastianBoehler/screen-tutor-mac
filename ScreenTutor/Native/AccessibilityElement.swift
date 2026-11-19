import ApplicationServices
import Foundation

/// Typed access to the small Accessibility surface used by native tutoring.
enum AccessibilityElement {
    static func attribute<T>(_ element: AXUIElement, _ name: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? T
    }

    static func frame(_ element: AXUIElement) -> CGRect? {
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionRef) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let positionRef, let sizeRef,
              CFGetTypeID(positionRef) == AXValueGetTypeID(), CFGetTypeID(sizeRef) == AXValueGetTypeID()
        else { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionRef as! AXValue, .cgPoint, &position),
              AXValueGetValue(sizeRef as! AXValue, .cgSize, &size),
              [position.x, position.y, size.width, size.height].allSatisfy(\.isFinite),
              size.width > 0, size.height > 0
        else { return nil }
        return CGRect(origin: position, size: size)
    }

    static func actions(_ element: AXUIElement) -> [NativeControlAction] {
        var names: CFArray?
        guard AXUIElementCopyActionNames(element, &names) == .success,
              let names = names as? [String] else { return [] }
        return NativeControlAction.allCases.filter { names.contains($0.accessibilityName) }
    }

    static func isSecure(_ element: AXUIElement) -> Bool {
        let subrole: String? = attribute(element, kAXSubroleAttribute)
        let role: String? = attribute(element, kAXRoleAttribute)
        return subrole == "AXSecureTextField" || role == "AXSecureTextField"
    }

    static func label(_ element: AXUIElement) -> String {
        for name in [kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute] {
            if let text: String = attribute(element, name), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return String(text.prefix(500))
            }
        }
        return ""
    }
}
