import XCTest
@testable import ScreenTutor

final class DeskChangeGateTests: XCTestCase {
    private func fingerprint(changedCells: Int, value: UInt8 = 200) -> DeskFrameFingerprint {
        var pixels = [UInt8](
            repeating: 120,
            count: DeskFrameFingerprint.width * DeskFrameFingerprint.height
        )
        for index in 0..<changedCells { pixels[index] = value }
        return DeskFrameFingerprint(pixels: pixels)
    }

    func testChangedFractionCountsOnlyCellsAboveThreshold() {
        let base = fingerprint(changedCells: 0)
        let noisy = fingerprint(changedCells: 300, value: 130)
        let written = fingerprint(changedCells: 300, value: 40)
        XCTAssertEqual(base.changedFraction(comparedTo: noisy), 0)
        XCTAssertEqual(base.changedFraction(comparedTo: written), 300.0 / 3072.0, accuracy: 1e-9)
    }

    func testFirstFrameIsAnalyzedThenQuietPageWaits() {
        var gate = DeskChangeGate()
        let start = Date()
        let page = fingerprint(changedCells: 0)
        XCTAssertEqual(gate.evaluate(page, at: start, hasActiveTask: false), .analyze(.firstLook))
        gate.recordAnalysis(of: page, at: start)
        XCTAssertEqual(gate.evaluate(page, at: start + 10, hasActiveTask: false), .wait)
    }

    func testNewWritingIsAnalyzedOnlyAfterTheHandSettles() {
        var gate = DeskChangeGate()
        let start = Date()
        let page = fingerprint(changedCells: 0)
        _ = gate.evaluate(page, at: start, hasActiveTask: true)
        gate.recordAnalysis(of: page, at: start)

        // A hand moves across the page: large motion between ticks.
        let hand = fingerprint(changedCells: 900, value: 10)
        XCTAssertEqual(gate.evaluate(hand, at: start + 5, hasActiveTask: true), .wait)
        // The hand leaves; a new line of writing remains (about 1% of cells).
        let written = fingerprint(changedCells: 40, value: 20)
        XCTAssertEqual(gate.evaluate(written, at: start + 5.5, hasActiveTask: true), .wait)
        XCTAssertEqual(gate.evaluate(written, at: start + 6, hasActiveTask: true), .wait)
        XCTAssertEqual(
            gate.evaluate(written, at: start + 7.1, hasActiveTask: true),
            .analyze(.pageChanged)
        )
    }

    func testStallIsReportedOnceForAnActiveTask() {
        var gate = DeskChangeGate(stallSeconds: 60)
        let start = Date()
        let page = fingerprint(changedCells: 0)
        _ = gate.evaluate(page, at: start, hasActiveTask: true)
        gate.recordAnalysis(of: page, at: start)
        XCTAssertEqual(gate.evaluate(page, at: start + 30, hasActiveTask: true), .wait)
        XCTAssertEqual(gate.evaluate(page, at: start + 61, hasActiveTask: true), .analyze(.noProgress))
        gate.recordAnalysis(of: page, at: start + 61)
        XCTAssertEqual(gate.evaluate(page, at: start + 200, hasActiveTask: true), .wait)
    }

    func testNoStallWithoutActiveTask() {
        var gate = DeskChangeGate(stallSeconds: 60)
        let start = Date()
        let page = fingerprint(changedCells: 0)
        _ = gate.evaluate(page, at: start, hasActiveTask: false)
        gate.recordAnalysis(of: page, at: start)
        XCTAssertEqual(gate.evaluate(page, at: start + 300, hasActiveTask: false), .wait)
    }
}

