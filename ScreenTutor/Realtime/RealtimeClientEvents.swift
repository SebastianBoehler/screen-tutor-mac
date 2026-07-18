import Foundation

struct InputAudioAppendEvent: Encodable, Sendable {
    let type = "input_audio_buffer.append"
    let audio: String

    init(pcmData: Data) {
        audio = pcmData.base64EncodedString()
    }
}

struct ConversationImageEvent: Encodable, Sendable {
    let eventID: String
    let type = "conversation.item.create"
    let item: MessageItem

    init(jpegData: Data) {
        let identifier = UUID().uuidString
        eventID = "evt_screen_\(identifier)"
        item = MessageItem(
            id: "screen_\(identifier)",
            type: "message",
            role: "user",
            content: [
                ContentPart(
                    type: "input_text",
                    text: "Current active-window view for the next spoken turn.",
                    imageURL: nil,
                    detail: nil
                ),
                ContentPart(
                    type: "input_image",
                    text: nil,
                    imageURL: "data:image/jpeg;base64,\(jpegData.base64EncodedString())",
                    detail: "high"
                )
            ]
        )
    }

    enum CodingKeys: String, CodingKey {
        case type, item
        case eventID = "event_id"
    }

    struct MessageItem: Encodable, Sendable {
        let id: String
        let type: String
        let role: String
        let content: [ContentPart]
    }

    struct ContentPart: Encodable, Sendable {
        let type: String
        let text: String?
        let imageURL: String?
        let detail: String?

        enum CodingKeys: String, CodingKey {
            case type, text, detail
            case imageURL = "image_url"
        }
    }
}

struct ConversationTruncateEvent: Encodable, Sendable {
    let type = "conversation.item.truncate"
    let itemID: String
    let contentIndex = 0
    let audioEndMilliseconds: Int

    enum CodingKeys: String, CodingKey {
        case type
        case itemID = "item_id"
        case contentIndex = "content_index"
        case audioEndMilliseconds = "audio_end_ms"
    }
}

struct ResponseCreateEvent: Encodable, Sendable {
    let eventID = "evt_response_\(UUID().uuidString)"
    let type = "response.create"

    enum CodingKeys: String, CodingKey {
        case type
        case eventID = "event_id"
    }
}

struct FunctionCallOutputEvent: Encodable, Sendable {
    let eventID = "evt_tool_\(UUID().uuidString)"
    let type = "conversation.item.create"
    let item: Item

    init(callID: String) {
        item = Item(
            type: "function_call_output",
            callID: callID,
            output: "{\"status\":\"highlighted\"}"
        )
    }

    enum CodingKeys: String, CodingKey {
        case type, item
        case eventID = "event_id"
    }

    struct Item: Encodable, Sendable {
        let type: String
        let callID: String
        let output: String

        enum CodingKeys: String, CodingKey {
            case type, output
            case callID = "call_id"
        }
    }
}
