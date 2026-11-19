import AppKit
import XCTest
@testable import ScreenTutor

/// Uses a synthetic slide and real OpenRouter requests. Never captures the desktop
/// or posts input events. Enable with TEST_RUNNER_OPENROUTER_API_KEY.
@MainActor
final class OpenRouterVisionLiveTests: XCTestCase {
    func testDeskObserverTranscribesVisibleFormula() async throws {
        let completion = try await OpenRouterClient().complete(
            apiKey: try apiKey(),
            model: AppSettingsModel.defaultObserverModel,
            system: DeskObserverPrompt.system,
            userText: DeskObserverPrompt.userText(
                reason: .requested, task: nil, previous: nil,
                conversation: "", secondsSinceLastChange: nil
            ),
            jpegData: try slideJPEG()
        )
        let observation = try DeskObservationPayload.parse(completion.text)
        XCTAssertFalse(observation.summary.isEmpty)
        XCTAssertTrue(observation.workTranscription.contains("theta") || observation.workTranscription.contains("θ"))
        XCTAssertTrue(observation.workTranscription.contains("eta") || observation.workTranscription.contains("η"))
        XCTAssertNil(observation.issue, "The slide contains a valid gradient descent rule.")
        report(completion)
    }

    func testComputerAgentPointsInsideRequestedHeading() async throws {
        let key = try apiKey()
        let image = SyntheticSlide.image()
        let frame = CGRect(origin: .zero, size: SyntheticSlide.size)
        let elements = try ScreenReader.recognizeText(in: image, displayFrame: frame)
        let heading = try XCTUnwrap(elements.first { $0.label.contains("Gradient descent update rule") })
        let completion = try await OpenRouterClient().complete(
            apiKey: key,
            model: AppSettingsModel.defaultComputerModel,
            system: ComputerAgentPrompt.system,
            userText: ComputerAgentPrompt.userText(
                goal: "Click the center of the heading 'Gradient descent update rule'.",
                step: 1, maxSteps: 1, history: []
            ),
            jpegData: try slideJPEG()
        )
        let step = try ComputerAgentStep.parse(completion.text)
        XCTAssertEqual(step.action.type, "click")
        let snapshot = DisplaySnapshot(jpegData: Data(), displayFrame: frame)
        let point = snapshot.globalPoint(
            normalizedX: try XCTUnwrap(step.action.x),
            normalizedY: try XCTUnwrap(step.action.y)
        )
        XCTAssertTrue(heading.rect.contains(point), "Proposed click \(point) misses heading \(heading.rect).")
        report(completion)
    }

    private func apiKey() throws -> String {
        guard let key = ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"], !key.isEmpty else {
            throw XCTSkip("Set TEST_RUNNER_OPENROUTER_API_KEY to run live vision tests.")
        }
        return key
    }

    private func slideJPEG() throws -> Data {
        try XCTUnwrap(ScreenImageEncoder().jpegData(from: SyntheticSlide.image(), maximumDimension: 1_024))
    }

    private func report(_ completion: OpenRouterCompletion) {
        print("VISION_LIVE \(completion.model): \(String(format: "%.2f", completion.latency)) s round trip, "
            + "\(completion.completionTokens.map(String.init) ?? "unknown") completion tokens")
    }
}
