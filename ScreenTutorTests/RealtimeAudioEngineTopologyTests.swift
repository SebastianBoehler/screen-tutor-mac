import XCTest
@testable import ScreenTutor

final class RealtimeAudioEngineTopologyTests: XCTestCase {
    func testMicrophoneAndPlaybackUseIndependentAudioEngines() {
        let engines = RealtimeAudioEngines()

        XCTAssertFalse(engines.input === engines.output)
    }
}
