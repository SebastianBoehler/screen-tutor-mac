import XCTest
@testable import ScreenTutor

@MainActor
final class NativeTutorToolsTests: XCTestCase {
    func testNativeToolsAreAvailableToVoiceSession() throws {
        let tools = RealtimeFunctionTool.all
        for name in ["inspect_app", "activate_control", "highlight_control", "set_learning_goal"] {
            XCTAssertEqual(tools.filter { $0.name == name }.count, 1)
        }
        let action = try XCTUnwrap(tools.first { $0.name == "activate_control" })
        XCTAssertEqual(action.parameters.required, ["control_id", "action"])
        XCTAssertEqual(action.parameters.properties["action"]?.enumValues, NativeControlAction.allCases.map(\.rawValue))
    }

    func testControlActivationRequiresOptInAndInspectReturnsAdaptiveContext() throws {
        let (model, backend, _) = makeModel()
        let result = model.executeNativeTool("inspect_app", arguments: ToolArguments(json: "{}"))
        XCTAssertTrue(result.succeeded)
        XCTAssertTrue(result.json.contains("learning_context"))
        let id = try XCTUnwrap(model.nativeApps.snapshot?.controls.first?.id)
        model.settings.setComputerControlEnabled(false)
        XCTAssertFalse(model.executeNativeTool("activate_control", arguments: arguments(id)).succeeded)
        XCTAssertTrue(backend.actions.isEmpty)
        model.settings.setComputerControlEnabled(true)
        defer { model.settings.setComputerControlEnabled(false) }
        XCTAssertTrue(model.executeNativeTool("activate_control", arguments: arguments(id)).succeeded)
        XCTAssertEqual(backend.actions, [.press])
    }

    func testLearningGoalUsesActualSkillAndUnaidedChecksRejectTeachingHints() throws {
        let (model, _, store) = makeModel()
        try store.startTopic("Optimization", subskills: ["Update rule"])
        let goal = model.executeNativeTool("set_learning_goal", arguments: ToolArguments(json:
            #"{"objective":"Explain the update rule","topic":"Optimization","subskill":"Update rule"}"#))
        XCTAssertTrue(goal.succeeded)
        XCTAssertEqual(model.learningGoal?.objective, "Explain the update rule")
        _ = model.executeNativeTool("inspect_app", arguments: ToolArguments(json: "{}"))
        let id = try XCTUnwrap(model.nativeApps.snapshot?.controls.first?.id)
        _ = model.deskObserver.assignTask(title: "Recall", prompt: "Write the rule", expectedEvidence: "Rule",
                                        kind: .warmUp, topic: "Optimization", subskill: "Update rule")
        let hint = ToolArguments(json: "{\"control_id\":\"\(id)\",\"purpose\":\"hint\",\"label\":\"Look here\"}")
        XCTAssertFalse(model.executeNativeTool("highlight_control", arguments: hint).succeeded)
        XCTAssertNil(model.overlay.current)
        let navigation = ToolArguments(json: "{\"control_id\":\"\(id)\",\"purpose\":\"navigation\"}")
        XCTAssertTrue(model.executeNativeTool("highlight_control", arguments: navigation).succeeded)
        model.overlay.clear()
        let invalid = model.executeNativeTool("set_learning_goal", arguments: ToolArguments(json:
            #"{"objective":"Invented skill","topic":"Optimization","subskill":"Unknown"}"#))
        XCTAssertFalse(invalid.succeeded)
        XCTAssertEqual(model.learningGoal?.objective, "Explain the update rule")
    }

    func testExamModeCannotBeBypassedByAnExistingPracticeTask() throws {
        let (model, _, _) = makeModel()
        _ = model.deskObserver.assignTask(title: "Practice", prompt: "Try", expectedEvidence: "Attempt", kind: .practice)
        try model.workspace.setMode(.exam)
        XCTAssertFalse(model.tutorSupportContext.allowsHints)
        XCTAssertThrowsError(try model.requireTeachingHintsAllowed())
        XCTAssertEqual(model.tutorSupportContext.nextMove, .independentCheck)
    }

    private func arguments(_ id: String) -> ToolArguments {
        ToolArguments(json: "{\"control_id\":\"\(id)\",\"action\":\"press\"}")
    }

    private func makeModel() -> (AppModel, NativeBackendFixture, LearnerStore) {
        let backend = NativeBackendFixture()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = LearnerStore(fileURL: directory.appendingPathComponent("learner.json"))
        let suite = "NativeTutorToolsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettingsModel(apiKeyStore: APIKeyStore(), captureService: ActiveWindowCaptureService(),
                                        launchAtLoginService: LaunchAtLoginService(), userDefaults: defaults)
        return (makeTestAppModel(nativeApps: NativeAppService(backend: backend), learner: store, settings: settings), backend, store)
    }
}
