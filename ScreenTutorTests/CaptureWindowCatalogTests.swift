import CoreGraphics
import Foundation
import XCTest
@testable import ScreenTutor

final class CaptureWindowCatalogTests: XCTestCase {
    func testFiltersUnsafeCandidatesAndKeepsFrontToBackOrder() {
        let catalog = CaptureWindowCatalog(
            candidates: [
                candidate(id: 30, processID: 300, app: "Back", title: "Notes", rank: 2),
                candidate(id: 10, processID: 100, app: "Front", title: "Notebook", rank: 0),
                candidate(id: 20, processID: 200, app: "Overlay", title: "HUD", layer: 1),
                candidate(id: 21, processID: 201, app: "Tiny", title: "Popover", width: 120),
                candidate(id: 22, processID: 999, app: "ScreenTutor", title: "Menu")
            ],
            excludingProcessID: 999,
            tokenProvider: tokenProvider(["selection-front", "selection-back"])
        )

        XCTAssertEqual(
            catalog.windows,
            [
                AvailableWindow(
                    id: "selection-front",
                    applicationName: "Front",
                    title: "Notebook"
                ),
                AvailableWindow(
                    id: "selection-back",
                    applicationName: "Back",
                    title: "Notes"
                )
            ]
        )
        XCTAssertEqual(
            catalog.selection(for: "selection-front"),
            CaptureWindowSelection(windowID: 10, processID: 100)
        )
        XCTAssertNil(catalog.selection(for: "missing"))
    }

    func testWindowMetadataDoesNotExposeNativeIdentifiersOrGeometry() throws {
        let window = AvailableWindow(
            id: "opaque-selection",
            applicationName: "JupyterLab",
            title: "Research notebook"
        )
        let data = try JSONEncoder().encode(window)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        XCTAssertEqual(Set(object.keys), ["window_id", "application", "title"])
        XCTAssertEqual(object["window_id"] as? String, "opaque-selection")
        XCTAssertEqual(object["application"] as? String, "JupyterLab")
    }

    func testCaptureArgumentsDecodeOpaqueWindowID() throws {
        let arguments = try JSONDecoder().decode(
            CaptureWindowArguments.self,
            from: Data(#"{"window_id":"opaque-selection"}"#.utf8)
        )

        XCTAssertEqual(arguments.windowID, "opaque-selection")
    }

    func testStaleListingCannotPublishOverNewerCatalog() throws {
        var state = CaptureWindowCatalogState()
        let staleRevision = state.beginListing()
        let currentRevision = state.beginListing()

        XCTAssertTrue(
            state.publish(
                catalog(id: "current", windowID: 20),
                for: currentRevision
            )
        )
        XCTAssertFalse(
            state.publish(
                catalog(id: "stale", windowID: 10),
                for: staleRevision
            )
        )

        let capture = try XCTUnwrap(state.consume(selectionID: "current"))
        XCTAssertEqual(
            capture.selection,
            CaptureWindowSelection(windowID: 20, processID: 200)
        )
    }

    func testConsumingCatalogInvalidatesTokenAndNewListingSupersedesCapture() throws {
        var state = CaptureWindowCatalogState()
        let initialRevision = state.beginListing()
        XCTAssertTrue(
            state.publish(
                catalog(id: "initial", windowID: 10),
                for: initialRevision
            )
        )

        let capture = try XCTUnwrap(state.consume(selectionID: "initial"))
        XCTAssertNil(state.consume(selectionID: "initial"))

        let replacementRevision = state.beginListing()
        XCTAssertTrue(
            state.publish(
                catalog(id: "replacement", windowID: 30),
                for: replacementRevision
            )
        )

        XCTAssertFalse(state.isCurrent(capture.revision))
        XCTAssertNotNil(state.consume(selectionID: "replacement"))
    }

    func testInvalidCaptureAttemptStillConsumesCatalog() {
        var state = CaptureWindowCatalogState()
        let revision = state.beginListing()
        XCTAssertTrue(
            state.publish(
                catalog(id: "valid", windowID: 10),
                for: revision
            )
        )

        XCTAssertNil(state.consume(selectionID: "invalid"))
        XCTAssertNil(state.consume(selectionID: "valid"))
    }

    private func candidate(
        id: CGWindowID,
        processID: pid_t,
        app: String,
        title: String,
        rank: Int = 1,
        layer: Int = 0,
        width: CGFloat = 800,
        height: CGFloat = 600
    ) -> CaptureWindowCandidate {
        CaptureWindowCandidate(
            windowID: id,
            processID: processID,
            applicationName: app,
            title: title,
            frame: CGRect(x: 0, y: 0, width: width, height: height),
            layer: layer,
            frontToBackRank: rank
        )
    }

    private func catalog(id: String, windowID: CGWindowID) -> CaptureWindowCatalog {
        CaptureWindowCatalog(
            candidates: [
                candidate(
                    id: windowID,
                    processID: pid_t(windowID) * 10,
                    app: "Test App",
                    title: "Test Window"
                )
            ],
            excludingProcessID: -1,
            tokenProvider: { id }
        )
    }

    private func tokenProvider(_ tokens: [String]) -> () -> String {
        var iterator = tokens.makeIterator()
        return { iterator.next() ?? "unexpected-token" }
    }
}
