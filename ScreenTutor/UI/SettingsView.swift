import SwiftUI

struct SettingsView: View {
    let model: AppSettingsModel
    @State private var apiKey = ""

    var body: some View {
        Form {
            Section("OpenAI") {
                SecureField("API key", text: $apiKey)
                    .textContentType(.password)
                HStack {
                    Button("Save in Keychain") {
                        model.saveAPIKey(apiKey)
                        if model.hasAPIKey { apiKey = "" }
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if model.hasAPIKey {
                        Label("Saved", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Spacer()
                        Button("Delete", role: .destructive) { model.deleteAPIKey() }
                    }
                }
                Text("This personal BYOK build keeps the key in macOS Keychain. It is never stored in project files.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Tutor") {
                Picker(
                    "Spoken language",
                    selection: Binding(
                        get: { model.tutorLanguage },
                        set: { model.setTutorLanguage($0) }
                    )
                ) {
                    ForEach(TutorLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                Text(
                    "Automatic follows your latest spoken language. A fixed language also helps "
                        + "transcription. Changes apply to new conversations."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section("Permissions") {
                HStack {
                    Label(
                        "Microphone",
                        systemImage: model.microphonePermissionGranted
                            ? "checkmark.circle.fill"
                            : "circle.dashed"
                    )
                    .foregroundStyle(model.microphonePermissionGranted ? .green : .secondary)
                    Spacer()
                }
                HStack {
                    Label(
                        "Screen Recording",
                        systemImage: model.screenPermissionGranted
                            ? "checkmark.circle.fill"
                            : "circle.dashed"
                    )
                    .foregroundStyle(model.screenPermissionGranted ? .green : .secondary)
                    Spacer()
                    if !model.screenPermissionGranted {
                        Button("Grant Access") { model.requestScreenPermission() }
                    }
                }
                Button("Open Screen Recording Settings") {
                    model.openScreenRecordingSettings()
                }
            }

            Section("System") {
                Toggle(
                    "Launch ScreenTutor at login",
                    isOn: Binding(
                        get: { model.launchAtLoginState.isEnabled },
                        set: { enabled in model.setLaunchAtLogin(enabled) }
                    )
                )
                Text("Global shortcut: Command-Shift-Space")
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = model.errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 560)
        .onAppear { model.refresh() }
    }

}
