import Foundation

struct RealtimeServerEvent: Decodable, Sendable {
    let type: String
    let eventID: String?
    let delta: String?
    let transcript: String?
    let itemID: String?
    let previousItemID: String?
    let responseID: String?
    let audioStartMilliseconds: Int?
    let audioEndMilliseconds: Int?
    let error: RealtimeAPIError?
    let response: RealtimeResponse?
    let item: RealtimeItem?

    enum CodingKeys: String, CodingKey {
        case type, delta, transcript, error, response, item
        case eventID = "event_id"
        case itemID = "item_id"
        case previousItemID = "previous_item_id"
        case responseID = "response_id"
        case audioStartMilliseconds = "audio_start_ms"
        case audioEndMilliseconds = "audio_end_ms"
    }
}

struct RealtimeAPIError: Decodable, Sendable {
    let type: String?
    let code: String?
    let message: String
    let param: String?
}

struct RealtimeResponse: Decodable, Sendable {
    let id: String?
    let status: String?
    let output: [RealtimeItem]?
}

struct RealtimeItem: Decodable, Sendable {
    let id: String?
    let type: String?
    let name: String?
    let callID: String?
    let arguments: String?

    enum CodingKeys: String, CodingKey {
        case id, type, name, arguments
        case callID = "call_id"
    }
}
