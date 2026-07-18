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
}
