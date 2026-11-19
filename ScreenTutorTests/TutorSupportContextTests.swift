import XCTest
@testable import ScreenTutor

final class TutorSupportContextTests: XCTestCase {
    private let goal = LearningGoal(objective: "Explain gradient descent from memory", topic: "Optimization", subskill: "Update rule")

    func testUnknownGoalAndNewSkillAskForGoalAndAttempt() {
        XCTAssertEqual(TutorSupportContext.make(goal: nil, skill: nil, taskKind: nil).nextMove, .establishGoal)
        let context = TutorSupportContext.make(goal: goal, skill: Subskill(name: "Update rule"), taskKind: nil)
        XCTAssertEqual(context.nextMove, .diagnose)
        XCTAssertTrue(context.guidance.contains("attempt"))
    }

    func testIncorrectAttemptsEscalateOnlyOneStepAndAssistanceHandsBackControl() {
        var skill = Subskill(name: "Update rule")
        skill.evidence = [evidence(.incorrect)]
        XCTAssertEqual(context(skill).nextMove, .cue)
        skill.evidence.append(evidence(.incorrect))
        XCTAssertEqual(context(skill).nextMove, .workedStep)
        skill.evidence.append(evidence(.assisted))
        XCTAssertEqual(context(skill).nextMove, .prompt)
    }

    func testIndependentEvidenceFadesHintsAndUnaidedTaskSuppressesThem() {
        var skill = Subskill(name: "Update rule")
        skill.level = 4
        skill.evidence = [evidence(.unprompted)]
        XCTAssertEqual(context(skill).nextMove, .transfer)
        for kind in [TaskKind.warmUp, .exitTicket] {
            let context = TutorSupportContext.make(goal: goal, skill: skill, taskKind: kind)
            XCTAssertEqual(context.nextMove, .independentCheck)
            XCTAssertFalse(context.allowsHints)
        }
    }

    private func context(_ skill: Subskill) -> TutorSupportContext {
        TutorSupportContext.make(goal: goal, skill: skill, taskKind: .practice)
    }

    private func evidence(_ kind: EvidenceKind) -> Evidence {
        Evidence(kind: kind, note: "Observed attempt", at: Date())
    }
}
