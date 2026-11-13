import AppKit
import CoreGraphics
import XCTest
@testable import ScreenTutor

final class OverlayLayoutTests: XCTestCase {
    private let bounds = CGRect(x: 0, y: 0, width: 1000, height: 800)

    func testLabelsAvoidTargetsAndEachOther() {
        let line = CGRect(x: 100, y: 300, width: 700, height: 40)
        let marks = [
            OverlayMark(kind: .circle, rect: CGRect(x: 400, y: 300, width: 50, height: 40), label: "step size"),
            OverlayMark(kind: .box, rect: line, label: "update rule"),
            OverlayMark(kind: .note, rect: CGRect(x: 420, y: 305, width: 10, height: 30), label: "what if it doubles?")
        ]
        let labels = OverlayLayout.placeLabels(for: marks, in: bounds)
        XCTAssertEqual(labels.count, 3)
        let rects = Array(labels.values)
        for (index, a) in rects.enumerated() {
            XCTAssertTrue(bounds.contains(a))
            XCTAssertFalse(a.intersects(line), "label \(a) covers the text line")
            for b in rects[(index + 1)...] { XCTAssertFalse(a.intersects(b), "labels overlap") }
        }
        // The first label goes above its target.
        XCTAssertLessThan(labels[marks[0].id]!.maxY, 300)
    }

    func testLabelSizeWrapsLongText() {
        XCTAssertEqual(OverlayLayout.labelSize(for: "eta").height, 35)
        let long = OverlayLayout.labelSize(for: String(repeating: "x", count: 80))
        XCTAssertEqual(long.width, OverlayLayout.maximumLabelWidth)
        XCTAssertGreaterThan(long.height, 35)
    }

    func testArrowRunsFromLabelToTargetEdge() {
        let target = CGRect(x: 500, y: 400, width: 100, height: 40)
        let label = CGRect(x: 300, y: 250, width: 120, height: 34)
        let arrow = OverlayLayout.arrow(from: label, to: target, in: bounds)
        XCTAssertEqual(arrow.head, CGPoint(x: 494, y: 394))
        XCTAssertTrue(label.insetBy(dx: -5, dy: -5).contains(arrow.tail))
    }
}

import SwiftUI

@MainActor
final class OverlaySnapshotTests: XCTestCase {
    /// Writes a PNG of every mark kind over the synthetic slide to the test
    /// host's temporary folder when TEST_RUNNER_OVERLAY_SNAPSHOT=1.
    func testRendersAllMarkKinds() throws {
        guard ProcessInfo.processInfo.environment["OVERLAY_SNAPSHOT"] == "1" else {
            throw XCTSkip("Set TEST_RUNNER_OVERLAY_SNAPSHOT=1 to render a snapshot.")
        }
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("overlay-snapshot.png").path
        let bounds = CGRect(origin: .zero, size: SyntheticSlide.size)
        let marks = [
            OverlayMark(kind: .spotlight, rect: CGRect(x: 150, y: 250, width: 820, height: 60)),
            OverlayMark(kind: .circle, rect: CGRect(x: 545, y: 262, width: 60, height: 44), label: "step size"),
            OverlayMark(kind: .box, rect: CGRect(x: 160, y: 380, width: 300, height: 36), label: "learning rate", color: .blue),
            OverlayMark(kind: .underline, rect: CGRect(x: 330, y: 520, width: 300, height: 34), color: .red),
            OverlayMark(kind: .arrow, rect: CGRect(x: 700, y: 262, width: 120, height: 44), label: "the gradient"),
            OverlayMark(kind: .note, rect: CGRect(x: 160, y: 600, width: 10, height: 30), label: "What happens if η doubles?", color: .purple)
        ]
        let view = ZStack(alignment: .topLeading) {
            Image(decorative: SyntheticSlide.image(), scale: 1)
            OverlayCanvasView(marks: marks, bounds: bounds, animated: false)
        }
        .frame(width: bounds.width, height: bounds.height)
        let renderer = ImageRenderer(content: view)
        let image = try XCTUnwrap(renderer.cgImage)
        let rep = NSBitmapImageRep(cgImage: image)
        let png = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
        try png.write(to: URL(fileURLWithPath: path))
        // The test host is sandboxed, so the image is also printed for tooling outside it.
        print("OVERLAY_SNAPSHOT_BASE64 \(png.base64EncodedString())")
    }
}

