import SwiftUI

struct HUDControlsView: View {
    let model: AppModel

    var body: some View {
        ControlGroup {
            Button(action: model.toggleSession) {
                Label(
                    model.phase.primaryActionLabel,
                    systemImage: model.phase.primaryActionSymbolName
                )
            }
            .disabled(!model.phase.isPrimaryActionEnabled)
            .help(model.phase.primaryActionLabel)

            Button {
                Task { await model.stopSession() }
            } label: {
                Label("End conversation", systemImage: "stop.fill")
            }
            .disabled(!model.phase.isStopActionEnabled)
            .help("End conversation and clear its live context")

            SettingsLink {
                Label("Open Settings", systemImage: "gearshape")
            }
            .help("Open ScreenTutor Settings")
        }
        .labelStyle(.iconOnly)
        .controlSize(.small)
        .fixedSize()
    }
}
