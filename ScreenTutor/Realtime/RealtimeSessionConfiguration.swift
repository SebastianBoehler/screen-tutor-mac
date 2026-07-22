import Foundation

struct RealtimeSessionUpdateEvent: Encodable, Sendable {
    let eventID: String
    let type = "session.update"
    let session: RealtimeSessionConfiguration

    enum CodingKeys: String, CodingKey {
        case type, session
        case eventID = "event_id"
    }

    static func screenTutor(
        model: RealtimeModel,
        language: TutorLanguage,
        tutorInstructions: String,
        reasoningEffort: ReasoningEffort
    ) -> RealtimeSessionUpdateEvent {
        RealtimeSessionUpdateEvent(
            eventID: "evt_session_\(UUID().uuidString)",
            session: RealtimeSessionConfiguration(
                type: "realtime",
                model: model.rawValue,
                instructions: RealtimeConstants.tutorInstructions(
                    language: language,
                    customTutorInstructions: tutorInstructions
                ),
                outputModalities: ["audio"],
                tools: [.listWindows, .captureWindow, .pointAtScreenPosition, .captureCamera],
                toolChoice: "auto",
                parallelToolCalls: false,
                reasoning: RealtimeReasoningConfiguration(effort: reasoningEffort),
                audio: RealtimeAudioConfiguration(
                    input: RealtimeInputAudioConfiguration(
                        format: RealtimeAudioFormat(type: "audio/pcm", rate: 24_000),
                        noiseReduction: RealtimeNoiseReductionConfiguration(
                            type: "far_field"
                        ),
                        transcription: RealtimeAudioTranscriptionConfiguration(
                            model: "gpt-4o-mini-transcribe",
                            language: language.transcriptionLanguageCode
                        ),
                        turnDetection: RealtimeTurnDetection(
                            type: "semantic_vad",
                            eagerness: "auto",
                            createResponse: false,
                            interruptResponse: true
                        )
                    ),
                    output: RealtimeOutputAudioConfiguration(
                        format: RealtimeAudioFormat(type: "audio/pcm", rate: 24_000),
                        voice: RealtimeConstants.voice
                    )
                )
            )
        )
    }
}

struct RealtimeSessionConfiguration: Encodable, Sendable {
    let type: String
    let model: String
    let instructions: String
    let outputModalities: [String]
    let tools: [RealtimeFunctionTool]
    let toolChoice: String
    let parallelToolCalls: Bool
    let reasoning: RealtimeReasoningConfiguration
    let audio: RealtimeAudioConfiguration

    enum CodingKeys: String, CodingKey {
        case type, model, instructions, tools, reasoning, audio
        case outputModalities = "output_modalities"
        case toolChoice = "tool_choice"
        case parallelToolCalls = "parallel_tool_calls"
    }
}

struct RealtimeAudioConfiguration: Encodable, Sendable {
    let input: RealtimeInputAudioConfiguration
    let output: RealtimeOutputAudioConfiguration
}

struct RealtimeInputAudioConfiguration: Encodable, Sendable {
    let format: RealtimeAudioFormat
    let noiseReduction: RealtimeNoiseReductionConfiguration
    let transcription: RealtimeAudioTranscriptionConfiguration
    let turnDetection: RealtimeTurnDetection

    enum CodingKeys: String, CodingKey {
        case format, transcription
        case noiseReduction = "noise_reduction"
        case turnDetection = "turn_detection"
    }
}

struct RealtimeNoiseReductionConfiguration: Encodable, Sendable {
    let type: String
}

struct RealtimeReasoningConfiguration: Encodable, Sendable {
    let effort: ReasoningEffort
}

struct RealtimeAudioTranscriptionConfiguration: Encodable, Sendable {
    let model: String
    let language: String?
}

struct RealtimeOutputAudioConfiguration: Encodable, Sendable {
    let format: RealtimeAudioFormat
    let voice: String
}

struct RealtimeAudioFormat: Encodable, Sendable {
    let type: String
    let rate: Int?
}

struct RealtimeTurnDetection: Encodable, Sendable {
    let type: String
    let eagerness: String
    let createResponse: Bool
    let interruptResponse: Bool

    enum CodingKeys: String, CodingKey {
        case type, eagerness
        case createResponse = "create_response"
        case interruptResponse = "interrupt_response"
    }
}
