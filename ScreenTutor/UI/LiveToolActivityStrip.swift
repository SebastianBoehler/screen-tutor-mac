import SwiftUI

struct LiveToolActivityStrip: View {
    let activities: [LiveToolActivity]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(activities) { activity in
                    Label(
                        activity.displayName,
                        systemImage: statusSymbol(for: activity)
                    )
                    .font(.caption)
                    .foregroundStyle(statusColor(for: activity))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        statusColor(for: activity).opacity(0.12),
                        in: Capsule()
                    )
                    .accessibilityLabel(
                        "\(activity.displayName), \(statusLabel(for: activity.status))"
                    )
                }
            }
        }
        .scrollIndicators(.hidden)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("ScreenTutor tool activity")
    }

    private func statusSymbol(for activity: LiveToolActivity) -> String {
        switch activity.status {
        case .started: activity.symbolName
        case .succeeded: "checkmark.circle.fill"
        case .failed: "exclamationmark.circle.fill"
        }
    }

    private func statusColor(for activity: LiveToolActivity) -> Color {
        switch activity.status {
        case .started: .accentColor
        case .succeeded: .green
        case .failed: .orange
        }
    }

    private func statusLabel(for status: LiveToolActivityStatus) -> String {
        switch status {
        case .started: "in progress"
        case .succeeded: "complete"
        case .failed: "failed"
        }
    }
}
