import CryptoKit
import Foundation
import PDFKit

struct ExtractedCourseMaterial: Sendable {
    let data: Data
    let title: String
    let fileExtension: String
    let digest: String
    let pages: [String]
}

enum CourseMaterialReader {
    static func read(_ url: URL) throws -> ExtractedCourseMaterial {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let ext = url.pathExtension.lowercased()
        guard ["pdf", "md", "markdown", "txt"].contains(ext) else {
            throw CourseLibraryError.invalid("Import a PDF, Markdown or UTF-8 text file: \(url.lastPathComponent).")
        }
        let data = try Data(contentsOf: url)
        let pages: [String]
        if ext == "pdf" {
            guard let pdf = PDFDocument(data: data), !pdf.isLocked else {
                throw CourseLibraryError.invalid("Cannot read \(url.lastPathComponent). Unlock the PDF before importing it.")
            }
            pages = (0..<pdf.pageCount).map { pdf.page(at: $0)?.string ?? "" }
        } else {
            guard let text = String(data: data, encoding: .utf8) else {
                throw CourseLibraryError.invalid("\(url.lastPathComponent) is not readable UTF-8 text.")
            }
            pages = [text]
        }
        guard pages.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw CourseLibraryError.invalid("No searchable text in \(url.lastPathComponent). Scanned PDFs need a text layer before import.")
        }
        return ExtractedCourseMaterial(data: data, title: url.lastPathComponent, fileExtension: ext,
            digest: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(), pages: pages)
    }
}
