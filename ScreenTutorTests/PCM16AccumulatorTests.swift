import Foundation
import XCTest
@testable import ScreenTutor

final class PCM16AccumulatorTests: XCTestCase {
    func testPreservesSplitSampleAcrossDeltas() throws {
        var accumulator = PCM16Accumulator()

        XCTAssertEqual(accumulator.append(Data([0x01])), Data())
        XCTAssertEqual(
            accumulator.append(Data([0x02, 0x03, 0x04])),
            Data([0x01, 0x02, 0x03, 0x04])
        )
        XCTAssertNoThrow(try accumulator.finish())
    }

    func testRejectsDanglingOutputByte() {
        var accumulator = PCM16Accumulator()
        _ = accumulator.append(Data([0x01]))

        XCTAssertThrowsError(try accumulator.finish()) { error in
            XCTAssertEqual(error.localizedDescription, AudioIOError.malformedOutputPCM.localizedDescription)
        }
    }
}
