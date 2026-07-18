import Carbon
import Foundation

@MainActor
final class GlobalHotKeyController {
    private var hotKeyReference: EventHotKeyRef?
    private var eventHandlerReference: EventHandlerRef?
    private var shortcut: GlobalHotKeyShortcut?
    private var nextHotKeyID: UInt32 = 1
    private let action: @MainActor () -> Void

    init(action: @escaping @MainActor () -> Void) {
        self.action = action
    }

    func register(_ shortcut: GlobalHotKeyShortcut) throws {
        guard self.shortcut != shortcut else { return }
        let installedHandler = eventHandlerReference == nil
        try installHandlerIfNeeded()

        var reference: EventHotKeyRef?
        let identifier = EventHotKeyID(signature: 0x53545554, id: nextHotKeyID)
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            identifier,
            GetApplicationEventTarget(),
            OptionBits(kEventHotKeyNoOptions),
            &reference
        )
        guard status == noErr, let reference else {
            if installedHandler, hotKeyReference == nil { removeHandler() }
            throw GlobalHotKeyError.registrationFailed(shortcut, status)
        }

        if let hotKeyReference { UnregisterEventHotKey(hotKeyReference) }
        hotKeyReference = reference
        self.shortcut = shortcut
        nextHotKeyID &+= 1
    }

    private func installHandlerIfNeeded() throws {
        guard eventHandlerReference == nil else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            Self.eventHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerReference
        )
        guard handlerStatus == noErr else {
            throw GlobalHotKeyError.handlerInstallationFailed(handlerStatus)
        }
    }

    func unregister() {
        if let hotKeyReference { UnregisterEventHotKey(hotKeyReference) }
        hotKeyReference = nil
        shortcut = nil
        removeHandler()
    }

    private func removeHandler() {
        if let eventHandlerReference { RemoveEventHandler(eventHandlerReference) }
        eventHandlerReference = nil
    }

    private func performAction() {
        action()
    }

    private static let eventHandler: EventHandlerUPP = { _, _, userData in
        guard let userData else { return OSStatus(eventNotHandledErr) }
        let opaquePointer = UInt(bitPattern: userData)
        Task { @MainActor in
            guard let pointer = UnsafeMutableRawPointer(bitPattern: opaquePointer) else { return }
            let controller = Unmanaged<GlobalHotKeyController>
                .fromOpaque(pointer)
                .takeUnretainedValue()
            controller.performAction()
        }
        return noErr
    }
}

enum GlobalHotKeyError: LocalizedError {
    case handlerInstallationFailed(OSStatus)
    case registrationFailed(GlobalHotKeyShortcut, OSStatus)

    var errorDescription: String? {
        switch self {
        case .handlerInstallationFailed(let status):
            "The global shortcut handler could not start (error \(status))."
        case .registrationFailed(let shortcut, let status):
            "\(shortcut.accessibilityName) could not be registered. It may already be used by "
                + "macOS or another app (error \(status))."
        }
    }
}
