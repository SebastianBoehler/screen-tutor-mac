import AppKit
import Foundation

/// High-level Mac actions the voice tutor may take on the learner's behalf.
/// Each action is narrow, validated, and visible: it opens something in the
/// foreground rather than silently driving the mouse or keyboard.
@MainActor
final class DesktopActions {
    private let workspace: NSWorkspace
    private let fileManager: FileManager

    init(workspace: NSWorkspace = .shared, fileManager: FileManager = .default) {
        self.workspace = workspace
        self.fileManager = fileManager
    }

    func openURL(_ string: String) throws -> URL {
        guard
            let url = URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines)),
            let scheme = url.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            url.host?.isEmpty == false
        else { throw DesktopActionError.invalidURL }
        guard workspace.open(url) else { throw DesktopActionError.openFailed(url.absoluteString) }
        return url
    }

    func searchYouTube(_ query: String) throws -> URL {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw DesktopActionError.emptyQuery }
        var components = URLComponents(string: "https://www.youtube.com/results")!
        components.queryItems = [URLQueryItem(name: "search_query", value: trimmed)]
        return try openURL(components.url!.absoluteString)
    }

    func openApplication(named name: String) async throws -> String {
        guard let appURL = applicationURL(named: name) else {
            throw DesktopActionError.applicationNotFound(name)
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        _ = try await workspace.openApplication(at: appURL, configuration: configuration)
        return appURL.deletingPathExtension().lastPathComponent
    }

    /// Writes a document into ~/Downloads/ScreenTutor and opens it in the default app.
    func createDocument(title: String, markdown: String, format: DocumentFormat) throws -> URL {
        let folder = try documentsFolder()
        let url = uniqueURL(in: folder, baseName: Self.safeFileName(title), extension: format.fileExtension)
        switch format {
        case .markdown:
            try "# \(title)\n\n\(markdown)\n".write(to: url, atomically: true, encoding: .utf8)
        case .word, .richText:
            let html = MarkdownHTML.document(title: title, markdown: markdown)
            guard let htmlData = html.data(using: .utf8) else { throw DesktopActionError.writeFailed }
            let attributed = try NSAttributedString(
                data: htmlData,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
            )
            let documentType: NSAttributedString.DocumentType =
                format == .word ? .officeOpenXML : .rtf
            let data = try attributed.data(
                from: NSRange(location: 0, length: attributed.length),
                documentAttributes: [.documentType: documentType, .title: title]
            )
            try data.write(to: url, options: .atomic)
        }
        workspace.open(url)
        return url
    }

    private func documentsFolder() throws -> URL {
        guard let downloads = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            throw DesktopActionError.writeFailed
        }
        let folder = downloads.appendingPathComponent("ScreenTutor", isDirectory: true)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private func uniqueURL(in folder: URL, baseName: String, extension ext: String) -> URL {
        var candidate = folder.appendingPathComponent(baseName).appendingPathExtension(ext)
        var counter = 2
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(baseName) \(counter)").appendingPathExtension(ext)
            counter += 1
        }
        return candidate
    }

    nonisolated static func safeFileName(_ title: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\:?%*|\"<>\n\r\t")
        let cleaned = title.components(separatedBy: forbidden).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let limited = String(cleaned.prefix(80))
        return limited.isEmpty ? "ScreenTutor note" : limited
    }

    private func applicationURL(named rawName: String) -> URL? {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        if name.contains("."), let url = workspace.urlForApplication(withBundleIdentifier: name) {
            return url
        }
        let wanted = name.lowercased().replacingOccurrences(of: ".app", with: "")
        let aliases: [String: String] = [
            "word": "microsoft word", "excel": "microsoft excel",
            "powerpoint": "microsoft powerpoint", "vscode": "visual studio code",
            "vs code": "visual studio code", "chrome": "google chrome"
        ]
        let target = aliases[wanted] ?? wanted
        let roots = [
            "/Applications", "/System/Applications", "/System/Applications/Utilities",
            "/Applications/Utilities", NSHomeDirectory() + "/Applications"
        ]
        var fallback: URL?
        for root in roots {
            guard let entries = try? fileManager.contentsOfDirectory(atPath: root) else { continue }
            for entry in entries where entry.hasSuffix(".app") {
                let base = String(entry.dropLast(4)).lowercased()
                let url = URL(fileURLWithPath: root).appendingPathComponent(entry)
                if base == target { return url }
                if fallback == nil, base.contains(target) { fallback = url }
            }
        }
        return fallback
    }
}

