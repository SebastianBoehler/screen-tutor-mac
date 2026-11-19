import SwiftUI

@main
struct ScreenTutorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate

    var body: some Scene {
        Window("ScreenTutor", id: "learning-workspace") {
            LearningShell(model: appDelegate.model)
        }
        .defaultSize(width: 1_160, height: 800)
        .windowToolbarStyle(.unifiedCompact)

        Window("Your learning", id: "study-dashboard") {
            StudyDashboardView(model: appDelegate.model)
        }
        .defaultSize(width: 780, height: 760)

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

        Window("Desk", id: "desk-camera") {
            DeskCameraView(model: appDelegate.model)
        }
        .defaultSize(width: 980, height: 620)

        Window("Conversation History", id: "conversation-history") {
            ConversationHistoryView(appModel: appDelegate.model)
        }
        .defaultSize(width: 820, height: 620)
    }
}
