import Foundation
import XCTest
@testable import ScreenTutor

final class ConversationHistoryIdentityTests: XCTestCase {
    func testRepeatedInvocationsReuseIdentityUntilExplicitlyCleared() {
        var identity = ConversationHistoryIdentity()
        let firstID = UUID()
        let secondID = UUID()

        XCTAssertEqual(identity.ensureCurrent { firstID }, firstID)
        XCTAssertEqual(identity.ensureCurrent { secondID }, firstID)

        identity.clear()

        XCTAssertEqual(identity.ensureCurrent { secondID }, secondID)
    }

    func testResumeSelectsExistingConversationIdentity() {
        var identity = ConversationHistoryIdentity()
        let existingID = UUID()

        identity.resume(existingID)

        XCTAssertEqual(identity.current, existingID)
        XCTAssertEqual(identity.ensureCurrent(), existingID)
    }

    func testTurnTrackerContinuesAfterArchivedTurn() {
        var tracker = ConversationTurnTracker(initialTurn: 8)

        XCTAssertEqual(tracker.advance(), 9)
        XCTAssertTrue(tracker.isCurrent(9))
    }
}
