import XCTest
@testable import ScreenTutor

@MainActor
final class ListeningIdleTimerTests: XCTestCase {
    func testDefaultsToTwentySeconds() {
        let timer = ListeningIdleTimer()

        XCTAssertEqual(timer.timeout, .seconds(20))
    }

    func testFiresArmedActionDeterministically() {
        var scheduledTimeout: Duration?
        var scheduledAction: (@MainActor () -> Void)?
        var fireCount = 0
        let timer = ListeningIdleTimer { timeout, action in
            scheduledTimeout = timeout
            scheduledAction = action
            return {}
        }

        timer.arm { fireCount += 1 }

        XCTAssertEqual(scheduledTimeout, .seconds(20))
        XCTAssertTrue(timer.isArmed)
        scheduledAction?()
        XCTAssertEqual(fireCount, 1)
        XCTAssertFalse(timer.isArmed)
    }

    func testCancelPreventsSchedulerThatIgnoresCancellationFromFiring() {
        var scheduledAction: (@MainActor () -> Void)?
        var cancellationCount = 0
        var fireCount = 0
        let timer = ListeningIdleTimer { _, action in
            scheduledAction = action
            return { cancellationCount += 1 }
        }

        timer.arm { fireCount += 1 }
        timer.cancel()
        scheduledAction?()

        XCTAssertEqual(cancellationCount, 1)
        XCTAssertEqual(fireCount, 0)
        XCTAssertFalse(timer.isArmed)
    }

    func testRearmingCancelsAndInvalidatesPreviousAction() {
        var scheduledActions: [@MainActor () -> Void] = []
        var cancellationCount = 0
        var firedValue = 0
        let timer = ListeningIdleTimer { _, action in
            scheduledActions.append(action)
            return { cancellationCount += 1 }
        }

        timer.arm { firedValue = 1 }
        timer.arm { firedValue = 2 }
        scheduledActions[0]()
        XCTAssertEqual(firedValue, 0)
        scheduledActions[1]()

        XCTAssertEqual(cancellationCount, 1)
        XCTAssertEqual(firedValue, 2)
        XCTAssertFalse(timer.isArmed)
    }

    func testSynchronousSchedulerDoesNotLeaveTimerArmed() {
        var cancellationCount = 0
        var fireCount = 0
        let timer = ListeningIdleTimer { _, action in
            action()
            return { cancellationCount += 1 }
        }

        timer.arm { fireCount += 1 }

        XCTAssertEqual(fireCount, 1)
        XCTAssertEqual(cancellationCount, 1)
        XCTAssertFalse(timer.isArmed)
    }
}
