import Foundation

// The learner model: topics broken into subskills, each at a mastery level 0–5
// that only ScreenTutor's rules change, never the voice model directly. The
// tutor reports evidence; these rules decide levels and review dates.
//
// Levels (after Jane Street's socratic-tutor scale):
// 0 unaware · 1 heard of it · 2 can follow along · 3 can do with help
// 4 can do independently · 5 can teach it / handle edge cases

enum EvidenceKind: String, Codable, Sendable, CaseIterable {
    /// Placement question at the start of a topic (sets a level up to 3).
    case diagnostic
    /// Correct, but with a hint or right after being shown how.
    case prompted
    /// Correct recall without help and not right after being told.
    case unprompted
    /// Explained it clearly or handled an edge case.
    case teachBack = "teach_back"
    case incorrect
    /// Needed a worked step, or asked "just tell me".
    case assisted
}

struct Evidence: Codable, Equatable, Sendable {
    let kind: EvidenceKind
    let note: String
    let at: Date
}

struct Subskill: Codable, Equatable, Sendable, Identifiable {
    let id: String
    var name: String
    var level: Int = 0
    var evidence: [Evidence] = []
    /// Correct checks since the last level change, and how many were unprompted.
    var correctSinceChange = 0
    var unpromptedSinceChange = 0
    var dueAt: Date?
    var lastPracticedAt: Date?

    init(name: String) {
        self.id = LearnerRules.slug(name)
        self.name = name
    }

    func isDue(at now: Date) -> Bool {
        level >= 1 && (dueAt.map { $0 <= now } ?? false)
    }
}

struct Topic: Codable, Equatable, Sendable, Identifiable {
    let id: String
    var title: String
    var subskills: [Subskill]
    let createdAt: Date
    var updatedAt: Date

    var percent: Int {
        guard !subskills.isEmpty else { return 0 }
        return Int((Double(subskills.map(\.level).reduce(0, +)) / Double(subskills.count * 5) * 100).rounded())
    }
}

/// The two scoreboards: work done with the tutor's help, and checks done without it.
struct SessionScore: Codable, Equatable, Sendable {
    let id: UUID
    let startedAt: Date
    var practiceIndependent = 0
    var practiceAssisted = 0
    var practiceAbandoned = 0
    var warmUpPassed = 0
    var warmUpFailed = 0
    var exitPassed = 0
    var exitFailed = 0

    init(id: UUID = UUID(), startedAt: Date) {
        self.id = id
        self.startedAt = startedAt
    }

    var unaidedChecks: Int { warmUpPassed + warmUpFailed + exitPassed + exitFailed }
}

struct LearnerState: Codable, Equatable, Sendable {
    var topics: [Topic] = []
    var sessions: [SessionScore] = []
}

struct LevelChange: Equatable, Sendable {
    let subskill: String
    let from: Int
    let to: Int
    let dueAt: Date?
}

enum LearnerRules {
    /// Days until the next review after a successful check, by level.
    static let reviewDays: [Int: Double] = [1: 1, 2: 2, 3: 4, 4: 8, 5: 21]
    static let retryDays: Double = 1

    static func slug(_ text: String) -> String {
        let lowered = text.lowercased().folding(options: .diacriticInsensitive, locale: nil)
        let parts = lowered.split { !$0.isLetter && !$0.isNumber }
        return parts.joined(separator: "-")
    }

    static func levelName(_ level: Int) -> String {
        ["unaware", "heard of it", "can follow along", "can do with help", "independent", "can teach it"][min(max(level, 0), 5)]
    }

    /// Applies one piece of evidence and returns the resulting level change.
    @discardableResult
    static func apply(
        _ kind: EvidenceKind,
        placedLevel: Int? = nil,
        note: String = "",
        to skill: inout Subskill,
        now: Date
    ) -> LevelChange {
        let before = skill.level
        let wasDue = skill.isDue(at: now)
        skill.evidence.append(Evidence(kind: kind, note: note, at: now))
        skill.lastPracticedAt = now

        func changeLevel(to level: Int) {
            skill.level = min(max(level, 0), 5)
            skill.correctSinceChange = 0
            skill.unpromptedSinceChange = 0
        }
        func scheduleReview() {
            skill.dueAt = skill.level >= 1 ? now.addingTimeInterval((reviewDays[skill.level] ?? 1) * 86_400) : nil
        }
        func scheduleRetry() {
            skill.dueAt = skill.level >= 1 ? now.addingTimeInterval(retryDays * 86_400) : nil
        }

        // Below level 4 a teach-back counts like an unprompted check.
        let effective: EvidenceKind = kind == .teachBack && skill.level < 4 ? .unprompted : kind
        switch effective {
        case .diagnostic:
            // Placement only counts before real practice and never above "can do with help".
            let practiced = skill.evidence.dropLast().contains { $0.kind != .diagnostic }
            if !practiced, let placedLevel { changeLevel(to: min(max(placedLevel, 0), 3)) }
            scheduleReview()
        case .prompted:
            if skill.level == 0 {
                changeLevel(to: 1)
            } else {
                skill.correctSinceChange += 1
                // Prompted checks alone reach 3; past that, one of the two must be unprompted.
                let canReach = skill.unpromptedSinceChange >= 1 ? 4 : 3
                if skill.correctSinceChange >= 2, skill.level < canReach { changeLevel(to: skill.level + 1) }
            }
            if skill.dueAt == nil { scheduleReview() }
        case .unprompted:
            if skill.level == 0 {
                changeLevel(to: 1)
            } else {
                skill.correctSinceChange += 1
                skill.unpromptedSinceChange += 1
                if skill.correctSinceChange >= 2, skill.unpromptedSinceChange >= 1, skill.level < 4 {
                    changeLevel(to: skill.level + 1)
                }
            }
            scheduleReview()
        case .teachBack:
            changeLevel(to: 5)
            scheduleReview()
        case .incorrect:
            // A failed review (something due, or supposedly mastered) costs a level.
            if wasDue || skill.level >= 4 { changeLevel(to: skill.level - 1) } else {
                skill.correctSinceChange = 0
                skill.unpromptedSinceChange = 0
            }
            scheduleRetry()
        case .assisted:
            if skill.level >= 4 { changeLevel(to: skill.level - 1) } else {
                skill.correctSinceChange = 0
                skill.unpromptedSinceChange = 0
            }
            scheduleRetry()
        }
        return LevelChange(subskill: skill.name, from: before, to: skill.level, dueAt: skill.dueAt)
    }

