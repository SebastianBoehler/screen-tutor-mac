import SwiftUI

struct HUDControlsView: View {
    let model: AppModel

    var body: some View {
        HStack(spacing: 8) {
            Button(action: model.toggleSession) {
                Label(
                    model.phase.primaryActionLabel,
                    systemImage: model.phase.primaryActionSymbolName
                )
            }
            .buttonStyle(.borderedProminent)
            .disabled(!model.phase.isPrimaryActionEnabled)
            .help(model.phase.primaryActionLabel)

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
                Label("Settings", systemImage: "gearshape")
            }
            .buttonStyle(.bordered)
            .help("Open ScreenTutor Settings")
        }
        .controlSize(.small)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}
