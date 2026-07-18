import Foundation

enum TutorLanguage: String, CaseIterable, Identifiable, Sendable {
    case automatic
    case german
    case english

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .automatic: "Automatic"
        case .german: "Deutsch"
        case .english: "English"
        }
    }

    var transcriptionLanguageCode: String? {
        switch self {
        case .automatic: nil
        case .german: "de"
        case .english: "en"
        }
    }

    var realtimeInstructions: String {
        switch self {
        case .automatic:
            """
            Reply in the language of the user's most recent spoken turn. Use natural pronunciation
            and prosody for that language. Do not default to English when the user speaks German,
            and never pronounce German text with English phonetics.
            """
        case .german:
            """
            Conduct the conversation in German. Speak with natural Standard German pronunciation
            and prosody. Do not pronounce German text with English phonetics.
            """
        case .english:
            """
            Conduct the conversation in English. Speak with natural English pronunciation and
            prosody.
            """
        }
    }
}