    /// Up to `limit` due subskills, oldest first, alternating between topics.
    static func warmUp(from topics: [Topic], now: Date, limit: Int = 3) -> [(topic: Topic, skill: Subskill)] {
        var queues = topics.map { topic in
            topic.subskills.filter { $0.isDue(at: now) }
                .sorted { ($0.dueAt ?? now) < ($1.dueAt ?? now) }
                .map { (topic: topic, skill: $0) }
        }
        .filter { !$0.isEmpty }
        .sorted { ($0[0].skill.dueAt ?? now) < ($1[0].skill.dueAt ?? now) }
        var picked: [(topic: Topic, skill: Subskill)] = []
        while picked.count < limit, queues.contains(where: { !$0.isEmpty }) {
            for index in queues.indices where !queues[index].isEmpty && picked.count < limit {
                picked.append(queues[index].removeFirst())
            }
        }
        return picked
    }
}

/// Markdown for the Tutor Board and text for the voice tutor.
enum LearnerReport {
    static func bar(_ level: Int) -> String {
        String(repeating: "█", count: level) + String(repeating: "░", count: 5 - level)
    }

    static func relative(_ date: Date?, now: Date) -> String {
        guard let date else { return "—" }
        let days = date.timeIntervalSince(now) / 86_400
        if days <= 0 { return "due now" }
        if days < 1 { return "in \(max(1, Int((days * 24).rounded()))) h" }
        return "in \(Int(days.rounded())) d"
    }

    static func skillMap(_ topic: Topic, now: Date) -> String {
        var lines = ["### \(topic.title) · \(topic.percent)%", "", "| Subskill | Level | Review |", "|---|---|---|"]
        for skill in topic.subskills {
            lines.append("| \(skill.name) | `\(bar(skill.level))` \(skill.level)/5 \(LearnerRules.levelName(skill.level)) | \(skill.level == 0 ? "—" : relative(skill.dueAt, now: now)) |")
        }
        return lines.joined(separator: "\n")
    }

    static func scoreboards(_ session: SessionScore?) -> String {
        guard let s = session else { return "" }
        return """
            **With help (practice):** \(s.practiceIndependent) independent · \(s.practiceAssisted) assisted · \(s.practiceAbandoned) abandoned
            **Without help (unaided checks):** warm-up \(s.warmUpPassed)/\(s.warmUpPassed + s.warmUpFailed) · exit tickets \(s.exitPassed)/\(s.exitPassed + s.exitFailed)
            """
    }

    /// Compact text for the tutor's instructions at session start.
    static func sessionContext(_ state: LearnerState, now: Date) -> String {
        guard !state.topics.isEmpty else {
            return "No learner history yet. When the learner starts a topic, call start_topic and run a short diagnostic."
        }
        var lines: [String] = []
        for topic in state.topics.sorted(by: { $0.updatedAt > $1.updatedAt }).prefix(6) {
            let skills = topic.subskills.map { "\($0.name) \($0.level)/5" }.joined(separator: ", ")
            lines.append("- \(topic.title) (\(topic.percent)%): \(skills)")
        }
        let due = LearnerRules.warmUp(from: state.topics, now: now)
        lines.append(
            due.isEmpty
                ? "Nothing is due for review."
                : "Due for a warm-up review: " + due.map { "\($0.skill.name) (\($0.topic.title))" }.joined(separator: "; ")
        )
        if let last = state.sessions.last {
            lines.append(
                "Last session: \(last.practiceIndependent) independent / \(last.practiceAssisted) assisted practice; "
                    + "unaided checks passed \(last.warmUpPassed + last.exitPassed) of \(last.unaidedChecks)."
            )
        }
        return lines.joined(separator: "\n")
    }
}
