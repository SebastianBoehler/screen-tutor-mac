import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import Vision

/// A thing on screen the annotation agent can refer to by id: a recognized text
/// line (ids "t…") or a UI control from the accessibility tree (ids "u…").
struct ScreenElement: Sendable, Equatable {
    let id: String
    /// "text" for recognized text, otherwise a short accessibility role.
    let kind: String
    let label: String
    /// CoreGraphics global points, top-left origin.
    let rect: CGRect
    /// Word boxes inside a text line, for marking part of a line.
    let tokens: [ScreenTextToken]

    /// The box around `substring` within this element, or nil when it is not found.
    func rect(of substring: String) -> CGRect? {
        let needle = substring.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty, !tokens.isEmpty else { return nil }
        // Every occurrence, preferring one that starts and ends on word boundaries
        // ("eta" the symbol, not the end of "theta").
        var occurrences: [(start: Int, end: Int)] = []
        var searchStart = label.startIndex
        while let range = label.range(
            of: needle,
            options: [.caseInsensitive, .diacriticInsensitive],
            range: searchStart..<label.endIndex
        ) {
            occurrences.append((
                label.distance(from: label.startIndex, to: range.lowerBound),
                label.distance(from: label.startIndex, to: range.upperBound)
            ))
            searchStart = label.index(after: range.lowerBound)
        }
        let isWordStart = { (offset: Int) in self.tokens.contains { $0.start == offset } }
        let isWordEnd = { (offset: Int) in self.tokens.contains { $0.end == offset } }
        let best = occurrences.max { a, b in
            let scoreA = (isWordStart(a.start) ? 2 : 0) + (isWordEnd(a.end) ? 1 : 0)
            let scoreB = (isWordStart(b.start) ? 2 : 0) + (isWordEnd(b.end) ? 1 : 0)
            return scoreA < scoreB
        }
        guard let best else { return nil }
        let covered = tokens.filter { $0.start < best.end && $0.end > best.start }
        guard var union = covered.first?.rect else { return nil }
        for token in covered.dropFirst() { union = union.union(token.rect) }
        return union
    }
}

struct ScreenTextToken: Sendable, Equatable {
    let start: Int
    let end: Int
    let rect: CGRect
}

struct ScreenReading: Sendable {
    /// The captured display in CoreGraphics global points.
    let displayFrame: CGRect
    let elements: [ScreenElement]
    let modelJPEG: Data
    let frontApplication: String?

    /// Element list for the model: id, box in 0–1000 of the display, label.
    func elementListing(limit: Int = 260) -> String {
        elements.prefix(limit).map { element in
            let box = normalized(element.rect)
            let label = element.label.count > 90 ? String(element.label.prefix(90)) + "…" : element.label
            let kind = element.kind == "text" ? "" : " \(element.kind)"
            return "\(element.id)\(kind) [\(box.map { String($0) }.joined(separator: ","))] \"\(label)\""
        }.joined(separator: "\n")
    }

    func normalized(_ rect: CGRect) -> [Int] {
        let f = displayFrame
        func nx(_ x: CGFloat) -> Int { Int(((x - f.minX) / max(f.width, 1) * 1000).rounded()) }
        func ny(_ y: CGFloat) -> Int { Int(((y - f.minY) / max(f.height, 1) * 1000).rounded()) }
        return [nx(rect.minX), ny(rect.minY), nx(rect.maxX), ny(rect.maxY)]
    }

    /// Converts a 0–1000 box on the display to CoreGraphics global points.
    func globalRect(normalizedBox box: [Double]) -> CGRect? {
        guard box.count == 4, box.allSatisfy(\.isFinite) else { return nil }
        let clamped = box.map { min(max($0, 0), 1000) / 1000 }
        let f = displayFrame
        let rect = CGRect(
            x: f.minX + min(clamped[0], clamped[2]) * f.width,
            y: f.minY + min(clamped[1], clamped[3]) * f.height,
            width: abs(clamped[2] - clamped[0]) * f.width,
            height: abs(clamped[3] - clamped[1]) * f.height
        )
        return rect.width >= 2 && rect.height >= 2 ? rect : nil
    }
}

/// Reads the screen on-device: Vision text recognition with word boxes, and the
/// frontmost app's accessibility tree when ScreenTutor is trusted for it.
enum ScreenReader {
    /// Recognizes text lines in `image`, which shows `displayFrame`.
    nonisolated static func recognizeText(in image: CGImage, displayFrame: CGRect) throws -> [ScreenElement] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US", "de-DE"]
        try VNImageRequestHandler(cgImage: image).perform([request])
        let observations = request.results ?? []

