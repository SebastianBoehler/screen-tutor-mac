import Foundation
import Observation

@MainActor
@Observable
final class LearningWorkspaceStore {
    private(set) var artifacts: [LearningArtifact] = []
    private(set) var messages: [WorkspaceMessage] = []
    private(set) var focusedArtifactID: String?
    private(set) var courseID: String?
    private(set) var mode: StudyMode = .learn
    private(set) var insights: [LearnerInsight] = []
    private(set) var learningGoal: LearningGoal?
    private(set) var studyPlan: StudyPlan?
    var errorMessage: String?
    @ObservationIgnored private let rootURL: URL

    private struct State: Codable {
        var artifacts: [LearningArtifact] = []
        var messages: [WorkspaceMessage] = []
        var focusedArtifactID: String?
        var mode: StudyMode = .learn
        var insights: [LearnerInsight] = []
        var learningGoal: LearningGoal?
        var studyPlan: StudyPlan?
    }

    init(rootURL: URL = LearningWorkspaceStore.defaultURL) { self.rootURL = rootURL }

    static var defaultURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ScreenTutor/Workspaces")
    }

    var sections: [String] {
        artifacts.reduce(into: []) { if !$0.contains($1.section) { $0.append($1.section) } }
    }

    func selectCourse(_ id: String?) throws {
        if let id, id.isEmpty || id.contains(where: { !$0.isLetter && !$0.isNumber && $0 != "-" && $0 != "_" }) {
            throw CourseLibraryError.invalid("Invalid workspace identifier.")
        }
        let url = fileURL(courseID: id)
        let state = FileManager.default.fileExists(atPath: url.path)
            ? try JSONDecoder().decode(State.self, from: Data(contentsOf: url)) : State()
        courseID = id
        artifacts = state.artifacts
        messages = state.messages
        focusedArtifactID = state.focusedArtifactID
        mode = state.mode
        insights = state.insights
        learningGoal = state.learningGoal
        studyPlan = state.studyPlan
        errorMessage = nil
    }

    func presentArtifact(id: String, title: String, markdown: String, section: String, flashcardAnswer: String? = nil) throws {
        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !section.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { throw CourseLibraryError.invalid("Artifacts need an ID, title, content and section.") }
        let artifact = LearningArtifact(id: id, title: title, markdown: markdown, section: section,
                                        flashcard: flashcardAnswer.map { FlashcardContent(answer: $0) })
        var state = currentState
        if let position = state.artifacts.firstIndex(where: { $0.id == id }) { state.artifacts[position] = artifact }
        else {
            state.artifacts.append(artifact)
            state.messages.append(WorkspaceMessage(id: "artifact-\(id)", role: "artifact", text: title, artifactID: id))
        }
        state.focusedArtifactID = id
        try commit(state)
    }

    func organize(artifactIDs: [String], section: String) throws {
        guard !artifactIDs.isEmpty, Set(artifactIDs).count == artifactIDs.count,
              !section.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              artifactIDs.allSatisfy({ id in artifacts.contains { $0.id == id } })
        else { throw CourseLibraryError.invalid("Organize existing artifact IDs into a named section.") }
        var state = currentState
        let selected = artifactIDs.compactMap { id in state.artifacts.first { $0.id == id } }.map { artifact in
            var changed = artifact
            changed.section = section
            return changed
        }
        state.artifacts = selected + state.artifacts.filter { !artifactIDs.contains($0.id) }
        try commit(state)
    }

    func focus(_ id: String?) throws {
        guard id == nil || artifacts.contains(where: { $0.id == id }) else { throw CourseLibraryError.invalid("Unknown artifact.") }
        var state = currentState
        state.focusedArtifactID = id
        try commit(state)
    }

    func setMode(_ mode: StudyMode) throws {
        var state = currentState
        state.mode = mode
        try commit(state)
    }

    func recordMessage(id: String, role: String, text: String) throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        var state = currentState
        if let position = state.messages.firstIndex(where: { $0.id == id }) { state.messages[position].text = text }
        else { state.messages.append(WorkspaceMessage(id: id, role: role, text: text)) }
        try commit(state)
    }

    func reviewFlashcard(id: String, action: String) throws {
        guard let position = artifacts.firstIndex(where: { $0.id == id }),
              var card = artifacts[position].flashcard, ["reveal", "again", "recalled"].contains(action),
              action == "reveal" || card.revealed
        else { throw CourseLibraryError.invalid("Reveal a flashcard before recording a self-rating.") }
        var state = currentState
        if action == "reveal" { card.revealed = true }
        else { card.selfRating = action }
        state.artifacts[position].flashcard = card
        try commit(state)
    }

    func recordInsight(observation: String, evidence: String, implication: String) throws {
        guard [observation, evidence, implication].allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw CourseLibraryError.invalid("Learning insights need an observation, learner evidence and a teaching implication.")
        }
        var state = currentState
        state.insights.append(LearnerInsight(id: UUID().uuidString, observation: observation,
                                            evidence: evidence, teachingImplication: implication))
        try commit(state)
    }

    func updateInsight(id: String, observation: String, evidence: String, implication: String) throws {
        guard let index = insights.firstIndex(where: { $0.id == id }),
              [observation, evidence, implication].allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        else { throw CourseLibraryError.invalid("The note needs an observation, evidence and a teaching hypothesis.") }
        var state = currentState
        state.insights[index] = LearnerInsight(id: id, observation: observation, evidence: evidence, teachingImplication: implication)
        try commit(state)
    }

    func removeInsight(id: String) throws {
        var state = currentState
        state.insights.removeAll { $0.id == id }
        try commit(state)
    }

    func setLearningGoal(_ goal: LearningGoal) throws {
        var state = currentState
        state.learningGoal = goal
        try commit(state)
    }

    func setStudyPlan(_ plan: StudyPlan) throws {
        var state = currentState
        state.studyPlan = plan
        try commit(state)
    }

    func goal(forCourse id: String) throws -> LearningGoal? {
        if courseID == id { return learningGoal }
        let url = fileURL(courseID: id)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(State.self, from: Data(contentsOf: url)).learningGoal
    }

    private var currentState: State {
        State(artifacts: artifacts, messages: messages, focusedArtifactID: focusedArtifactID, mode: mode, insights: insights,
              learningGoal: learningGoal, studyPlan: studyPlan)
    }

    private func fileURL(courseID: String?) -> URL { rootURL.appendingPathComponent("\(courseID ?? "general").json") }

    private func commit(_ state: State) throws {
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try JSONEncoder().encode(state).write(to: fileURL(courseID: courseID), options: .atomic)
        artifacts = state.artifacts
        messages = state.messages
        focusedArtifactID = state.focusedArtifactID
        mode = state.mode
        insights = state.insights
        learningGoal = state.learningGoal
        studyPlan = state.studyPlan
    }
}
