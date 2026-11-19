import XCTest
@testable import ScreenTutor

@MainActor
final class CourseLibraryTests: XCTestCase {
    func testImportSearchIsolationDuplicateAndReload() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = CourseLibrary(rootURL: root)
        let course = try library.createCourse(title: "Optimization")
        let file = root.appendingPathComponent("lecture.md")
        try "Gradient descent updates parameters opposite the gradient. The learning rate is eta.".write(to: file, atomically: true, encoding: .utf8)
        try await library.importFiles([file], into: course.id)
        try await library.importFiles([file], into: course.id)
        XCTAssertEqual(library.selectedCourse?.materials.count, 1)
        let found = try library.search("gradient descent", courseID: course.id)
        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found[0].page, 1)
        XCTAssertEqual(found[0].title, "lecture.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: try library.sourceURL(materialID: found[0].materialID).path))
        let other = try library.createCourse(title: "Statistics")
        XCTAssertTrue(try library.search("gradient", courseID: other.id).isEmpty)
        let reloaded = CourseLibrary(rootURL: root)
        XCTAssertEqual(reloaded.courses.count, 2)
        XCTAssertEqual(try reloaded.search("eta", courseID: course.id).count, 1)
        XCTAssertThrowsError(try library.search("", courseID: course.id))
    }

    func testUnreadableOrUnsupportedMaterialIsExplicitAndDoesNotAddAMaterial() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = CourseLibrary(rootURL: root)
        let course = try library.createCourse(title: "Signals")
        let file = root.appendingPathComponent("lecture.zip")
        try Data([1, 2, 3]).write(to: file)
        do {
            try await library.importFiles([file], into: course.id)
            XCTFail("Unsupported files must fail.")
        } catch { XCTAssertTrue(error.localizedDescription.contains("PDF")) }
        XCTAssertTrue(library.selectedCourse?.materials.isEmpty == true)
    }
}
