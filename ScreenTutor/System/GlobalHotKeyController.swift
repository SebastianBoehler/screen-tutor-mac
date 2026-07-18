import Carbon
import Foundation

@MainActor
final class GlobalHotKeyController {
    private var hotKeyReference: EventHotKeyRef?
    private var eventHandlerReference: EventHandlerRef?
    private let action: @MainActor () -> Void

    init(action: @escaping @MainActor () -> Void) {
        self.action = action
    }

    func register() throws {
        guard hotKeyReference == nil else { return }

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
            throw GlobalHotKeyError.registrationFailed(handlerStatus)
        }

        var reference: EventHotKeyRef?
        let identifier = EventHotKeyID(signature: 0x53545554, id: 1)
        let hotKeyStatus = RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(cmdKey | shiftKey),
            identifier,
            GetApplicationEventTarget(),
            OptionBits(kEventHotKeyNoOptions),
            &reference
        )
        guard hotKeyStatus == noErr, let reference else {
            if let eventHandlerReference { RemoveEventHandler(eventHandlerReference) }
            eventHandlerReference = nil
            throw GlobalHotKeyError.registrationFailed(hotKeyStatus)
        }
        hotKeyReference = reference
    }

    func unregister() {
        if let hotKeyReference { UnregisterEventHotKey(hotKeyReference) }
        if let eventHandlerReference { RemoveEventHandler(eventHandlerReference) }
        hotKeyReference = nil
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
    case registrationFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .registrationFailed(let status):
            "Command-Shift-Space could not be registered (error \(status))."
        }
    }
}
