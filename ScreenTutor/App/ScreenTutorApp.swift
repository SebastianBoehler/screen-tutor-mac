import SwiftUI

@main
struct ScreenTutorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(model: appDelegate.model)
        } label: {
            Label("ScreenTutor", systemImage: appDelegate.model.phase.symbolName)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: appDelegate.model.settings)
        }
    }
}
