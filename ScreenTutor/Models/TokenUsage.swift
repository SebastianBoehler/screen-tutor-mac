import Foundation

struct TokenUsage: Codable, Equatable, Sendable {
    let inputTokens: Int
    let outputTokens: Int
    let totalTokens: Int
    let inputTextTokens: Int
    let inputAudioTokens: Int
    let inputImageTokens: Int
    let cachedInputTokens: Int
    let cachedTextTokens: Int
    let cachedAudioTokens: Int
    let cachedImageTokens: Int
    let outputTextTokens: Int
    let outputAudioTokens: Int

    init(
        inputTokens: Int = 0,
        outputTokens: Int = 0,
        totalTokens: Int = 0,
        inputTextTokens: Int = 0,
        inputAudioTokens: Int = 0,
        inputImageTokens: Int = 0,
        cachedInputTokens: Int = 0,
        cachedTextTokens: Int = 0,
        cachedAudioTokens: Int = 0,
        cachedImageTokens: Int = 0,
        outputTextTokens: Int = 0,
        outputAudioTokens: Int = 0
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalTokens = totalTokens
        self.inputTextTokens = inputTextTokens
        self.inputAudioTokens = inputAudioTokens
        self.inputImageTokens = inputImageTokens
        self.cachedInputTokens = cachedInputTokens
        self.cachedTextTokens = cachedTextTokens
        self.cachedAudioTokens = cachedAudioTokens
        self.cachedImageTokens = cachedImageTokens
        self.outputTextTokens = outputTextTokens
        self.outputAudioTokens = outputAudioTokens
    }

    init(from decoder: Decoder) throws {
        let root = try decoder.container(keyedBy: CodingKeys.self)
        inputTokens = try root.decodeIfPresent(Int.self, forKey: .inputTokens) ?? 0
        outputTokens = try root.decodeIfPresent(Int.self, forKey: .outputTokens) ?? 0
        totalTokens = try root.decodeIfPresent(Int.self, forKey: .totalTokens) ?? 0

        let input = try? root.nestedContainer(
            keyedBy: DetailCodingKeys.self,
            forKey: .inputTokenDetails
        )
        inputTextTokens = try input?.decodeIfPresent(Int.self, forKey: .textTokens) ?? 0
        inputAudioTokens = try input?.decodeIfPresent(Int.self, forKey: .audioTokens) ?? 0
        inputImageTokens = try input?.decodeIfPresent(Int.self, forKey: .imageTokens) ?? 0
        cachedInputTokens = try input?.decodeIfPresent(Int.self, forKey: .cachedTokens) ?? 0

        let cached = try? input?.nestedContainer(
            keyedBy: DetailCodingKeys.self,
            forKey: .cachedTokenDetails
        )
        cachedTextTokens = try cached?.decodeIfPresent(Int.self, forKey: .textTokens) ?? 0
        cachedAudioTokens = try cached?.decodeIfPresent(Int.self, forKey: .audioTokens) ?? 0
        cachedImageTokens = try cached?.decodeIfPresent(Int.self, forKey: .imageTokens) ?? 0

        let output = try? root.nestedContainer(
            keyedBy: DetailCodingKeys.self,
            forKey: .outputTokenDetails
        )
        outputTextTokens = try output?.decodeIfPresent(Int.self, forKey: .textTokens) ?? 0
        outputAudioTokens = try output?.decodeIfPresent(Int.self, forKey: .audioTokens) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var root = encoder.container(keyedBy: CodingKeys.self)
        try root.encode(inputTokens, forKey: .inputTokens)
        try root.encode(outputTokens, forKey: .outputTokens)
        try root.encode(totalTokens, forKey: .totalTokens)

        var input = root.nestedContainer(
            keyedBy: DetailCodingKeys.self,
            forKey: .inputTokenDetails
        )
        try input.encode(inputTextTokens, forKey: .textTokens)
        try input.encode(inputAudioTokens, forKey: .audioTokens)
        try input.encode(inputImageTokens, forKey: .imageTokens)
        try input.encode(cachedInputTokens, forKey: .cachedTokens)
        var cached = input.nestedContainer(
            keyedBy: DetailCodingKeys.self,
            forKey: .cachedTokenDetails
        )
        try cached.encode(cachedTextTokens, forKey: .textTokens)
        try cached.encode(cachedAudioTokens, forKey: .audioTokens)
        try cached.encode(cachedImageTokens, forKey: .imageTokens)

        var output = root.nestedContainer(
            keyedBy: DetailCodingKeys.self,
            forKey: .outputTokenDetails
        )
        try output.encode(outputTextTokens, forKey: .textTokens)
        try output.encode(outputAudioTokens, forKey: .audioTokens)
    }

    static func + (lhs: TokenUsage, rhs: TokenUsage) -> TokenUsage {
        TokenUsage(
            inputTokens: lhs.inputTokens + rhs.inputTokens,
            outputTokens: lhs.outputTokens + rhs.outputTokens,
            totalTokens: lhs.totalTokens + rhs.totalTokens,
            inputTextTokens: lhs.inputTextTokens + rhs.inputTextTokens,
            inputAudioTokens: lhs.inputAudioTokens + rhs.inputAudioTokens,
            inputImageTokens: lhs.inputImageTokens + rhs.inputImageTokens,
            cachedInputTokens: lhs.cachedInputTokens + rhs.cachedInputTokens,
            cachedTextTokens: lhs.cachedTextTokens + rhs.cachedTextTokens,
            cachedAudioTokens: lhs.cachedAudioTokens + rhs.cachedAudioTokens,
            cachedImageTokens: lhs.cachedImageTokens + rhs.cachedImageTokens,
            outputTextTokens: lhs.outputTextTokens + rhs.outputTextTokens,
            outputAudioTokens: lhs.outputAudioTokens + rhs.outputAudioTokens
        )
    }

    private enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case totalTokens = "total_tokens"
        case inputTokenDetails = "input_token_details"
        case outputTokenDetails = "output_token_details"
    }

    private enum DetailCodingKeys: String, CodingKey {
        case textTokens = "text_tokens"
        case audioTokens = "audio_tokens"
        case imageTokens = "image_tokens"
        case cachedTokens = "cached_tokens"
        case cachedTokenDetails = "cached_tokens_details"
    }
}
