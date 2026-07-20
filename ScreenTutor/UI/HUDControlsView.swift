import SwiftUI

struct HUDControlsView: View {
    let model: AppModel

    var body: some View {
        let microphone = model.microphoneControlState
        HStack(spacing: 8) {
            Button(action: model.toggleSession) {
                Label(
                    microphone.compactLabel,
                    systemImage: microphone.symbolName
                )
                .lineLimit(1)
            }
            .buttonStyle(.plain)
            .foregroundStyle(microphone.tone.foregroundColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(microphone.tone.color, in: Capsule())
            .contentShape(Capsule())
            .disabled(!microphone.isEnabled)
            .opacity(microphone.isEnabled ? 1 : 0.62)
            .help("\(microphone.label). \(microphone.accessibilityHint)")
            .accessibilityLabel(microphone.label)
            .accessibilityHint(microphone.accessibilityHint)

            Button {
                Task { await model.stopSession() }
            } label: {
                Label("End", systemImage: "stop.fill")
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .disabled(!model.phase.isStopActionEnabled)
            .help("End conversation and clear its live context")
            .accessibilityLabel("End conversation")

            SettingsLink {
                Label("Settings", systemImage: "gearshape")
            }
            .buttonStyle(.bordered)
            .help("Open ScreenTutor Settings")
            .accessibilityLabel("Open settings")
        }
        .controlSize(.small)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}
