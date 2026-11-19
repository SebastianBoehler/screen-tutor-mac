import XCTest
@testable import ScreenTutor

extension XCTestCase {
    /// App-level tests must never write study data into the developer's real library.
    @MainActor
    func makeTestAppModel(
        history: ConversationHistoryModel? = nil, realtimeClient: RealtimeClient? = nil,
        nativeApps: NativeAppService? = nil, learner: LearnerStore? = nil, settings: AppSettingsModel? = nil
    ) -> AppModel {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suite = "AppModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { try? FileManager.default.removeItem(at: root); defaults.removePersistentDomain(forName: suite) }
        let settings = settings ?? AppSettingsModel(apiKeyStore: APIKeyStore(), captureService: ActiveWindowCaptureService(),
            launchAtLoginService: LaunchAtLoginService(), userDefaults: defaults)
        return AppModel(history: history ?? ConversationHistoryModel(store: ConversationLogStore(rootDirectoryURL: root.appendingPathComponent("History"))),
            realtimeClient: realtimeClient, nativeApps: nativeApps, learner: learner ?? LearnerStore(fileURL: root.appendingPathComponent("learner.json")),
            settings: settings, courses: CourseLibrary(rootURL: root.appendingPathComponent("Courses")),
            workspace: LearningWorkspaceStore(rootURL: root.appendingPathComponent("Workspaces")))
    }
}
