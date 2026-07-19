import Foundation

enum RealtimeModel: String, CaseIterable, Identifiable, Sendable {
    case flagship = "gpt-realtime-2.1"
    case economy = "gpt-realtime-2.1-mini"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .flagship: "Best tutoring quality"
        case .economy: "Lower cost"
        }
    }

    var guidance: String {
        switch self {
        case .flagship:
            "GPT-Realtime-2.1 offers the strongest voice tutoring quality."
        case .economy:
            "GPT-Realtime-2.1 mini is faster and cheaper, but its distilled model may give less capable tutoring."
        }
    }
}