final class AnnotationPlanTests: XCTestCase {
    private func reading() -> ScreenReading {
        let line = ScreenElement(
            id: "t1",
            kind: "text",
            label: "theta = theta - eta * grad L",
            rect: CGRect(x: 100, y: 200, width: 600, height: 40),
            tokens: [
                ScreenTextToken(start: 0, end: 5, rect: CGRect(x: 100, y: 200, width: 100, height: 40)),
                ScreenTextToken(start: 16, end: 19, rect: CGRect(x: 420, y: 200, width: 60, height: 40)),
                ScreenTextToken(start: 22, end: 26, rect: CGRect(x: 520, y: 200, width: 80, height: 40))
            ]
        )
        let button = ScreenElement(id: "u1", kind: "button", label: "Next", rect: CGRect(x: 900, y: 700, width: 80, height: 30), tokens: [])
        return ScreenReading(
            displayFrame: CGRect(x: 0, y: 0, width: 1000, height: 1000),
            elements: [line, button],
            modelJPEG: Data(),
            frontApplication: "Preview"
        )
    }

    func testSubstringTargetsResolveToWordBoxes() {
        let element = reading().elements[0]
        XCTAssertEqual(element.rect(of: "eta"), CGRect(x: 420, y: 200, width: 60, height: 40))
        XCTAssertEqual(element.rect(of: "eta * grad"), CGRect(x: 420, y: 200, width: 180, height: 40))
        XCTAssertNil(element.rect(of: "lambda"))
    }

    func testResolvesTargetsBoxesAndReportsMisses() throws {
        let json = """
            Here: {"marks":[
              {"kind":"circle","target":"t1","text":"eta","label":"learning rate","color":"yellow"},
              {"kind":"arrow","target":"u1","label":"next slide"},
              {"kind":"box","box":[100,500,300,600],"color":"blue"},
              {"kind":"spotlight","target":"t1"},
              {"kind":"spotlight","target":"u1"},
              {"kind":"note","target":"t1"},
              {"kind":"box","target":"t99","label":"ghost"}
            ],"summary":"Marked the step size.","missing":null}
            """
        let result = try AnnotationPlan.resolve(json, reading: reading())
        let marks = result.scene.marks
        XCTAssertEqual(marks.map(\.kind), [.circle, .arrow, .box, .spotlight])
        XCTAssertEqual(marks[0].rect, CGRect(x: 420, y: 200, width: 60, height: 40))
        XCTAssertEqual(marks[2].rect, CGRect(x: 100, y: 500, width: 200, height: 100))
        XCTAssertEqual(marks[2].color, .blue)
        XCTAssertEqual(marks.map { ($0.delay * 10).rounded() / 10 }, [0, 0.7, 1.4, 2.1])
        XCTAssertEqual(result.missing, "Could not place: ghost.")
        XCTAssertEqual(result.summary, "Marked the step size.")
    }

