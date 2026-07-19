import SwiftUI

struct ConversationUsageSummaryView: View {
    let usage: TokenUsage

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(
                "\(usage.totalTokens.formatted()) total tokens",
                systemImage: "chart.bar.xaxis"
            )
            .font(.headline)

            Text(
                "\(usage.inputTokens.formatted()) input · "
                    + "\(usage.outputTokens.formatted()) output · "
                    + "\(usage.cachedInputTokens.formatted()) cached input"
            )
            .foregroundStyle(.secondary)

            if hasModalityDetails {
                Text(modalityDescription)
                    .foregroundStyle(.secondary)
            }

            Text("Provider-reported usage across all responses in this conversation.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private var hasModalityDetails: Bool {
        usage.inputTextTokens > 0
            || usage.outputTextTokens > 0
            || usage.inputAudioTokens > 0
            || usage.outputAudioTokens > 0
            || usage.inputImageTokens > 0
    }

    private var modalityDescription: String {
        var parts = [
            "Text \(usage.inputTextTokens.formatted()) in / "
                + "\(usage.outputTextTokens.formatted()) out",
            "Audio \(usage.inputAudioTokens.formatted()) in / "
                + "\(usage.outputAudioTokens.formatted()) out"
        ]
        if usage.inputImageTokens > 0 {
            parts.append("Images \(usage.inputImageTokens.formatted()) in")
        }
        return parts.joined(separator: " · ")
    }
}
