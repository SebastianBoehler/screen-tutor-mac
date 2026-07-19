import SwiftUI

struct HUDControlsView: View {
    let model: AppModel

    var body: some View {
        let microphone = model.microphoneControlState
        HStack(spacing: 8) {
            Button(action: model.toggleSession) {
                Label(
                    microphone.label,
                    systemImage: microphone.symbolName
                )
            }
            .buttonStyle(.borderedProminent)
            .tint(microphone.tone.color)
            .disabled(!microphone.isEnabled)
            .help("\(microphone.label). \(microphone.accessibilityHint)")
            .accessibilityHint(microphone.accessibilityHint)

            Button {
                Task { await model.stopSession() }
            } label: {
                Label("End conversation", systemImage: "stop.fill")
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .disabled(!model.phase.isStopActionEnabled)
            .help("End conversation and clear its live context")

            SettingsLink {
                Label("Open settings", systemImage: "gearshape")
            }
            .buttonStyle(.bordered)
            .help("Open ScreenTutor Settings")
        }
        .controlSize(.small)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}
