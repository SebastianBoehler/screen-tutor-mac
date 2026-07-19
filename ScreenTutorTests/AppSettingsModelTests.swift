import Foundation
import XCTest
@testable import ScreenTutor

final class AppSettingsModelTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "AppSettingsModelTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    @MainActor
    func testTutorInstructionsDefaultPersistAndRestore() {
        let model = makeModel()
        XCTAssertEqual(
            model.tutorInstructions,
            RealtimeConstants.defaultTutorInstructions
        )

        let customInstructions = "Use Socratic questions and relate ideas to control theory."
        model.saveTutorInstructions(customInstructions)

        XCTAssertEqual(model.tutorInstructions, customInstructions)
        XCTAssertEqual(makeModel().tutorInstructions, customInstructions)

        model.restoreDefaultTutorInstructions()

        XCTAssertEqual(
            model.tutorInstructions,
            RealtimeConstants.defaultTutorInstructions
        )
        XCTAssertEqual(
            makeModel().tutorInstructions,
            RealtimeConstants.defaultTutorInstructions
        )
    }

    @MainActor
    func testBlankTutorInstructionsRemainAValidCustomization() {
        let model = makeModel()

        model.saveTutorInstructions("")

        XCTAssertEqual(model.tutorInstructions, "")
        XCTAssertEqual(makeModel().tutorInstructions, "")
    }

    @MainActor
    func testReasoningEffortDefaultsToLowAndPersists() {
        let model = makeModel()
        XCTAssertEqual(model.reasoningEffort, .low)

        model.setReasoningEffort(.high)

        XCTAssertEqual(model.reasoningEffort, .high)
        XCTAssertEqual(makeModel().reasoningEffort, .high)
    }

    @MainActor
    private func makeModel() -> AppSettingsModel {
        AppSettingsModel(
            apiKeyStore: APIKeyStore(),
            captureService: ActiveWindowCaptureService(),
            launchAtLoginService: LaunchAtLoginService(),
            userDefaults: defaults
        )
    }
}