    func testListingUsesNormalizedBoxes() {
        let listing = reading().elementListing()
        XCTAssertTrue(listing.contains(#"t1 [100,200,700,240] "theta = theta - eta * grad L""#))
        XCTAssertTrue(listing.contains(#"u1 button [900,700,980,730] "Next""#))
    }
}

final class YouTubeCatalogTests: XCTestCase {
    func testExtractsEmbeddedJSONWithBracesInStrings() throws {
        let html = #"<script>var ytInitialData = {"a":{"b":"x } { y"},"videoRenderer":{"videoId":"IHZwWFHWa-w","title":{"runs":[{"text":"Gradient descent"}]},"ownerText":{"runs":[{"text":"3Blue1Brown"}]},"lengthText":{"simpleText":"20:33"}}};</script>"#
        let data = try XCTUnwrap(YouTubeCatalog.embeddedJSON(named: "ytInitialData", in: html))
        XCTAssertEqual(
            YouTubeCatalog.searchResults(fromInitialData: data),
            [VideoSearchResult(id: "IHZwWFHWa-w", title: "Gradient descent", channel: "3Blue1Brown", length: "20:33")]
        )
    }

    func testParsesChaptersOnlyWhenTheyStartAtZeroAndIncrease() {
        let description = """
            Intro text 12:00 mentioned inline.
            0:00 Introduction
            1:49 - Using training data
            (1:02:03) Wrap-up
            """
        XCTAssertEqual(
            YouTubeCatalog.chapters(fromDescription: description),
            [VideoChapter(seconds: 0, title: "Introduction"), VideoChapter(seconds: 109, title: "Using training data"), VideoChapter(seconds: 3723, title: "Wrap-up")]
        )
        XCTAssertEqual(YouTubeCatalog.chapters(fromDescription: "5:00 Late start\n6:00 More"), [])
        XCTAssertEqual(YouTubeCatalog.timestamp(3723), "1:02:03")
        XCTAssertEqual(YouTubeCatalog.timestamp(65.4), "1:05")
        XCTAssertTrue(YouTubeCatalog.isValidVideoID("IHZwWFHWa-w"))
        XCTAssertFalse(YouTubeCatalog.isValidVideoID("javascript:1"))
    }
}

/// Renders a synthetic lecture slide, so no test ever reads the real screen.
enum SyntheticSlide {
    static let size = CGSize(width: 1440, height: 900)

    static func image() -> CGImage {
        let context = CGContext(
            data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )!
        let graphics = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        NSColor(white: 0.96, alpha: 1).setFill()
        NSRect(origin: .zero, size: size).fill()
        func draw(_ text: String, x: CGFloat, top: CGFloat, size: CGFloat) {
            let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size), .foregroundColor: NSColor.black]
            NSAttributedString(string: text, attributes: attributes).draw(at: NSPoint(x: x, y: Self.size.height - top - size))
        }
        draw("Gradient descent update rule", x: 120, top: 140, size: 44)
        draw("theta_next = theta - eta * grad L(theta)", x: 160, top: 260, size: 44)
        draw("eta: learning rate      grad L: gradient of the loss", x: 160, top: 380, size: 30)
        draw("If eta is too large, the iterates oscillate or diverge.", x: 160, top: 520, size: 30)
        NSGraphicsContext.restoreGraphicsState()
        return context.makeImage()!
    }
}

final class ScreenReaderTests: XCTestCase {
    func testRecognizesTextWithWordBoxesInGlobalCoordinates() throws {
        let frame = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let elements = ScreenReader.numbered(text: try ScreenReader.recognizeText(in: SyntheticSlide.image(), displayFrame: frame), controls: [])
        let rule = try XCTUnwrap(elements.first { $0.label.contains("theta_next") || $0.label.contains("grad L(") })
        XCTAssertEqual(rule.id, "t2")
        XCTAssertEqual(rule.rect.minY, 260, accuracy: 20)
        let eta = try XCTUnwrap(rule.rect(of: "eta"))
        XCTAssertTrue(rule.rect.insetBy(dx: -2, dy: -2).contains(eta))
        XCTAssertLessThan(eta.width, rule.rect.width / 4)
    }

    /// Live: the default annotation model on OpenRouter must place a circle on
    /// "eta" in the synthetic slide. Run with TEST_RUNNER_OPENROUTER_API_KEY set.
    @MainActor
    func testLiveAnnotationLandsOnTheTerm() async throws {
        guard let key = ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"], !key.isEmpty else {
            throw XCTSkip("Set TEST_RUNNER_OPENROUTER_API_KEY to run the live annotation test.")
        }
        let frame = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let image = SyntheticSlide.image()
        let reading = ScreenReading(
            displayFrame: frame,
            elements: ScreenReader.numbered(text: try ScreenReader.recognizeText(in: image, displayFrame: frame), controls: []),
            modelJPEG: try XCTUnwrap(ScreenImageEncoder().jpegData(from: image, maximumDimension: 1_024)),
            frontApplication: "Preview"
        )
        let model = ProcessInfo.processInfo.environment["OVERLAY_MODEL"] ?? AppSettingsModel.defaultOverlayModel
        let started = Date()
        let completion = try await OpenRouterClient().complete(
            apiKey: key,
            model: model,
            system: AnnotationPrompt.system,
            userText: AnnotationPrompt.userText(
                instruction: "Circle the learning rate symbol in the update rule (the formula line) and label it 'step size'.",
                reading: reading
            ),
            jpegData: reading.modelJPEG,
            maxTokens: 700,
            reasoning: .off
        )
        let result = try AnnotationPlan.resolve(completion.text, reading: reading)
        print("annotation \(model): \(String(format: "%.2f", Date().timeIntervalSince(started))) s → \(completion.text)")
        let circle = try XCTUnwrap(result.scene.marks.first)
        let rule = try XCTUnwrap(reading.elements.first { $0.label.contains("theta_next") || $0.label.contains("grad L(") })
        let eta = try XCTUnwrap(rule.rect(of: "eta"))
        XCTAssertTrue(circle.rect.insetBy(dx: -10, dy: -10).contains(CGPoint(x: eta.midX, y: eta.midY)), "marked \(circle.rect), eta at \(eta)")
    }
}

/// Live: plays a real YouTube video in the lesson player. Run with
/// TEST_RUNNER_LIVE_PLAYER=1.
@MainActor
final class LessonPlayerLiveTests: XCTestCase {
    func testPlaysPausesSeeksAndLoops() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["LIVE_PLAYER"] == "1", "Set TEST_RUNNER_LIVE_PLAYER=1.")
        let player = LessonPlayerController()
        try await player.play(videoID: "IHZwWFHWa-w", title: "Gradient descent", start: 30)
        try await waitFor("playing past 31 s") { player.state.isPlaying && player.state.time > 31 }
        XCTAssertEqual(player.state.duration, 1233, accuracy: 3)
        XCTAssertTrue(player.state.title.localizedCaseInsensitiveContains("gradient descent"), "title: \(player.state.title)")