enum DocumentFormat: String, Sendable {
    case word = "docx"
    case markdown = "md"
    case richText = "rtf"

    var fileExtension: String { rawValue }
}

enum DesktopActionError: LocalizedError {
    case invalidURL
    case emptyQuery
    case openFailed(String)
    case applicationNotFound(String)
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Only complete http or https URLs can be opened."
        case .emptyQuery: "The search query is empty."
        case .openFailed(let url): "macOS could not open \(url)."
        case .applicationNotFound(let name): "No installed application matches “\(name)”."
        case .writeFailed: "The document could not be written."
        }
    }
}

/// A small Markdown-to-HTML converter for documents: headings, lists, code
/// blocks, emphasis and inline code. Math stays as readable LaTeX text.
enum MarkdownHTML {
    static func document(title: String, markdown: String) -> String {
        """
        <html><head><meta charset="utf-8"><title>\(escape(title))</title>
        <style>body{font-family:-apple-system,Helvetica,Arial;font-size:12pt;line-height:1.4}
        h1{font-size:20pt}h2{font-size:16pt}h3{font-size:13pt}
        pre,code{font-family:Menlo,monospace;font-size:10.5pt}</style></head>
        <body><h1>\(escape(title))</h1>\(body(markdown))</body></html>
        """
    }

    static func body(_ markdown: String) -> String {
        var html: [String] = []
        var paragraph: [String] = []
        var listTag: String?
        var inCode = false
        var code: [String] = []

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            html.append("<p>\(inline(paragraph.joined(separator: " ")))</p>")
            paragraph.removeAll()
        }
        func closeList() {
            if let tag = listTag { html.append("</\(tag)>") }
            listTag = nil
        }

        for rawLine in markdown.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("```") {
                if inCode {
                    html.append("<pre>\(escape(code.joined(separator: "\n")))</pre>")
                    code.removeAll()
                } else {
                    flushParagraph(); closeList()
                }
                inCode.toggle()
                continue
            }
            if inCode { code.append(rawLine); continue }
            if line.isEmpty { flushParagraph(); closeList(); continue }

            if let heading = headingLevel(line) {
                flushParagraph(); closeList()
                let text = line.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
                html.append("<h\(heading)>\(inline(text))</h\(heading)>")
            } else if let item = bulletItem(line) {
                flushParagraph()
                if listTag != "ul" { closeList(); html.append("<ul>"); listTag = "ul" }
                html.append("<li>\(inline(item))</li>")
            } else if let item = numberedItem(line) {
                flushParagraph()
                if listTag != "ol" { closeList(); html.append("<ol>"); listTag = "ol" }
                html.append("<li>\(inline(item))</li>")
            } else {
                closeList()
                paragraph.append(line)
            }
        }
        if inCode { html.append("<pre>\(escape(code.joined(separator: "\n")))</pre>") }
        flushParagraph(); closeList()
        return html.joined(separator: "\n")
    }

    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    static func inline(_ text: String) -> String {
        var result = escape(text)
        result = replace(#"`([^`]+)`"#, in: result, with: "<code>$1</code>")
        result = replace(#"\*\*([^*]+)\*\*"#, in: result, with: "<b>$1</b>")
        result = replace(#"(?<![*\w])\*([^*]+)\*(?!\*)"#, in: result, with: "<i>$1</i>")
        return result
    }

    private static func replace(_ pattern: String, in text: String, with template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        return regex.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text),
            withTemplate: template
        )
    }

    private static func headingLevel(_ line: String) -> Int? {
        let hashes = line.prefix(while: { $0 == "#" }).count
        guard (1...4).contains(hashes), line.dropFirst(hashes).first == " " else { return nil }
        return min(hashes + 1, 4)
    }

    private static func bulletItem(_ line: String) -> String? {
        for marker in ["- ", "* ", "• "] where line.hasPrefix(marker) {
            return String(line.dropFirst(marker.count))
        }
        return nil
    }

    private static func numberedItem(_ line: String) -> String? {
        guard
            let dot = line.firstIndex(of: "."),
            line[..<dot].allSatisfy(\.isNumber),
            !line[..<dot].isEmpty,
            line[line.index(after: dot)...].first == " "
        else { return nil }
        return String(line[line.index(dot, offsetBy: 2)...])
    }
}
