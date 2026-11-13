import XCTest
@testable import ScreenTutor

final class LearnerRulesTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    private func day(_ n: Double) -> Date { t0.addingTimeInterval(n * 86_400) }

    func testPromptedChecksAloneStopAtCanDoWithHelp() {
        var skill = Subskill(name: "Chain rule")
        LearnerRules.apply(.prompted, to: &skill, now: t0)
        XCTAssertEqual(skill.level, 1)
        for _ in 0..<2 { LearnerRules.apply(.prompted, to: &skill, now: t0) }
        XCTAssertEqual(skill.level, 2)
        for _ in 0..<2 { LearnerRules.apply(.prompted, to: &skill, now: t0) }
        XCTAssertEqual(skill.level, 3)
        for _ in 0..<5 { LearnerRules.apply(.prompted, to: &skill, now: t0) }
        XCTAssertEqual(skill.level, 3, "independent needs unprompted recall")
    }

    func testIndependentNeedsTwoChecksIncludingOneUnprompted() {
        var skill = Subskill(name: "Chain rule")
        skill.level = 3
        LearnerRules.apply(.unprompted, to: &skill, now: t0)
        XCTAssertEqual(skill.level, 3, "one check is not enough")
        let change = LearnerRules.apply(.prompted, to: &skill, now: t0)
        XCTAssertEqual(change.from, 3)
        XCTAssertEqual(change.to, 4)
        XCTAssertEqual(skill.correctSinceChange, 0)
    }

    func testTeachBackReachesFiveOnlyFromIndependent() {
        var skill = Subskill(name: "Eigenvectors")
        skill.level = 3
        LearnerRules.apply(.teachBack, to: &skill, now: t0)
        XCTAssertEqual(skill.level, 3)
        XCTAssertEqual(skill.unpromptedSinceChange, 1, "counts as an unprompted check")
        XCTAssertEqual(skill.evidence.map(\.kind), [.teachBack])
        skill.level = 4
        LearnerRules.apply(.teachBack, to: &skill, now: t0)
        XCTAssertEqual(skill.level, 5)
    }

    func testFailedReviewLosesALevelAndComesBackTomorrow() {
        var skill = Subskill(name: "Gradient")
        skill.level = 3
        skill.dueAt = t0
        let change = LearnerRules.apply(.incorrect, to: &skill, now: t0)
        XCTAssertEqual(change.to, 2)
        XCTAssertEqual(skill.dueAt, day(1))
        // A mistake during fresh practice (not due, below 4) keeps the level.
        skill.dueAt = day(5)
        skill.correctSinceChange = 1
        LearnerRules.apply(.incorrect, to: &skill, now: t0)
        XCTAssertEqual(skill.level, 2)
        XCTAssertEqual(skill.correctSinceChange, 0)
    }

    func testAssistedOnAMasteredSkillDropsIt() {
        var skill = Subskill(name: "Gradient")
        skill.level = 4
        LearnerRules.apply(.assisted, to: &skill, now: t0)
        XCTAssertEqual(skill.level, 3)
    }

    func testDiagnosticPlacesUpToThreeOnlyBeforePractice() {
        var skill = Subskill(name: "Limits")
        LearnerRules.apply(.diagnostic, placedLevel: 5, to: &skill, now: t0)
        XCTAssertEqual(skill.level, 3)
        LearnerRules.apply(.prompted, to: &skill, now: t0)
        LearnerRules.apply(.diagnostic, placedLevel: 0, to: &skill, now: t0)
        XCTAssertEqual(skill.level, 3, "placement is ignored after practice")
    }

    func testReviewIntervalsExpandWithLevel() {
        var skill = Subskill(name: "Limits")
        skill.level = 3
        LearnerRules.apply(.unprompted, to: &skill, now: t0)
        XCTAssertEqual(skill.dueAt, day(4))
        LearnerRules.apply(.unprompted, to: &skill, now: t0)
        XCTAssertEqual(skill.level, 4)
        XCTAssertEqual(skill.dueAt, day(8))
        XCTAssertFalse(skill.isDue(at: day(7)))
        XCTAssertTrue(skill.isDue(at: day(8)))
    }

    func testWarmUpInterleavesTopicsOldestFirst() {
        func skill(_ name: String, due: Double) -> Subskill {
            var s = Subskill(name: name)
            s.level = 2
            s.dueAt = day(due)
            return s
        }
        let a = Topic(id: "a", title: "A", subskills: [skill("a1", due: 1), skill("a2", due: 2), skill("a3", due: 3)], createdAt: t0, updatedAt: t0)
        let b = Topic(id: "b", title: "B", subskills: [skill("b1", due: 1.5), skill("b-later", due: 30)], createdAt: t0, updatedAt: t0)
        let picked = LearnerRules.warmUp(from: [b, a], now: day(10)).map(\.skill.name)
        XCTAssertEqual(picked, ["a1", "b1", "a2"])
    }

    func testReportRendersBarsAndScoreboards() {
        var skill = Subskill(name: "Chain rule")
        skill.level = 3
        skill.dueAt = day(2)
        let topic = Topic(id: "calc", title: "Calculus", subskills: [skill, Subskill(name: "Limits")], createdAt: t0, updatedAt: t0)
        let map = LearnerReport.skillMap(topic, now: t0)
        XCTAssertTrue(map.contains("### Calculus · 30%"))
        XCTAssertTrue(map.contains("| Chain rule | `███░░` 3/5 can do with help | in 2 d |"))
        var score = SessionScore(startedAt: t0)
        score.practiceAssisted = 2
        score.exitPassed = 1
        score.exitFailed = 1
        XCTAssertTrue(LearnerReport.scoreboards(score).contains("exit tickets 1/2"))
    }
}

