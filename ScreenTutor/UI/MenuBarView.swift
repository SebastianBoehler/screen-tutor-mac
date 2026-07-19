import AppKit
import SwiftUI

struct MenuBarView: View {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let microphone = model.microphoneControlState
        VStack(alignment: .leading, spacing: 14) {
            Text("ScreenTutor")
                .font(.headline)

            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.statusTitle)
                        .font(.headline)
                    Text(model.statusDetail)
                        .font(.caption)
                        .foregroundStyle(model.errorMessage == nil ? Color.secondary : Color.red)
                        .lineLimit(2)
                }
            } icon: {
                Image(systemName: model.statusSymbolName)
                    .font(.title2)
                    .foregroundStyle(model.errorMessage == nil ? Color.accentColor : Color.red)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Status: \(model.statusTitle). \(model.statusDetail)")

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
                Label(microphone.label, systemImage: microphone.symbolName)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(microphone.tone.color)
            .controlSize(.large)
            .disabled(!microphone.isEnabled)
            .accessibilityHint(microphone.accessibilityHint)

            if model.phase.hasConversation {
                Button(action: model.startNewConversation) {
                    Label("New conversation", systemImage: "plus.bubble")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button(action: model.toggleTranscriptOverlay) {
                    Label(
                        model.showsTranscriptOverlay ? "Hide screen transcript" : "Show screen transcript",
                        systemImage: model.showsTranscriptOverlay ? "captions.bubble.fill" : "captions.bubble"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            Button {
                openWindow(id: "conversation-history")
                NSApplication.shared.activate(ignoringOtherApps: true)
            } label: {
                Label("Conversation History…", systemImage: "clock.arrow.circlepath")
            }
            .buttonStyle(.plain)

            if let historyError = model.history.errorMessage {
                Label("History: \(historyError)", systemImage: "externaldrive.badge.exclamationmark")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
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
