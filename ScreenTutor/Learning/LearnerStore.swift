import Foundation
import Observation

enum TaskKind: String, Codable, Sendable, CaseIterable {
    /// Practice right after instruction; help is allowed.
    case practice
    /// Spaced review at session start; no help.
    case warmUp = "warm_up"
    /// Unseen problem at the end of a block; no help.
    case exitTicket = "exit_ticket"

    var isUnaided: Bool { self != .practice }

    var boardLabel: String {
        switch self {
        case .practice: "Your task"
        case .warmUp: "Warm-up · from memory, no help"
        case .exitTicket: "Exit ticket · on your own, no help"
        }
    }
}

enum LearnerError: LocalizedError {
    case unknownTopic(String)
    case noSubskills

    var errorDescription: String? {
        switch self {
        case .unknownTopic(let name): "No topic called “\(name)”. Call start_topic first."
        case .noSubskills: "Give at least one subskill."
        }
    }
}

/// Persists the learner model as one JSON file in Application Support and keeps
/// the scoreboards for the current session.
@MainActor
@Observable
final class LearnerStore {
    private(set) var state = LearnerState()
    private(set) var currentSessionID: UUID?
    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private let now: () -> Date

    init(fileURL: URL = LearnerStore.defaultURL(), now: @escaping () -> Date = Date.init) {
        self.fileURL = fileURL
        self.now = now
        if let data = try? Data(contentsOf: fileURL) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            state = (try? decoder.decode(LearnerState.self, from: data)) ?? LearnerState()
        }
    }

    static func defaultURL() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ScreenTutor/Learner/learner-model.json")
    }

    var currentSession: SessionScore? {
        state.sessions.last { $0.id == currentSessionID }
    }

    /// Starts a scoreboard for this conversation (a gap of 2 h starts a new one).
    func beginSession() {
        if let last = state.sessions.last, now().timeIntervalSince(last.startedAt) < 2 * 3600 {
            currentSessionID = last.id
            return
        }
        let session = SessionScore(startedAt: now())
        state.sessions.append(session)
        state.sessions = Array(state.sessions.suffix(200))
        currentSessionID = session.id
        save()
    }

    // MARK: topics and evidence

    @discardableResult
    func startTopic(_ title: String, subskills names: [String]) throws -> Topic {
        let cleaned = names.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let id = LearnerRules.slug(title)
        if let index = state.topics.firstIndex(where: { $0.id == id }) {
            for name in cleaned where !state.topics[index].subskills.contains(where: { $0.id == LearnerRules.slug(name) }) {
                state.topics[index].subskills.append(Subskill(name: name))
            }
            state.topics[index].updatedAt = now()
            save()
            return state.topics[index]
        }
        guard !cleaned.isEmpty else { throw LearnerError.noSubskills }
        var seen = Set<String>()
        let topic = Topic(
            id: id,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            subskills: cleaned.map(Subskill.init(name:)).filter { seen.insert($0.id).inserted },
            createdAt: now(),
            updatedAt: now()
        )
        state.topics.append(topic)
        save()
        return topic
    }

    func topic(named name: String) -> Topic? {
        let id = LearnerRules.slug(name)
        return state.topics.first { $0.id == id }
            ?? state.topics.first { $0.id.contains(id) || id.contains($0.id) }
    }

    /// Records evidence; an unknown subskill is added to the topic.
    @discardableResult
    func record(
        _ kind: EvidenceKind,
        topic topicName: String,
        subskill skillName: String,
        placedLevel: Int? = nil,
        note: String = ""
    ) throws -> LevelChange {
        guard let topic = topic(named: topicName), let t = state.topics.firstIndex(where: { $0.id == topic.id }) else {
            throw LearnerError.unknownTopic(topicName)
        }
        let skillID = LearnerRules.slug(skillName)
        var s = state.topics[t].subskills.firstIndex { $0.id == skillID }
            ?? state.topics[t].subskills.firstIndex { $0.id.contains(skillID) || skillID.contains($0.id) }
        if s == nil {
            state.topics[t].subskills.append(Subskill(name: skillName))
            s = state.topics[t].subskills.count - 1
        }
        let change = LearnerRules.apply(kind, placedLevel: placedLevel, note: note, to: &state.topics[t].subskills[s!], now: now())
        state.topics[t].updatedAt = now()
        save()
        return change
    }

    /// Scoreboard and evidence for a finished desk task.
    @discardableResult
    func recordTaskOutcome(kind: TaskKind, outcome: String, topic: String?, subskill: String?, note: String) -> LevelChange? {
        if currentSessionID == nil { beginSession() }
        if let index = state.sessions.lastIndex(where: { $0.id == currentSessionID }) {
            let passed = outcome == "independent"
            switch (kind, outcome) {
            case (.practice, "independent"): state.sessions[index].practiceIndependent += 1
            case (.practice, "assisted"): state.sessions[index].practiceAssisted += 1
            case (.practice, _): state.sessions[index].practiceAbandoned += 1
            case (.warmUp, _): passed ? (state.sessions[index].warmUpPassed += 1) : (state.sessions[index].warmUpFailed += 1)
            case (.exitTicket, _): passed ? (state.sessions[index].exitPassed += 1) : (state.sessions[index].exitFailed += 1)
            }
        }
        defer { save() }
        guard let topic, let subskill, !topic.isEmpty, !subskill.isEmpty else { return nil }
        let evidence: EvidenceKind = switch (kind, outcome) {
        case (.practice, "independent"): .prompted
        case (_, "independent"): .unprompted
        case (_, "assisted"): .assisted
        default: .incorrect
        }
        return try? record(evidence, topic: topic, subskill: subskill, note: note)
    }

    // MARK: reports

    func warmUp(limit: Int = 3) -> [(topic: Topic, skill: Subskill)] {
        LearnerRules.warmUp(from: state.topics, now: now(), limit: limit)
    }

    func sessionContext() -> String {
        LearnerReport.sessionContext(state, now: now())
    }

    func progressMarkdown(topic name: String? = nil) -> String {
        let topics = name.flatMap { topic(named: $0) }.map { [$0] }
            ?? state.topics.sorted { $0.updatedAt > $1.updatedAt }
        var parts = topics.prefix(4).map { LearnerReport.skillMap($0, now: now()) }
        if parts.isEmpty { parts.append("No topics yet.") }
        let scores = LearnerReport.scoreboards(currentSession)
        if !scores.isEmpty { parts.append("#### This session\n" + scores) }
        let due = warmUp()
        if !due.isEmpty {
            parts.append("**Due for review:** " + due.map { "\($0.skill.name)" }.joined(separator: ", "))
        }
        return parts.joined(separator: "\n\n")
    }

    // MARK: persistence

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(state) else { return }
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }
}
