import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var hotKeyController: GlobalHotKeyController?
    private var hudController: HUDPanelController?
    private var teachingPointerController: TeachingPointerController?
    private var isPreparingToTerminate = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        hudController = HUDPanelController(model: model)
        let teachingPointerController = TeachingPointerController()
        self.teachingPointerController = teachingPointerController
        model.configureTeachingPointer(
            show: { [weak teachingPointerController] highlight in
                teachingPointerController?.show(highlight)
            },
            clear: { [weak teachingPointerController] in
                teachingPointerController?.hide()
            }
        )
        let hotKeyController = GlobalHotKeyController { [weak model] in
            model?.toggleSession()
        }
        self.hotKeyController = hotKeyController
        do {
            try hotKeyController.register()
        } catch {
            model.reportHotKeyError(error)
        }
        model.settings.refresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyController?.unregister()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard model.phase.needsTeardown, !isPreparingToTerminate else { return .terminateNow }
        isPreparingToTerminate = true
        Task {
            await model.stopSession()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
