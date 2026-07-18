import XCTest
@testable import ScreenTutor

final class SessionIdentityTests: XCTestCase {
    func testOldConnectionCannotMatchOrClearReplacement() throws {
        let first = RealtimeConnectionID()
        let second = RealtimeConnectionID()
        var state = RealtimeConnectionState()

        try state.activate(first)
        XCTAssertTrue(state.clear(ifCurrent: first))
        try state.activate(second)

        XCTAssertFalse(state.matches(first))
        XCTAssertFalse(state.clear(ifCurrent: first))
        XCTAssertTrue(state.matches(second))
    }

    func testAdvancingTurnInvalidatesInFlightToolWork() {
        var turns = ConversationTurnTracker()
        let captureTurn = turns.advance()

        XCTAssertTrue(turns.isCurrent(captureTurn))
        _ = turns.advance()
        XCTAssertFalse(turns.isCurrent(captureTurn))
    }
}
