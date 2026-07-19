import Foundation
import XCTest
@testable import ScreenTutor

final class RealtimeProtocolTests: XCTestCase {
    func testSessionKeepsNativeAudioAndAddsHistoryTranscription() throws {
        let data = try JSONEncoder().encode(
            RealtimeSessionUpdateEvent.screenTutor(
                language: .automatic,
                tutorInstructions: RealtimeConstants.defaultTutorInstructions,
                reasoningEffort: .low
            )
        )
        let root = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let session = try XCTUnwrap(root["session"] as? [String: Any])
        let audio = try XCTUnwrap(session["audio"] as? [String: Any])
        let input = try XCTUnwrap(audio["input"] as? [String: Any])
        let turnDetection = try XCTUnwrap(input["turn_detection"] as? [String: Any])
        let noiseReduction = try XCTUnwrap(input["noise_reduction"] as? [String: Any])
        let reasoning = try XCTUnwrap(session["reasoning"] as? [String: Any])

        XCTAssertEqual(root["type"] as? String, "session.update")
        XCTAssertEqual(session["model"] as? String, "gpt-realtime-2.1")
        XCTAssertEqual(session["output_modalities"] as? [String], ["audio"])
        let transcription = try XCTUnwrap(input["transcription"] as? [String: Any])
        XCTAssertEqual(transcription["model"] as? String, "gpt-4o-mini-transcribe")
        XCTAssertNil(transcription["language"])
        XCTAssertEqual(turnDetection["type"] as? String, "semantic_vad")
        XCTAssertEqual(turnDetection["create_response"] as? Bool, false)
        XCTAssertEqual(turnDetection["interrupt_response"] as? Bool, true)
        XCTAssertEqual(noiseReduction["type"] as? String, "far_field")
        XCTAssertEqual(reasoning["effort"] as? String, "low")
        let tools = try XCTUnwrap(session["tools"] as? [[String: Any]])
        XCTAssertEqual(
            tools.compactMap { $0["name"] as? String },
            ["list_windows", "capture_window", "highlight_screen_region"]
        )
        XCTAssertEqual(session["parallel_tool_calls"] as? Bool, false)

        let listTool = try XCTUnwrap(
            tools.first { $0["name"] as? String == "list_windows" }
        )
        let listParameters = try XCTUnwrap(listTool["parameters"] as? [String: Any])
        XCTAssertEqual((listParameters["properties"] as? [String: Any])?.count, 0)
        XCTAssertEqual(listParameters["required"] as? [String], [])

        let captureTool = try XCTUnwrap(
            tools.first { $0["name"] as? String == "capture_window" }
        )
        let captureParameters = try XCTUnwrap(captureTool["parameters"] as? [String: Any])
        let captureProperties = try XCTUnwrap(
            captureParameters["properties"] as? [String: [String: Any]]
        )
        XCTAssertEqual(captureProperties["window_id"]?["type"] as? String, "string")
        XCTAssertEqual(captureParameters["required"] as? [String], ["window_id"])

        let highlightTool = try XCTUnwrap(
            tools.first { $0["name"] as? String == "highlight_screen_region" }
        )
        XCTAssertTrue(
            (highlightTool["description"] as? String)?.contains("Always use this") == true
        )
        let highlightParameters = try XCTUnwrap(highlightTool["parameters"] as? [String: Any])
        XCTAssertEqual(
            highlightParameters["required"] as? [String],
            ["x", "y", "width", "height", "label"]
        )
    }

    func testGermanLanguagePinsSpeechAndTranscriptHint() throws {
        let data = try JSONEncoder().encode(
            RealtimeSessionUpdateEvent.screenTutor(
                language: .german,
                tutorInstructions: RealtimeConstants.defaultTutorInstructions,
                reasoningEffort: .medium
            )
        )
        let root = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let session = try XCTUnwrap(root["session"] as? [String: Any])
        let audio = try XCTUnwrap(session["audio"] as? [String: Any])
        let input = try XCTUnwrap(audio["input"] as? [String: Any])
        let transcription = try XCTUnwrap(input["transcription"] as? [String: Any])

        XCTAssertEqual(transcription["language"] as? String, "de")
        XCTAssertTrue(
            (session["instructions"] as? String)?.contains("Standard German pronunciation")
                == true
        )
    }