        func global(_ box: CGRect) -> CGRect {
            // Vision boxes are normalized with a bottom-left origin.
            CGRect(
                x: displayFrame.minX + box.minX * displayFrame.width,
                y: displayFrame.minY + (1 - box.maxY) * displayFrame.height,
                width: box.width * displayFrame.width,
                height: box.height * displayFrame.height
            )
        }

        var elements: [ScreenElement] = []
        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let text = candidate.string
            guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            var tokens: [ScreenTextToken] = []
            var offset = 0
            for word in text.split(separator: " ", omittingEmptySubsequences: false) {
                let length = word.count
                defer { offset += length + 1 }
                guard length > 0 else { continue }
                let lower = text.index(text.startIndex, offsetBy: offset)
                let upper = text.index(lower, offsetBy: length)
                if let box = try? candidate.boundingBox(for: lower..<upper)?.boundingBox {
                    tokens.append(ScreenTextToken(start: offset, end: offset + length, rect: global(box)))
                }
            }
            elements.append(
                ScreenElement(id: "", kind: "text", label: text, rect: global(observation.boundingBox), tokens: tokens)
            )
        }
        return elements
    }

    /// Interactive controls of the frontmost app's focused window (needs Accessibility).
    @MainActor
    static func accessibilityElements(within displayFrame: CGRect, limit: Int = 120) -> (app: String?, elements: [ScreenElement]) {
        guard
            let app = NSWorkspace.shared.frontmostApplication,
            app.processIdentifier != ProcessInfo.processInfo.processIdentifier
        else { return (nil, []) }
        guard AXIsProcessTrusted() else { return (app.localizedName, []) }

        let root = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 0.4)
        guard let window: AXUIElement = attribute(root, kAXFocusedWindowAttribute) else { return (app.localizedName, []) }

        let roles: [String: String] = [
            "AXButton": "button", "AXLink": "link", "AXTextField": "field", "AXTextArea": "textarea",
            "AXCheckBox": "checkbox", "AXRadioButton": "radio", "AXPopUpButton": "popup", "AXTab": "tab",
            "AXMenuItem": "menuitem", "AXMenuButton": "menu", "AXSlider": "slider", "AXImage": "image",
            "AXHeading": "heading", "AXComboBox": "combobox", "AXSearchField": "search"
        ]
        var queue: [(AXUIElement, Int)] = [(window, 0)]
        var visited = 0
        var found: [ScreenElement] = []
        while !queue.isEmpty, visited < 800, found.count < limit {
            let (element, depth) = queue.removeFirst()
            visited += 1
            if let role: String = attribute(element, kAXRoleAttribute),
               let short = roles[role],
               let rect = frame(of: element),
               rect.width >= 4, rect.height >= 4,
               displayFrame.intersects(rect) {
                let label = [kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute, kAXHelpAttribute]
                    .lazy
                    .compactMap { (key: String) -> String? in attribute(element, key) }
                    .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                if let label {
                    found.append(ScreenElement(id: "", kind: short, label: label, rect: rect, tokens: []))
                }
            }
            if depth < 30, let children: [AXUIElement] = attribute(element, kAXChildrenAttribute) {
                queue.append(contentsOf: children.map { ($0, depth + 1) })
            }
        }
        return (app.localizedName, found)
    }

    /// Orders elements top-to-bottom, left-to-right and assigns ids.
    nonisolated static func numbered(text: [ScreenElement], controls: [ScreenElement]) -> [ScreenElement] {
        func ordered(_ items: [ScreenElement]) -> [ScreenElement] {
            items.sorted { a, b in
                abs(a.rect.minY - b.rect.minY) > 6 ? a.rect.minY < b.rect.minY : a.rect.minX < b.rect.minX
            }
        }
        let t = ordered(text).enumerated().map { index, e in
            ScreenElement(id: "t\(index + 1)", kind: e.kind, label: e.label, rect: e.rect, tokens: e.tokens)
        }
        let u = ordered(controls).enumerated().map { index, e in
            ScreenElement(id: "u\(index + 1)", kind: e.kind, label: e.label, rect: e.rect, tokens: e.tokens)
        }
        return t + u
    }

    private static func attribute<T>(_ element: AXUIElement, _ name: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? T
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionRef) == .success,
            AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success,
            let positionRef, let sizeRef,
            CFGetTypeID(positionRef) == AXValueGetTypeID(),
            CFGetTypeID(sizeRef) == AXValueGetTypeID()
        else { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        // swiftlint:disable force_cast
        AXValueGetValue(positionRef as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
        // swiftlint:enable force_cast
        return CGRect(origin: position, size: size)
    }
}
