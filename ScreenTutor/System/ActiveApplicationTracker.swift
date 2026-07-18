import AppKit

@MainActor
final class ActiveApplicationTracker: NSObject {
    private(set) var processIdentifier: pid_t?
    private(set) var applicationName: String?

    override init() {
        super.init()
        update(with: NSWorkspace.shared.frontmostApplication)
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc
    private func applicationDidActivate(_ notification: Notification) {
        let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
            as? NSRunningApplication
        update(with: application)
    }

    private func update(with application: NSRunningApplication?) {
        guard
            let application,
            application.processIdentifier != ProcessInfo.processInfo.processIdentifier
        else { return }
        processIdentifier = application.processIdentifier
        applicationName = application.localizedName
    }
}
