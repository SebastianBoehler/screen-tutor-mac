import Foundation

struct StudyCourse: Codable, Identifiable, Equatable, Sendable {
    let id: String
    var title: String
    var materials: [CourseMaterial] = []
}

struct CourseMaterial: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let filename: String
    let digest: String
    let pages: Int
}

struct CourseExcerpt: Codable, Equatable, Sendable {
    let materialID: String
    let title: String
    let page: Int
    let text: String

    var source: String { "[\(title), p. \(page)](screentutor-source://\(materialID)/\(page))" }
}

enum CourseLibraryError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { switch self { case .invalid(let message): message } }
}
