import Foundation

/// The learner model across sessions: topics, evidence, spaced review, scoreboards.
extension AppModel {
    static let learningToolNames: Set<String> = ["start_topic", "record_evidence", "show_progress", "review_due"]

    func handleLearningToolCall(
        _ item: RealtimeItem,
        userItemID: String?,
        turn: Int,
        generation: Int,
        connectionID: RealtimeConnectionID
    ) async throws -> Bool {
        guard let name = item.name, Self.learningToolNames.contains(name) else { return false }
        let arguments = ToolArguments(json: item.arguments)
        let result: ToolResult

        do {
            switch name {
            case "start_topic":
                let subskills = (arguments.values["subskills"] as? [Any])?.compactMap { $0 as? String }
                    ?? (arguments.optionalString("subskills") ?? "").split(whereSeparator: \.isNewline).map(String.init)
                let topic = try learner.startTopic(try arguments.string("topic"), subskills: subskills)
                let unplaced = topic.subskills.filter { $0.evidence.isEmpty }.map(\.name)
                result = .ok([
                    "skill_map": LearnerReport.skillMap(topic, now: Date()),
                    "next": unplaced.isEmpty
                        ? "Levels are known; continue with the weakest subskill or a warm-up."
                        : "Run a 3–5 question diagnostic (easy to hard, one question at a time, no teaching yet) for: "
                            + unplaced.joined(separator: ", ") + ". Record each with record_evidence kind diagnostic."
                ])
            case "record_evidence":
                guard let kind = arguments.optionalString("kind").flatMap(EvidenceKind.init(rawValue:)) else {
                    throw DeskToolError.missingArgument("kind")
                }
                let change = try learner.record(
                    kind,
                    topic: try arguments.string("topic"),
                    subskill: try arguments.string("subskill"),
                    placedLevel: arguments.number("placed_level").map { Int($0.rounded()) },
                    note: arguments.optionalString("note") ?? ""
                )
                var fields = [
                    "subskill": change.subskill,
                    "level": "\(change.from) → \(change.to)/5 (\(LearnerRules.levelName(change.to)))",
                    "next_review": LearnerReport.relative(change.dueAt, now: Date())
                ]
                fields["learning_context"] = try tutorSupportContext.json()
                if tutorSupportContext.nextMove == .transfer { overlay.clear() }
                if change.to == change.from, kind == .prompted, change.to >= 3 {
                    fields["note"] = "Prompted checks cannot raise past 3; check again later from memory."
                }
                result = .ok(fields)
            case "show_progress":
                let markdown = learner.progressMarkdown(topic: arguments.optionalString("topic"))
                try workspace.presentArtifact(id: "learning-progress", title: "Progress", markdown: markdown, section: "Learning evidence")
                result = .ok(["board": "shown", "progress": markdown])
            case "review_due":
                let due = learner.warmUp()
                result = .ok([
                    "due": due.isEmpty
                        ? "Nothing is due."
                        : due.map { "\($0.skill.name) (\($0.topic.title), level \($0.skill.level))" }.joined(separator: "\n"),
                    "how": "Give these as one warm_up task on paper, mixed, from memory, no hints. Record each answer."
                ])
            default:
                return false
            }
        } catch {
            result = .failure(code: "\(name)_failed", message: error.localizedDescription)
        }

        try await completeDeskToolCall(
            item,
            result: result,
            image: nil,
            userItemID: userItemID,
            turn: turn,
            generation: generation,
            connectionID: connectionID
        )
        return true
    }
}
