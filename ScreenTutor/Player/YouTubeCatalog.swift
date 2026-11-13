import Foundation

struct VideoSearchResult: Sendable, Equatable {
    let id: String
    let title: String
    let channel: String
    let length: String
}

struct VideoChapter: Sendable, Equatable {
    let seconds: Int
    let title: String
}

struct VideoDetails: Sendable, Equatable {
    let id: String
    let title: String
    let channel: String
    let lengthSeconds: Int
    let chapters: [VideoChapter]
}

/// YouTube search and video details from the public web pages, without an API
/// key. Only ids, titles, channels, lengths and chapter timestamps are read.
struct YouTubeCatalog: Sendable {
    var session: URLSession = .shared

    static func isValidVideoID(_ id: String) -> Bool {
        id.range(of: #"^[A-Za-z0-9_-]{11}$"#, options: .regularExpression) != nil
    }

    func search(_ query: String, limit: Int = 6) async throws -> [VideoSearchResult] {
        var components = URLComponents(string: "https://www.youtube.com/results")!
        components.queryItems = [.init(name: "search_query", value: query), .init(name: "hl", value: "en")]
        let html = try await page(components.url!)
        guard let data = Self.embeddedJSON(named: "ytInitialData", in: html) else { throw YouTubeError.unreadablePage }
        return Array(Self.searchResults(fromInitialData: data).prefix(limit))
    }

    func details(videoID: String) async throws -> VideoDetails {
        guard Self.isValidVideoID(videoID) else { throw YouTubeError.invalidVideoID }
        let html = try await page(URL(string: "https://www.youtube.com/watch?v=\(videoID)&hl=en")!)
        guard
            let data = Self.embeddedJSON(named: "ytInitialPlayerResponse", in: html),
            let player = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let video = player["videoDetails"] as? [String: Any]
        else { throw YouTubeError.unreadablePage }
        let description = video["shortDescription"] as? String ?? ""
        return VideoDetails(
            id: videoID,
            title: video["title"] as? String ?? "",
            channel: video["author"] as? String ?? "",
            lengthSeconds: Int(video["lengthSeconds"] as? String ?? "") ?? 0,
            chapters: Self.chapters(fromDescription: description)
        )
    }

    private func page(_ url: URL) async throws -> String {
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        // Skips the EU consent interstitial (rejects non-essential cookies).
        request.setValue("SOCS=CAI", forHTTPHeaderField: "Cookie")
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200, let html = String(data: data, encoding: .utf8) else {
            throw YouTubeError.unreadablePage
        }
        return html
    }

    // MARK: parsing (static for tests)

    /// The JSON object assigned to `name` in an inline script, by brace matching.
    static func embeddedJSON(named name: String, in html: String) -> Data? {
        guard let marker = html.range(of: "\(name) = ") ?? html.range(of: "\(name)=") else { return nil }
        let bytes = Array(html.utf8[marker.upperBound...])
        guard bytes.first == UInt8(ascii: "{") else { return nil }
        var depth = 0
        var inString = false
        var escaped = false
        for (index, byte) in bytes.enumerated() {
            if inString {
                if escaped { escaped = false } else if byte == UInt8(ascii: "\\") { escaped = true } else if byte == UInt8(ascii: "\"") { inString = false }
                continue
            }
            switch byte {
            case UInt8(ascii: "\""): inString = true
            case UInt8(ascii: "{"): depth += 1
            case UInt8(ascii: "}"):
                depth -= 1
                if depth == 0 { return Data(bytes[0...index]) }
            default: break
            }
        }
        return nil
    }

    static func searchResults(fromInitialData data: Data) -> [VideoSearchResult] {
        guard let root = try? JSONSerialization.jsonObject(with: data) else { return [] }
        var results: [VideoSearchResult] = []
        func text(_ value: Any?) -> String {
            guard let object = value as? [String: Any] else { return "" }
            if let simple = object["simpleText"] as? String { return simple }
            return (object["runs"] as? [[String: Any]])?.compactMap { $0["text"] as? String }.joined() ?? ""
        }
        func walk(_ node: Any) {
            if let object = node as? [String: Any] {
                if let video = object["videoRenderer"] as? [String: Any],
                   let id = video["videoId"] as? String, isValidVideoID(id) {
                    results.append(
                        VideoSearchResult(id: id, title: text(video["title"]), channel: text(video["ownerText"]), length: text(video["lengthText"]))
                    )
                }
                object.values.forEach(walk)
            } else if let array = node as? [Any] {
                array.forEach(walk)
            }
        }
        walk(root)
        var seen = Set<String>()
        return results.filter { seen.insert($0.id).inserted }
    }

    /// Chapter lines like "3:01 Cost functions" or "(1:02:03) - Wrap-up".
    static func chapters(fromDescription description: String) -> [VideoChapter] {
        let pattern = #"(?m)^\s*\(?((?:\d{1,2}:)?\d{1,2}:\d{2})\)?\s*[-–—:]?\s*(.+?)\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(description.startIndex..., in: description)
        let chapters = regex.matches(in: description, range: range).compactMap { match -> VideoChapter? in
            guard
                let timeRange = Range(match.range(at: 1), in: description),
                let titleRange = Range(match.range(at: 2), in: description)
            else { return nil }
            return VideoChapter(seconds: seconds(from: String(description[timeRange])), title: String(description[titleRange]))
        }
        // Real chapter lists start at 0:00 and increase.
        guard chapters.first?.seconds == 0, zip(chapters, chapters.dropFirst()).allSatisfy({ $0.seconds < $1.seconds }) else {
            return []
        }
        return chapters
    }

    static func seconds(from timestamp: String) -> Int {
        timestamp.split(separator: ":").reduce(0) { $0 * 60 + (Int($1) ?? 0) }
    }

    static func timestamp(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let (h, m, s) = (total / 3600, total % 3600 / 60, total % 60)
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}

enum YouTubeError: LocalizedError {
    case unreadablePage
    case invalidVideoID

    var errorDescription: String? {
        switch self {
        case .unreadablePage: "YouTube did not return a readable page."
        case .invalidVideoID: "That is not a valid YouTube video id."
        }
    }
}
