import Foundation

/// Adds a user-role context item (text plus an optional image) to the Realtime
/// conversation. Used for desk-observer notes and desk frames; the text always
/// identifies the content as automated so the model never mistakes it for speech.
struct DeskContextItemEvent: Encodable, Sendable {
    let eventID: String
    let type = "conversation.item.create"
    let previousItemID: String?
    let item: MessageItem

    init(
        itemID: String? = nil,
        text: String,
        jpegData: Data? = nil,
        previousItemID: String? = nil
    ) {
        eventID = "evt_desk_\(UUID().uuidString)"
        self.previousItemID = previousItemID
        var content = [ContentPart(type: "input_text", text: text, imageURL: nil, detail: nil)]
        if let jpegData {
            content.append(
                ContentPart(
                    type: "input_image",
                    text: nil,
                    imageURL: "data:image/jpeg;base64,\(jpegData.base64EncodedString())",
                    detail: "high"
                )
            )
        }
        item = MessageItem(id: itemID, type: "message", role: "user", content: content)
    }

    /// Realtime item IDs are limited to 32 characters.
    static func makeItemID() -> String {
        "desk_" + String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(24))
    }

    enum CodingKeys: String, CodingKey {
        case type, item
        case eventID = "event_id"
        case previousItemID = "previous_item_id"
    }

    struct MessageItem: Encodable, Sendable {
        let id: String?
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
