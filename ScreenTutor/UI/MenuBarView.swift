import AppKit
import SwiftUI

struct MenuBarView: View {
    let model: AppModel

    private var statusTitle: String {
        model.errorMessage == nil ? model.phase.title : "Needs attention"
    }

    private var statusSymbolName: String {
        model.errorMessage == nil ? model.phase.symbolName : "exclamationmark.triangle.fill"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ScreenTutor")
                .font(.headline)

            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(statusTitle)
                        .font(.headline)
                    Text(model.statusDetail)
                        .font(.caption)
                        .foregroundStyle(model.errorMessage == nil ? Color.secondary : Color.red)
                        .lineLimit(2)
                }
            } icon: {
                Image(systemName: statusSymbolName)
                    .font(.title2)
                    .foregroundStyle(model.errorMessage == nil ? Color.accentColor : Color.red)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Status: \(statusTitle). \(model.statusDetail)")

            if !model.assistantTranscript.isEmpty {
                Text(model.assistantTranscript)
                    .font(.callout)
                    .lineLimit(5)
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }

            Button(action: model.toggleSession) {
                Label(model.phase.primaryActionLabel, systemImage: model.phase.primaryActionSymbolName)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!model.phase.isPrimaryActionEnabled)

            if model.phase.hasConversation {
                Button(action: model.startNewConversation) {
                    Label("New conversation", systemImage: "plus.bubble")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            HStack {
                SettingsLink {
                    Label("Settings", systemImage: "gearshape")
                }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
            .buttonStyle(.plain)
            .font(.callout)
        }
        .padding(16)
        .frame(width: 340)
    }
}