@MainActor
final class LearnerStoreTests: XCTestCase {
    private var url: URL!
    private var clock = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUp() async throws {
        url = FileManager.default.temporaryDirectory.appendingPathComponent("learner-\(UUID().uuidString).json")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: url)
    }

    private func store() -> LearnerStore {
        LearnerStore(fileURL: url, now: { [unowned self] in self.clock })
    }

    func testTopicsEvidenceTaskOutcomesAndPersistence() throws {
        let learner = store()
        learner.beginSession()
        try learner.startTopic("Gradient descent", subskills: ["Update rule", "Learning rate", "Update rule"])
        XCTAssertEqual(learner.state.topics[0].subskills.map(\.name), ["Update rule", "Learning rate"])
        try learner.startTopic("gradient  DESCENT", subskills: ["Convergence"])
        XCTAssertEqual(learner.state.topics.count, 1)
        XCTAssertEqual(learner.state.topics[0].subskills.count, 3)

        try learner.record(.diagnostic, topic: "Gradient descent", subskill: "update rule", placedLevel: 2)
        // Unknown subskills are added rather than rejected.
        try learner.record(.prompted, topic: "Gradient descent", subskill: "Momentum")
        XCTAssertEqual(learner.state.topics[0].subskills.last?.name, "Momentum")
        XCTAssertThrowsError(try learner.record(.prompted, topic: "Topology", subskill: "Open sets"))

        // Exit ticket passed counts as unprompted evidence and on the unaided scoreboard.
        learner.recordTaskOutcome(kind: .practice, outcome: "assisted", topic: "Gradient descent", subskill: "Update rule", note: "")
        let change = learner.recordTaskOutcome(kind: .exitTicket, outcome: "independent", topic: "Gradient descent", subskill: "Update rule", note: "")
        XCTAssertEqual(change?.from, 2)
        let session = try XCTUnwrap(learner.currentSession)
        XCTAssertEqual(session.practiceAssisted, 1)
        XCTAssertEqual(session.exitPassed, 1)

        let reloaded = store()
        XCTAssertEqual(reloaded.state, learner.state)
    }

    func testSessionsGroupWithinTwoHoursAndContextListsDueReviews() throws {
        let learner = store()
        learner.beginSession()
        let first = learner.currentSessionID
        clock = clock.addingTimeInterval(3600)
        learner.beginSession()
        XCTAssertEqual(learner.currentSessionID, first)

        try learner.startTopic("Calculus", subskills: ["Chain rule"])
        try learner.record(.diagnostic, topic: "Calculus", subskill: "Chain rule", placedLevel: 2)
        clock = clock.addingTimeInterval(3 * 86_400)
        learner.beginSession()
        XCTAssertNotEqual(learner.currentSessionID, first)
        let context = learner.sessionContext()
        XCTAssertTrue(context.contains("Calculus (40%): Chain rule 2/5"), context)
        XCTAssertTrue(context.contains("Due for a warm-up review: Chain rule (Calculus)"), context)
        XCTAssertTrue(learner.progressMarkdown().contains("**Due for review:** Chain rule"))
    }
}

final class LessonProtocolTests: XCTestCase {
    func testChapterPausesSkipShortAndEarlyChapters() {
        let chapters = [
            VideoChapter(seconds: 0, title: "Intro"), VideoChapter(seconds: 30, title: "Recap"),
            VideoChapter(seconds: 109, title: "Data"), VideoChapter(seconds: 181, title: "Cost"),
            VideoChapter(seconds: 415, title: "Descent"), VideoChapter(seconds: 678, title: "Vectors")
        ]
        XCTAssertEqual(LessonPlayerController.chapterPauses(chapters, after: 0), [109, 415, 678])
        XCTAssertEqual(LessonPlayerController.chapterPauses(chapters, after: 400), [678])
        XCTAssertEqual(LessonPlayerController.chapterPauses([], after: 0), [])
    }

    func testInstructionsCarryLearnerContextAsData() {
        let text = RealtimeConstants.tutorInstructions(
            language: .automatic,
            customTutorInstructions: "",
            learnerContext: "- Calculus (40%): Chain rule 2/5"
        )
        XCTAssertTrue(text.contains("<learner_model>\n- Calculus (40%): Chain rule 2/5\n</learner_model>"))
        XCTAssertTrue(text.contains("assign_task(kind: warm_up)"))
        XCTAssertTrue(text.contains("<lesson_player>"))
    }
}