        try await player.pause()
        try await waitFor("paused") { player.state.playerState == 2 }
        try await player.seek(to: 415)
        try await waitFor("at 6:55") { abs(player.state.time - 415) < 2 }

        try await player.loop(from: 600, to: 603)
        try await waitFor("looped back") { player.state.loop != nil && player.state.time >= 600 && player.state.time < 603.5 }
        try await Task.sleep(for: .seconds(4))
        XCTAssertLessThan(player.state.time, 604, "loop should jump back to 600")
        try await player.setRate(1.5)
        XCTAssertEqual(player.state.rate, 1.5)
        player.close()
    }

    private func waitFor(_ label: String, timeout: Double = 15, _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(200))
        }
        XCTFail("timed out waiting for \(label)")
    }
}

/// Live comparison of grounding with and without the grid/tag markup on a
/// figure task (no text to anchor to). Run with TEST_RUNNER_GROUNDING_BENCH=1
/// and TEST_RUNNER_OPENROUTER_API_KEY; prints one line per model and mode.
final class GroundingBenchmarkTests: XCTestCase {
    /// A loss curve whose minimum sits at (1010, 690) in a 1440×900 image.
    static let minimum = CGPoint(x: 1010, y: 690)

    static func plot() -> CGImage {
        let size = CGSize(width: 1440, height: 900)
        let context = CGContext(
            data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )!
        // Top-left origin, matching screen coordinates.
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)
        let graphics = NSGraphicsContext(cgContext: context, flipped: true)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()
        NSAttributedString(string: "Training loss over parameter w", attributes: [.font: NSFont.systemFont(ofSize: 34)])
            .draw(at: NSPoint(x: 420, y: 60))
        let axes = NSBezierPath()
        axes.move(to: NSPoint(x: 200, y: 140)); axes.line(to: NSPoint(x: 200, y: 800)); axes.line(to: NSPoint(x: 1340, y: 800))
        NSColor.black.setStroke(); axes.lineWidth = 3; axes.stroke()
        let curve = NSBezierPath()
        for i in 0...300 {
            let x = 240 + CGFloat(i) * 3.6
            let u = (x - minimum.x) / 380
            let y = minimum.y - 520 * (u * u) / (1 + 0.15 * u * u) + 18 * sin(x / 37) * (abs(u) > 0.6 ? 1 : 0)
            i == 0 ? curve.move(to: NSPoint(x: x, y: y)) : curve.line(to: NSPoint(x: x, y: y))
        }
        NSColor.systemBlue.setStroke(); curve.lineWidth = 4; curve.stroke()
        NSAttributedString(string: "w", attributes: [.font: NSFont.systemFont(ofSize: 28)]).draw(at: NSPoint(x: 1300, y: 815))
        NSAttributedString(string: "L(w)", attributes: [.font: NSFont.systemFont(ofSize: 28)]).draw(at: NSPoint(x: 120, y: 140))
        NSGraphicsContext.restoreGraphicsState()
        return context.makeImage()!
    }

    @MainActor
    func testGridImprovesFigureGrounding() async throws {
        let env = ProcessInfo.processInfo.environment
        guard env["GROUNDING_BENCH"] == "1", let key = env["OPENROUTER_API_KEY"] else {
            throw XCTSkip("Set TEST_RUNNER_GROUNDING_BENCH=1 and TEST_RUNNER_OPENROUTER_API_KEY.")
        }
        let frame = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let image = Self.plot()
        let elements = ScreenReader.numbered(text: try ScreenReader.recognizeText(in: image, displayFrame: frame), controls: [])
        let models = (env["BENCH_MODELS"] ?? "deepseek/deepseek-v4.1-flash,google/gemini-3.1-flash-lite,google/gemma-4-26b-a4b-it")
            .split(separator: ",").map(String.init)
        let modes: [(String, ScreenMarkup.Options)] = [
            ("plain", .init(grid: false, tags: false)),
            ("grid", .init(grid: true, tags: false)),
            ("grid+tags", .init(grid: true, tags: true))
        ]
        let runs = Int(env["BENCH_RUNS"] ?? "3") ?? 3
        for model in models {
            for (name, options) in modes {
                let marked = try XCTUnwrap(ScreenMarkup.render(image, elements: elements, displayFrame: frame, maximumDimension: 1_024, options: options))
                let reading = ScreenReading(
                    displayFrame: frame, elements: elements,
                    modelJPEG: try XCTUnwrap(ScreenImageEncoder().jpegData(from: marked, maximumDimension: 1_024)),
                    frontApplication: "Preview"
                )
                if name == "grid+tags", model == models.first {
                    print("BENCH_IMAGE \(reading.modelJPEG.base64EncodedString())")
                }
                var errors: [Double] = []
                var seconds: [Double] = []
                for _ in 0..<runs {
                    let started = Date()
                    guard let completion = try? await OpenRouterClient().complete(
                        apiKey: key, model: model, system: AnnotationPrompt.system,
                        userText: AnnotationPrompt.userText(
                            instruction: "Circle the lowest point of the blue loss curve (its minimum). Tight circle, no label.",
                            reading: reading
                        ),
                        jpegData: reading.modelJPEG, maxTokens: 500, reasoning: .off
                    ), let mark = try? AnnotationPlan.resolve(completion.text, reading: reading).scene.marks.first else {
                        errors.append(.infinity)
                        continue
                    }
                    seconds.append(Date().timeIntervalSince(started))
                    errors.append(hypot(mark.rect.midX - Self.minimum.x, mark.rect.midY - Self.minimum.y))
                }
                let finite = errors.filter(\.isFinite).sorted()
                let median = finite.isEmpty ? .infinity : finite[finite.count / 2]
                print(String(
                    format: "BENCH %@ %@: median error %.0f px, hits(<40px) %d/%d, median %.2f s, errors %@",
                    model, name, median, errors.filter { $0 < 40 }.count, runs,
                    seconds.sorted().dropFirst(seconds.count / 2).first ?? 0,
                    errors.map { $0.isFinite ? String(Int($0)) : "x" }.joined(separator: ",")
                ))
            }
        }
    }
}

@MainActor
final class OverlayControllerTests: XCTestCase {
    func testShowsOnTheDisplayOfEachMarkThenClears() throws {
        let screen = try XCTUnwrap(NSScreen.screens.first)
        let bounds = CGDisplayBounds(try XCTUnwrap(screen.displayID))
        let controller = OverlayController()
        controller.show(OverlayScene(
            marks: [OverlayMark(kind: .box, rect: CGRect(x: bounds.minX + 100, y: bounds.minY + 100, width: 200, height: 40), label: "test")],
            duration: 30
        ))
        let visible = NSApp.windows.filter { $0 is NSPanel && $0.isVisible && $0.ignoresMouseEvents && $0.frame == screen.frame }
        XCTAssertEqual(visible.count, 1)
        controller.clear()
        XCTAssertFalse(visible[0].isVisible)
    }
}
