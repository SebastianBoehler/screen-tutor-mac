import Foundation

struct LearningGoal: Codable, Equatable, Sendable {
    let objective: String
    let topic: String
    let subskill: String
}

struct TutorSupportContext: Codable, Equatable, Sendable {
    enum Move: String, Codable, Sendable {
        case establishGoal = "establish_goal", diagnose, prompt, cue
        case workedStep = "worked_step", transfer, independentCheck = "independent_check"
    }

    let goal: LearningGoal?
    let nextMove: Move
    let allowsHints: Bool
    let guidance: String

    static func make(goal: LearningGoal?, skill: Subskill?, taskKind: TaskKind?) -> Self {
        if taskKind?.isUnaided == true {
            return Self(goal: goal, nextMove: .independentCheck, allowsHints: false,
                        guidance: "Let the learner finish from memory. Navigation is allowed; teaching overlays and hints are withheld. "
                            + "If they ask for help, close this check as assisted before giving a cue.")
        }
        guard let goal else {
            return Self(goal: nil, nextMove: .establishGoal, allowsHints: true,
                        guidance: "Use the learner's stated objective to set one concrete learning goal. Ask only if the objective is unclear.")
        }
        guard let skill, !skill.evidence.isEmpty else {
            return Self(goal: goal, nextMove: .diagnose, allowsHints: true,
                        guidance: "Ask for one attempt or prediction about this goal before giving substantive help.")
        }
        if skill.level >= 4 {
            return Self(goal: goal, nextMove: .transfer, allowsHints: true,
                        guidance: "Fade the overlays. Give one changed problem or teach-back question without hints; verify independent understanding.")
        }
        let recent = skill.evidence.suffix(2)
        if recent.count == 2, recent.allSatisfy({ $0.kind == .incorrect }) {
            return Self(goal: goal, nextMove: .workedStep, allowsHints: true,
                        guidance: "Show one worked step with its reasoning, then hand the very next step back to the learner. Never complete the exercise.")
        }
        if skill.evidence.last?.kind == .incorrect {
            return Self(goal: goal, nextMove: .cue, allowsHints: true,
                        guidance: "Give one located cue or highlight, without the answer. Ask the learner to re-check that step.")
        }
        return Self(goal: goal, nextMove: .prompt, allowsHints: true,
                    guidance: "Hand the next step to the learner with one short question. Use a visual cue only if their next attempt needs it.")
    }

    func json() throws -> String {
        String(decoding: try JSONEncoder().encode(self), as: UTF8.self)
    }
}
