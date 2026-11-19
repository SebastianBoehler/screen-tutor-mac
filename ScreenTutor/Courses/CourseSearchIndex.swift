import Foundation
import SQLite3

/// The index stays on the Mac. Search returns bounded, page-labelled excerpts to the tutor.
@MainActor
final class CourseSearchIndex {
    // Only this main-actor owner uses the handle; deinit closes it without dispatching work.
    nonisolated(unsafe) private var database: OpaquePointer?
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    init(url: URL) throws {
        guard sqlite3_open(url.path, &database) == SQLITE_OK else { throw failure() }
        try execute("CREATE VIRTUAL TABLE IF NOT EXISTS chunks USING fts5(course_id UNINDEXED, material_id UNINDEXED, title, page UNINDEXED, text, tokenize='unicode61')")
    }

    deinit { sqlite3_close(database) }

    func replace(material: CourseMaterial, courseID: String, pages: [String]) throws {
        try execute("BEGIN IMMEDIATE")
        do {
            try execute("DELETE FROM chunks WHERE material_id = ? AND course_id = ?", values: [material.id, courseID])
            for (page, text) in pages.enumerated() {
                var start = text.startIndex
                while start < text.endIndex {
                    let end = text.index(start, offsetBy: 1_400, limitedBy: text.endIndex) ?? text.endIndex
                    let chunk = String(text[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !chunk.isEmpty {
                        try execute("INSERT INTO chunks(course_id, material_id, title, page, text) VALUES(?,?,?,?,?)",
                                    values: [courseID, material.id, material.title, String(page + 1), chunk])
                    }
                    start = end
                }
            }
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    func search(_ query: String, courseID: String) throws -> [CourseExcerpt] {
        let words = query.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init).filter { $0.count > 1 }
        guard !words.isEmpty else { throw CourseLibraryError.invalid("Give at least one search term with two characters.") }
        let match = Array(Set(words)).sorted().map { "\"\($0)\"" }.joined(separator: " OR ")
        let statement = try prepare("SELECT material_id,title,page,text FROM chunks WHERE course_id=? AND chunks MATCH ? ORDER BY bm25(chunks) LIMIT 6",
                                    values: [courseID, match])
        defer { sqlite3_finalize(statement) }
        var excerpts: [CourseExcerpt] = []
        var status = sqlite3_step(statement)
        while status == SQLITE_ROW {
            func value(_ column: Int32) -> String { String(cString: sqlite3_column_text(statement, column)) }
            excerpts.append(CourseExcerpt(materialID: value(0), title: value(1), page: Int(value(2)) ?? 1, text: value(3)))
            status = sqlite3_step(statement)
        }
        guard status == SQLITE_DONE else { throw failure() }
        return excerpts
    }

    private func execute(_ sql: String, values: [String] = []) throws {
        let statement = try prepare(sql, values: values)
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_DONE else { throw failure() }
    }

    private func prepare(_ sql: String, values: [String]) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw failure() }
        for (index, value) in values.enumerated() {
            guard sqlite3_bind_text(statement, Int32(index + 1), value, -1, transient) == SQLITE_OK else {
                sqlite3_finalize(statement)
                throw failure()
            }
        }
        return statement
    }

    private func failure() -> CourseLibraryError {
        .invalid("Course index: \(database.map { String(cString: sqlite3_errmsg($0)) } ?? "could not open the database").")
    }
}