final class DeskObservationPayloadTests: XCTestCase {
    func testParsesFencedJSONWithIssueAndInterjection() throws {
        let text = """
            ```json
            {"desk_visible": true, "summary": "Solving a quadratic.",
             "work_transcription": "x^2 - 5x + 6 = 0 \\\\Rightarrow (x-2)(x+3)",
             "progress": "working",
             "issue": {"kind": "error", "location": "line 2", "description": "Sign of 3 is wrong."},
             "interjection": {"kind": "error", "reason": "Wrong factor will propagate.",
                              "suggested_move": "Ask them to expand (x-2)(x+3)."}}
            ```
            """
        let payload = try DeskObservationPayload.parse(text)
        XCTAssertEqual(payload.progress, .working)
        XCTAssertEqual(payload.issue?.location, "line 2")
        XCTAssertEqual(payload.interjection?.kind, .error)
        XCTAssertEqual(payload.interjection?.suggestedMove, "Ask them to expand (x-2)(x+3).")
    }

    func testToleratesMissingAndUnknownFields() throws {
        let payload = try DeskObservationPayload.parse(
            #"{"summary": "Blank page.", "progress": "daydreaming", "issue": null}"#
        )
        XCTAssertTrue(payload.deskVisible)
        XCTAssertEqual(payload.progress, .unclear)
        XCTAssertNil(payload.issue)
        XCTAssertNil(payload.interjection)
    }

    func testRejectsNonJSON() {
        XCTAssertThrowsError(try DeskObservationPayload.parse("I cannot see the desk."))
    }

    func testProactivityGatesInterjectionKinds() {
        XCTAssertFalse(DeskProactivity.off.allows(.error))
        XCTAssertTrue(DeskProactivity.gentle.allows(.error))
        XCTAssertFalse(DeskProactivity.gentle.allows(.checkIn))
        XCTAssertTrue(DeskProactivity.active.allows(.checkIn))
    }
}

final class DeskConversationEventTests: XCTestCase {
    func testDeskItemCarriesShortIDTextAndImage() throws {
        let itemID = DeskContextItemEvent.makeItemID()
        XCTAssertLessThanOrEqual(itemID.count, 32)
        let data = try JSONEncoder().encode(
            DeskContextItemEvent(itemID: itemID, text: "<desk_observer> note", jpegData: Data([1, 2, 3]))
        )
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(root["type"] as? String, "conversation.item.create")
        XCTAssertNil(root["previous_item_id"])
        let item = try XCTUnwrap(root["item"] as? [String: Any])
        XCTAssertEqual(item["id"] as? String, itemID)
        XCTAssertEqual(item["role"] as? String, "user")
        let content = try XCTUnwrap(item["content"] as? [[String: Any]])
        XCTAssertEqual(content.map { $0["type"] as? String }, ["input_text", "input_image"])
        XCTAssertEqual(content[1]["image_url"] as? String, "data:image/jpeg;base64,AQID")
    }
}

final class DocumentConversionTests: XCTestCase {
    func testMarkdownToHTMLCoversStudyNoteBasics() {
        let html = MarkdownHTML.body("""
            ## Eigenvalues
            Solve **det**(A - λI) = 0 for *each* λ.

            - first <item>
            - second `code`

            1. Expand
            2. Factor
            """)
        XCTAssertTrue(html.contains("<h3>Eigenvalues</h3>"))
        XCTAssertTrue(html.contains("<b>det</b>"))
        XCTAssertTrue(html.contains("<i>each</i>"))
        XCTAssertTrue(html.contains("<ul>\n<li>first &lt;item&gt;</li>"))
        XCTAssertTrue(html.contains("<code>code</code>"))
        XCTAssertTrue(html.contains("<ol>\n<li>Expand</li>\n<li>Factor</li>\n</ol>"))
    }

    func testSafeFileNameStripsPathCharacters() {
        XCTAssertEqual(DesktopActions.safeFileName("Linear Algebra: Week 3/4"), "Linear Algebra  Week 3 4")
        XCTAssertEqual(DesktopActions.safeFileName("   "), "ScreenTutor note")
    }

    @MainActor
    func testOpenURLRejectsNonWebSchemes() {
        let actions = DesktopActions()
        XCTAssertThrowsError(try actions.openURL("file:///etc/passwd"))
        XCTAssertThrowsError(try actions.openURL("javascript:alert(1)"))
    }
}