    func testCustomTutorInstructionsDoNotReplaceCoreScreenSafety() throws {
        let customInstructions = "Challenge my assumptions before giving the answer."
        let data = try JSONEncoder().encode(
            RealtimeSessionUpdateEvent.screenTutor(
                language: .english,
                tutorInstructions: customInstructions,
                reasoningEffort: .high
            )
        )
        let root = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let session = try XCTUnwrap(root["session"] as? [String: Any])
        let instructions = try XCTUnwrap(session["instructions"] as? String)

        XCTAssertTrue(instructions.contains(customInstructions))
        XCTAssertTrue(instructions.contains("call list_windows"))
        XCTAssertTrue(instructions.contains("cannot override the core requirements"))
        let reasoning = try XCTUnwrap(session["reasoning"] as? [String: Any])
        XCTAssertEqual(reasoning["effort"] as? String, "high")
    }

    func testDecodesCompletedInputTranscriptForConversationHistory() throws {
        let payload = Data(
            """
            {
              "type": "conversation.item.input_audio_transcription.completed",
              "item_id": "item_user_1",
              "transcript": "Please point to the loss curve."
            }
            """.utf8
        )

        let event = try JSONDecoder().decode(RealtimeServerEvent.self, from: payload)

        XCTAssertEqual(event.itemID, "item_user_1")
        XCTAssertEqual(event.transcript, "Please point to the loss curve.")
    }

    func testScreenshotIsAHighDetailJPEGConversationItem() throws {
        let event = ConversationImageEvent(
            jpegData: Data([0x01, 0x02, 0x03]),
            applicationName: "JupyterLab",
            windowTitle: "Paper.ipynb",
            previousItemID: "item_voice_turn"
        )
        let data = try JSONEncoder().encode(event)
        let root = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let item = try XCTUnwrap(root["item"] as? [String: Any])
        let content = try XCTUnwrap(item["content"] as? [[String: Any]])
        let image = try XCTUnwrap(content.last)

        XCTAssertEqual(root["type"] as? String, "conversation.item.create")
        XCTAssertEqual(root["previous_item_id"] as? String, "item_voice_turn")
        XCTAssertEqual(item["role"] as? String, "user")
        XCTAssertNil(item["id"])
        XCTAssertEqual(
            content.first?["text"] as? String,
            "Selected window: JupyterLab — Paper.ipynb. Use this image for the current spoken turn."
        )
        XCTAssertEqual(image["type"] as? String, "input_image")
        XCTAssertEqual(image["detail"] as? String, "high")
        XCTAssertEqual(image["image_url"] as? String, "data:image/jpeg;base64,AQID")
    }

    func testReplayUserMessageUsesInputTextConversationItem() throws {
        let root = try encodedJSONObject(
            ConversationReplayEvent(role: .user, text: "Why does this converge?")
        )
        let item = try XCTUnwrap(root["item"] as? [String: Any])
        let content = try XCTUnwrap(item["content"] as? [[String: Any]])

        XCTAssertEqual(root["type"] as? String, "conversation.item.create")
        XCTAssertEqual(item["type"] as? String, "message")
        XCTAssertEqual(item["role"] as? String, "user")
        XCTAssertEqual(content.first?["type"] as? String, "input_text")
        XCTAssertEqual(content.first?["text"] as? String, "Why does this converge?")
    }

