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
            SettingsView(
                model: appDelegate.model.settings,
                historyModel: appDelegate.model.history
            )
        }

        Window("Conversation History", id: "conversation-history") {
            ConversationHistoryView(model: appDelegate.model.history)
        }
        .defaultSize(width: 820, height: 620)
    }
}
