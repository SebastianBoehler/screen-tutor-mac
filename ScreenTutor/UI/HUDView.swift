import SwiftUI

struct HUDView: View {
    let model: AppModel
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let transcript = model.ambientTranscriptPresentation
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: model.statusSymbolName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(model.errorMessage == nil ? Color.accentColor : Color.red)
                        .frame(width: 34, height: 34)
                        .background(.primary.opacity(0.08), in: Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.statusTitle)
                            .font(.headline)
                            .lineLimit(1)
                        Text(model.statusDetail)
                            .font(.caption)
                            .foregroundStyle(model.errorMessage == nil ? Color.secondary : Color.red)
                            .lineLimit(2)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("ScreenTutor \(model.statusTitle). \(model.statusDetail)")
                .accessibilityHint("Drag the background to move the overlay.")
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .help("Drag to move ScreenTutor")
                    .accessibilityHidden(true)
            }

            if !model.liveToolActivities.isEmpty {
                LiveToolActivityStrip(activities: model.liveToolActivities)
            }

            if transcript.isExpanded {
                Divider()
                AmbientTranscriptView(
                    userText: transcript.userText,
                    assistantText: transcript.assistantText
                )
            }

            Divider()
            HUDControlsView(model: model)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: 420, height: transcript.panelHeight, alignment: .top)
        .background {
            if reduceTransparency {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor))
            } else {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.12))
        }
    }
}
