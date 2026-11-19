import XCTest
@testable import ScreenTutor

@MainActor
final class LearningWorkspaceTests: XCTestCase {
    func testArtifactUpdatesRetainIdentityAndPersistWithTheirCourse() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = LearningWorkspaceStore(rootURL: root)
        try workspace.selectCourse("optimization")
        try workspace.presentArtifact(id: "update-rule", title: "Update rule", markdown: "$x' = x - eta*g$", section: "Concepts")
        try workspace.presentArtifact(id: "update-rule", title: "Update rule", markdown: "Now explain the sign.", section: "Your turn")
        XCTAssertEqual(workspace.artifacts.count, 1)
        XCTAssertEqual(workspace.artifacts[0].id, "update-rule")
        XCTAssertEqual(workspace.artifacts[0].section, "Your turn")
        let reloaded = LearningWorkspaceStore(rootURL: root)
        try reloaded.selectCourse("optimization")
        XCTAssertEqual(reloaded.artifacts, workspace.artifacts)
        try reloaded.selectCourse("statistics")
        XCTAssertTrue(reloaded.artifacts.isEmpty)
        try reloaded.selectCourse("optimization")
        XCTAssertEqual(reloaded.artifacts.count, 1)
    }

    func testOrganizationRejectsUnknownIdsWithoutDroppingExistingContent() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = LearningWorkspaceStore(rootURL: root)
        try workspace.presentArtifact(id: "one", title: "One", markdown: "First idea", section: "Concepts")
        try workspace.presentArtifact(id: "two", title: "Two", markdown: "Next idea", section: "Practice")
        try workspace.organize(artifactIDs: ["two", "one"], section: "Review")
        XCTAssertEqual(workspace.artifacts.map(\.id), ["two", "one"])
        XCTAssertTrue(workspace.artifacts.allSatisfy { $0.section == "Review" })
        XCTAssertThrowsError(try workspace.organize(artifactIDs: ["missing"], section: "Lost"))
        XCTAssertEqual(workspace.artifacts.count, 2)
    }

    func testFlashcardRequiresRevealAndDoesNotCreateMasteryEvidence() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = LearningWorkspaceStore(rootURL: root)
        try workspace.presentArtifact(id: "recall", title: "Gradient", markdown: "Which direction?", section: "Recall", flashcardAnswer: "Opposite the gradient.")
        XCTAssertFalse(try XCTUnwrap(workspace.artifacts.first?.flashcard).revealed)
        XCTAssertThrowsError(try workspace.reviewFlashcard(id: "recall", action: "recalled"))
        try workspace.reviewFlashcard(id: "recall", action: "reveal")
        try workspace.reviewFlashcard(id: "recall", action: "recalled")
        XCTAssertEqual(workspace.artifacts.first?.flashcard?.selfRating, "recalled")
        XCTAssertTrue(workspace.insights.isEmpty)
    }

    func testReasoningMemoryIsEvidenceBackedPersistentAndCorrectable() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = LearningWorkspaceStore(rootURL: root)
        try workspace.recordInsight(observation: "Uses a slope analogy", evidence: "I imagine walking downhill", implication: "Check the sign with that analogy")
        let id = try XCTUnwrap(workspace.insights.first?.id)
        try workspace.updateInsight(id: id, observation: "Prefers checking the derivative", evidence: "The slope analogy confused the sign", implication: "Use a local linear approximation")
        let reloaded = LearningWorkspaceStore(rootURL: root)
        try reloaded.selectCourse(nil)
        XCTAssertEqual(reloaded.insights.first?.observation, "Prefers checking the derivative")
        XCTAssertThrowsError(try workspace.recordInsight(observation: "Unsupported", evidence: "", implication: "Guess"))
        try reloaded.removeInsight(id: id)
        XCTAssertTrue(reloaded.insights.isEmpty)
    }
}