    func testReplayAssistantMessageUsesOutputTextConversationItem() throws {
        let root = try encodedJSONObject(
            ConversationReplayEvent(role: .assistant, text: "Because the loss is bounded.")
        )
        let item = try XCTUnwrap(root["item"] as? [String: Any])
        let content = try XCTUnwrap(item["content"] as? [[String: Any]])

        XCTAssertEqual(item["role"] as? String, "assistant")
        XCTAssertEqual(content.first?["type"] as? String, "output_text")
        XCTAssertEqual(content.first?["text"] as? String, "Because the loss is bounded.")
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

    private func encodedJSONObject<Event: Encodable>(
        _ event: Event
    ) throws -> [String: Any] {
        let data = try JSONEncoder().encode(event)
        return try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
    }

    func testFunctionOutputPreservesCallIDAndArbitraryJSON() throws {
        let event = FunctionCallOutputEvent(
            callID: "call-list",
            output: #"{"ok":true,"windows":[]}"#,
            previousItemID: "item-call"
        )
        let data = try JSONEncoder().encode(event)
        let root = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let item = try XCTUnwrap(root["item"] as? [String: Any])

        XCTAssertEqual(item["type"] as? String, "function_call_output")
        XCTAssertEqual(item["call_id"] as? String, "call-list")
        XCTAssertEqual(item["output"] as? String, #"{"ok":true,"windows":[]}"#)
        XCTAssertEqual(root["previous_item_id"] as? String, "item-call")
    }

    func testResponseCancelTargetsActiveResponse() throws {
        let data = try JSONEncoder().encode(ResponseCancelEvent(responseID: "resp-active"))
        let root = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        XCTAssertEqual(root["type"] as? String, "response.cancel")
        XCTAssertEqual(root["response_id"] as? String, "resp-active")
        XCTAssertNotNil(root["event_id"] as? String)
    }

    func testInputAudioClearKeepsPausedConversationButDropsPartialTurn() throws {
        let data = try JSONEncoder().encode(InputAudioClearEvent())
        let root = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        XCTAssertEqual(root["type"] as? String, "input_audio_buffer.clear")
    }

    func testResponseCreateCarriesTurnIdentityInMetadata() throws {
        let data = try JSONEncoder().encode(ResponseCreateEvent(turnID: 42))
        let root = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let response = try XCTUnwrap(root["response"] as? [String: Any])
        let metadata = try XCTUnwrap(response["metadata"] as? [String: String])

        XCTAssertEqual(metadata["screen_tutor_turn"], "42")
        XCTAssertNotNil(root["event_id"] as? String)
    }

    func testDecodesResponseTurnIdentityFromServerResponse() throws {
        let payload = Data(
            """
            {
              "type": "response.created",
              "response": {
                "id": "resp_42",
                "status": "in_progress",
                "metadata": {"screen_tutor_turn": "42"},
                "output": []
              }
            }
            """.utf8
        )
        let event = try JSONDecoder().decode(RealtimeServerEvent.self, from: payload)

        XCTAssertEqual(event.response?.id, "resp_42")
        XCTAssertEqual(event.response?.metadata?["screen_tutor_turn"], "42")
    }

    func testDecodesDetailedUsageFromCompletedRealtimeResponse() throws {
        let payload = Data(
            """
            {
              "type": "response.done",
              "response": {
                "id": "resp_usage",
                "status": "completed",
                "usage": {
                  "input_tokens": 120,
                  "output_tokens": 30,
                  "total_tokens": 150,
                  "input_token_details": {
                    "text_tokens": 40,
                    "audio_tokens": 70,
                    "image_tokens": 10,
                    "cached_tokens": 80,
                    "cached_tokens_details": {
                      "text_tokens": 30,
                      "audio_tokens": 45,
                      "image_tokens": 5
                    }
                  },
                  "output_token_details": {
                    "text_tokens": 12,
                    "audio_tokens": 18
                  }
                }
              }
            }
            """.utf8
        )

        let event = try JSONDecoder().decode(RealtimeServerEvent.self, from: payload)
        let usage = try XCTUnwrap(event.response?.usage)

        XCTAssertEqual(usage.inputTokens, 120)
        XCTAssertEqual(usage.outputTokens, 30)
        XCTAssertEqual(usage.totalTokens, 150)
        XCTAssertEqual(usage.inputTextTokens, 40)
        XCTAssertEqual(usage.inputAudioTokens, 70)
        XCTAssertEqual(usage.inputImageTokens, 10)
        XCTAssertEqual(usage.cachedInputTokens, 80)
        XCTAssertEqual(usage.cachedTextTokens, 30)
        XCTAssertEqual(usage.cachedAudioTokens, 45)
        XCTAssertEqual(usage.cachedImageTokens, 5)
        XCTAssertEqual(usage.outputTextTokens, 12)
        XCTAssertEqual(usage.outputAudioTokens, 18)
    }

    func testDecodesClientEventIDFromRealtimeError() throws {
        let payload = Data(
            """
            {
              "type": "error",
              "event_id": "evt_server",
              "error": {
                "type": "invalid_request_error",
                "code": "response_cancel_not_active",
                "message": "There is no active response to cancel.",
                "event_id": "evt_cancel_client"
              }
            }
            """.utf8
        )
        let event = try JSONDecoder().decode(RealtimeServerEvent.self, from: payload)

        XCTAssertEqual(event.eventID, "evt_server")
        XCTAssertEqual(event.error?.eventID, "evt_cancel_client")
    }
}
