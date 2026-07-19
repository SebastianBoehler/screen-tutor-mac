import Foundation

enum ReasoningEffort: String, CaseIterable, Codable, Identifiable, Sendable {
    case minimal
    case low
    case medium
    case high
    case xhigh

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .minimal: "Minimal"
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        case .xhigh: "Extra high"
        }
    }

    var guidance: String {
        switch self {
        case .minimal: "Fastest for simple, direct questions."
        case .low: "Responsive with basic reasoning; recommended for voice."
        case .medium: "More thought for multi-step explanations."
        case .high: "Deeper reasoning with more latency and token use."
        case .xhigh: "Maximum reasoning when latency and cost matter less."
        }
    }
}
