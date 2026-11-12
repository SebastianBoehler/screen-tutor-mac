import Foundation

/// Minimal OpenRouter chat-completions client for one image + text request.
/// Routing prefers the highest-throughput endpoint and only providers that
/// neither retain nor train on prompts.
struct OpenRouterClient: Sendable {
    static let endpoint = URL(string: "https://openrouter.ai/api/v1/chat/completions")!

    var session: URLSession = .shared

    func complete(
        apiKey: String,
        model: String,
        system: String,
        userText: String,
        jpegData: Data?,
        maxTokens: Int = 900
    ) async throws -> OpenRouterCompletion {
        var content: [OpenRouterRequest.Part] = [.init(type: "text", text: userText, imageURL: nil)]
        if let jpegData {
            content.append(
                .init(
                    type: "image_url",
                    text: nil,
                    imageURL: .init(url: "data:image/jpeg;base64,\(jpegData.base64EncodedString())")
                )
            )
        }
        let body = OpenRouterRequest(
            model: model,
            messages: [
                .init(role: "system", content: [.init(type: "text", text: system, imageURL: nil)]),
                .init(role: "user", content: content)
            ],
            responseFormat: .init(type: "json_object"),
            temperature: 0.2,
            maxTokens: maxTokens,
            provider: .init(sort: "throughput", dataCollection: "deny", zdr: true)
        )

        var request = URLRequest(url: Self.endpoint, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("ScreenTutor", forHTTPHeaderField: "X-Title")
        request.httpBody = try JSONEncoder().encode(body)

        let started = Date()
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let message = (try? JSONDecoder().decode(OpenRouterErrorEnvelope.self, from: data))?
                .error.message ?? String(data: data.prefix(300), encoding: .utf8) ?? ""
            throw OpenRouterError.http(status, message)
        }
        let decoded = try JSONDecoder().decode(OpenRouterResponse.self, from: data)
        if let error = decoded.error { throw OpenRouterError.http(status, error.message) }
        guard let text = decoded.choices?.first?.message.content, !text.isEmpty else {
            throw OpenRouterError.emptyResponse
        }
        return OpenRouterCompletion(
            text: text,
            model: decoded.model ?? model,
            latency: Date().timeIntervalSince(started),
            completionTokens: decoded.usage?.completionTokens
        )
    }
}

struct OpenRouterCompletion: Sendable {
    let text: String
    let model: String
    let latency: TimeInterval
    let completionTokens: Int?
}

enum OpenRouterError: LocalizedError {
    case missingKey
    case http(Int, String)
    case emptyResponse
    case invalidJSON

    var errorDescription: String? {
        switch self {
        case .missingKey:
            "Add an OpenRouter API key in Settings (or set OPENROUTER_API_KEY) to enable the desk observer."
        case .http(let status, let message):
            "OpenRouter error \(status): \(message)"
        case .emptyResponse:
            "OpenRouter returned an empty response."
        case .invalidJSON:
            "The desk observer returned malformed JSON."
        }
    }
}

private struct OpenRouterRequest: Encodable {
    let model: String
    let messages: [Message]
    let responseFormat: ResponseFormat
    let temperature: Double
    let maxTokens: Int
    let provider: Provider

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature, provider
        case responseFormat = "response_format"
        case maxTokens = "max_tokens"
    }

    struct Message: Encodable {
        let role: String
        let content: [Part]
    }

    struct Part: Encodable {
        let type: String
        let text: String?
        let imageURL: ImageURL?

        enum CodingKeys: String, CodingKey {
            case type, text
            case imageURL = "image_url"
        }
    }

    struct ImageURL: Encodable {
        let url: String
    }

    struct ResponseFormat: Encodable {
        let type: String
    }

    struct Provider: Encodable {
        let sort: String
        let dataCollection: String
        let zdr: Bool

        enum CodingKeys: String, CodingKey {
            case sort, zdr
            case dataCollection = "data_collection"
        }
    }
}

private struct OpenRouterResponse: Decodable {
    let model: String?
    let choices: [Choice]?
    let usage: Usage?
    let error: APIError?

    struct Choice: Decodable {
        let message: Message
    }

    struct Message: Decodable {
        let content: String?
    }

    struct Usage: Decodable {
        let completionTokens: Int?

        enum CodingKeys: String, CodingKey {
            case completionTokens = "completion_tokens"
        }
    }

    struct APIError: Decodable {
        let message: String
    }
}

private struct OpenRouterErrorEnvelope: Decodable {
    let error: OpenRouterResponse.APIError
}

enum LenientJSON {
    /// Extracts the first JSON object from model text, tolerating code fences.
    static func objectData(from text: String) -> Data? {
        guard
            let start = text.firstIndex(of: "{"),
            let end = text.lastIndex(of: "}"),
            start < end
        else { return nil }
        return String(text[start...end]).data(using: .utf8)
    }
}
