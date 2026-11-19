import Foundation
import Observation

@MainActor
@Observable
final class CourseLibrary {
    private(set) var courses: [StudyCourse] = []
    private(set) var selectedCourseID: String?
    private(set) var isImporting = false
    private(set) var importStatus = ""
    var errorMessage: String?
    private(set) var studyPreferences = StudySchedulePreferences()
    private(set) var studyPlan: StudyPlan?
    @ObservationIgnored private let rootURL: URL
    @ObservationIgnored private var index: CourseSearchIndex?

    private struct Catalog: Codable {
        var courses: [StudyCourse]
        var selectedCourseID: String?
        var studyPreferences: StudySchedulePreferences?
        var studyPlan: StudyPlan?
    }

    init(rootURL: URL = CourseLibrary.defaultURL) {
        self.rootURL = rootURL
        do {
            try FileManager.default.createDirectory(at: rootURL.appendingPathComponent("Files"), withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: catalogURL.path) {
                let catalog = try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: catalogURL))
                courses = catalog.courses
                selectedCourseID = catalog.selectedCourseID
                studyPreferences = catalog.studyPreferences ?? StudySchedulePreferences()
                studyPlan = catalog.studyPlan
            }
            index = try CourseSearchIndex(url: rootURL.appendingPathComponent("search.sqlite"))
        } catch { errorMessage = error.localizedDescription }
    }

    static var defaultURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ScreenTutor/Courses")
    }

    var selectedCourse: StudyCourse? { courses.first { $0.id == selectedCourseID } }
    private var catalogURL: URL { rootURL.appendingPathComponent("courses.json") }

    @discardableResult
    func createCourse(title: String) throws -> StudyCourse {
        guard index != nil else { throw CourseLibraryError.invalid(errorMessage ?? "The course library is unavailable.") }
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw CourseLibraryError.invalid("Give the course a name.") }
        let course = StudyCourse(id: UUID().uuidString.lowercased(), title: title)
        var updated = courses
        updated.append(course)
        try save(courses: updated, selection: course.id)
        courses = updated
        selectedCourseID = course.id
        return course
    }

    func selectCourse(_ id: String) throws {
        guard courses.contains(where: { $0.id == id }) else { throw CourseLibraryError.invalid("Unknown course.") }
        try save(courses: courses, selection: id)
        selectedCourseID = id
    }

    func importFiles(_ urls: [URL], into courseID: String) async throws {
        guard !isImporting else { throw CourseLibraryError.invalid("A course import is already running.") }
        guard let index, courses.contains(where: { $0.id == courseID }) else { throw CourseLibraryError.invalid("Select an available course first.") }
        isImporting = true
        errorMessage = nil
        defer { isImporting = false; importStatus = "" }
        for url in urls {
            try Task.checkCancellation()
            importStatus = "Reading \(url.lastPathComponent)…"
            let extracted = try await Task.detached(priority: .userInitiated) { try CourseMaterialReader.read(url) }.value
            guard let position = courses.firstIndex(where: { $0.id == courseID }) else { throw CourseLibraryError.invalid("The course is no longer available.") }
            if courses[position].materials.contains(where: { $0.digest == extracted.digest }) { continue }
            let id = UUID().uuidString.lowercased()
            let material = CourseMaterial(id: id, title: extracted.title, filename: "\(id).\(extracted.fileExtension)",
                                          digest: extracted.digest, pages: extracted.pages.count)
            let destination = rootURL.appendingPathComponent("Files/\(material.filename)")
            try extracted.data.write(to: destination, options: .atomic)
            try index.replace(material: material, courseID: courseID, pages: extracted.pages)
            var updated = courses
            updated[position].materials.append(material)
            try save(courses: updated, selection: selectedCourseID)
            courses = updated
        }
    }

    func search(_ query: String, courseID: String) throws -> [CourseExcerpt] {
        guard courses.contains(where: { $0.id == courseID }), let index else { throw CourseLibraryError.invalid("Select an available course first.") }
        return try index.search(query, courseID: courseID)
    }

    func sourceURL(materialID: String) throws -> URL {
        guard let material = courses.flatMap(\.materials).first(where: { $0.id == materialID }) else {
            throw CourseLibraryError.invalid("This material is no longer in the course library.")
        }
        return rootURL.appendingPathComponent("Files/\(material.filename)")
    }

    func context() -> String {
        guard let course = selectedCourse else { return "No course selected. Ask the learner to import their course materials before claiming course-specific context." }
        return "Selected course: \(course.title) (\(course.id)).\nMaterials:\n"
            + course.materials.map { "\($0.id): \($0.title) (\($0.pages) pages)" }.joined(separator: "\n")
            + "\nUse search_course_materials before making claims about these sources. Inventory is metadata, not evidence of contents."
    }

    func setStudySchedule(preferences: StudySchedulePreferences, plan: StudyPlan) throws {
        let oldPreferences = studyPreferences
        let oldPlan = studyPlan
        studyPreferences = preferences
        studyPlan = plan
        do { try save(courses: courses, selection: selectedCourseID) }
        catch { studyPreferences = oldPreferences; studyPlan = oldPlan; throw error }
    }

    private func save(courses: [StudyCourse], selection: String?) throws {
        try JSONEncoder().encode(Catalog(courses: courses, selectedCourseID: selection,
            studyPreferences: studyPreferences, studyPlan: studyPlan)).write(to: catalogURL, options: .atomic)
    }
}
