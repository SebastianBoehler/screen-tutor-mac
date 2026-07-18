import AppKit
import SwiftUI

struct MenuBarView: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if !model.assistantTranscript.isEmpty {
                Text(model.assistantTranscript)
                    .font(.callout)
                    .lineLimit(5)
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }

            if let errorMessage = model.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: model.toggleSession) {
                Label(
                    model.phase.isActive ? "Stop conversation" : "Start conversation",
                    systemImage: model.phase.isActive ? "stop.fill" : "mic.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(model.phase == .requestingPermissions || model.phase == .connecting)

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

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: model.phase.symbolName)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("ScreenTutor").font(.headline)
                Text(model.statusDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Text(model.phase.title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.secondary.opacity(0.1), in: Capsule())
        }
    }
}
