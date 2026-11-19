import Foundation

struct LearningArtifact: Codable, Equatable, Identifiable, Sendable {
    let id: String
    var title: String
    var markdown: String
    var section: String
    var flashcard: FlashcardContent? = nil
}

struct FlashcardContent: Codable, Equatable, Sendable {
    let answer: String
    var revealed = false
    var selfRating: String?
}

struct LearnerInsight: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let observation: String
    let evidence: String
    let teachingImplication: String
}

struct WorkspaceMessage: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let role: String
    var text: String
    var artifactID: String?
}

enum StudyMode: String, Codable, Sendable, CaseIterable {
    case learn, practice, exam
    var title: String {
        switch self {
        case .learn: "Learn"
        case .practice: "Practice"
        case .exam: "Mock exam"
        }
    }
}
