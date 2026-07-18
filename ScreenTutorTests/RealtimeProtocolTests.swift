import Foundation
import XCTest
@testable import ScreenTutor

final class RealtimeProtocolTests: XCTestCase {
    func testSessionUsesNativeAudioWithoutTranscription() throws {
        let data = try JSONEncoder().encode(RealtimeSessionUpdateEvent.screenTutor)
        let root = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let session = try XCTUnwrap(root["session"] as? [String: Any])
        let audio = try XCTUnwrap(session["audio"] as? [String: Any])
        let input = try XCTUnwrap(audio["input"] as? [String: Any])
        let turnDetection = try XCTUnwrap(input["turn_detection"] as? [String: Any])

        XCTAssertEqual(root["type"] as? String, "session.update")
        XCTAssertEqual(session["model"] as? String, "gpt-realtime-2.1")
        XCTAssertEqual(session["output_modalities"] as? [String], ["audio"])
        XCTAssertNil(input["transcription"])
        XCTAssertEqual(turnDetection["type"] as? String, "semantic_vad")
        XCTAssertEqual(turnDetection["create_response"] as? Bool, false)
        XCTAssertEqual(turnDetection["interrupt_response"] as? Bool, true)
        let tools = try XCTUnwrap(session["tools"] as? [[String: Any]])
        XCTAssertEqual(tools.first?["name"] as? String, "highlight_screen_region")
    }

    func testScreenshotIsAHighDetailJPEGConversationItem() throws {
        let event = ConversationImageEvent(jpegData: Data([0x01, 0x02, 0x03]))
        let data = try JSONEncoder().encode(event)
        let root = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let item = try XCTUnwrap(root["item"] as? [String: Any])
        let content = try XCTUnwrap(item["content"] as? [[String: Any]])
        let image = try XCTUnwrap(content.last)

        XCTAssertEqual(root["type"] as? String, "conversation.item.create")
        XCTAssertEqual(item["role"] as? String, "user")
        XCTAssertEqual(image["type"] as? String, "input_image")
        XCTAssertEqual(image["detail"] as? String, "high")
        XCTAssertEqual(image["image_url"] as? String, "data:image/jpeg;base64,AQID")
    }

    func testDecodesCurrentOutputAudioDeltaEvent() throws {
        let payload = Data(
            """
            {
              "type": "response.output_audio.delta",
              "response_id": "resp_1",
              "item_id": "item_1",
              "delta": "AQI="
            }
            """.utf8
        )
        let event = try JSONDecoder().decode(RealtimeServerEvent.self, from: payload)

        XCTAssertEqual(event.type, "response.output_audio.delta")
        XCTAssertEqual(event.responseID, "resp_1")
        XCTAssertEqual(event.itemID, "item_1")
        XCTAssertEqual(event.delta, "AQI=")
    }
}
