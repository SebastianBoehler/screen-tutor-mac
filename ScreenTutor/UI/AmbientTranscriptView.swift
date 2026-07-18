import SwiftUI

struct AmbientTranscriptView: View {
    let userText: String
    let assistantText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !userText.isEmpty {
                transcriptRow(
                    title: "You",
                    symbol: "person.fill",
                    text: userText,
                    lineLimit: 2
                )
            }
            if !assistantText.isEmpty {
                transcriptRow(
                    title: "ScreenTutor",
                    symbol: "sparkles",
                    text: assistantText,
                    lineLimit: 4
                )
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func transcriptRow(
        title: String,
        symbol: String,
        text: String,
        lineLimit: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.callout)
                .lineLimit(lineLimit)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(text)")
    }
}
