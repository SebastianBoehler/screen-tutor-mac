import SwiftUI

struct SettingsView: View {
    let model: AppSettingsModel
    @State private var apiKey = ""
    @State private var tutorInstructionsDraft = ""

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

                Picker(
                    "Reasoning effort",
                    selection: Binding(
                        get: { model.reasoningEffort },
                        set: { model.setReasoningEffort($0) }
                    )
                ) {
                    ForEach(ReasoningEffort.allCases) { effort in
                        Text(effort.displayName).tag(effort)
                    }
                }
                Text(
                    model.reasoningEffort.guidance
                        + " Changes apply to new conversations."
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    TextField(
                        "Tutor instructions",
                        text: $tutorInstructionsDraft,
                        axis: .vertical
                    )
                    .lineLimit(6...10)
                    .accessibilityLabel("Custom tutor instructions")
                    HStack {
                        Button("Save Instructions") {
                            model.saveTutorInstructions(tutorInstructionsDraft)
                        }
                        .disabled(tutorInstructionsDraft == model.tutorInstructions)
                        Spacer()
                        Button("Restore Default") {
                            model.restoreDefaultTutorInstructions()
                            tutorInstructionsDraft = model.tutorInstructions
                        }
                        .disabled(
                            model.tutorInstructions == RealtimeConstants.defaultTutorInstructions
                                && tutorInstructionsDraft
                                    == RealtimeConstants.defaultTutorInstructions
                        )
                    }
                    Text(
                        "Customize teaching style and depth. Screen capture, privacy, and tool "
                            + "rules remain protected. Saved locally; changes apply to new "
                            + "conversations."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
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
                HStack {
                    Text("Global shortcut")
                    Spacer()
                    GlobalHotKeyShortcutRecorder(
                        shortcut: model.hotKeyShortcut,
                        onChange: model.setHotKeyShortcut,
                        onError: model.reportHotKeyError
                    )
                    .frame(width: 160, height: 28)
                }
                HStack {
                    Text("Click the shortcut, then press a modified key combination.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Restore Default") {
                        model.restoreDefaultHotKeyShortcut()
                    }
                    .disabled(model.hotKeyShortcut == .defaultShortcut)
                }
                Toggle(
                    "Launch ScreenTutor at login",
                    isOn: Binding(
                        get: { model.launchAtLoginState.isEnabled },
                        set: { enabled in model.setLaunchAtLogin(enabled) }
                    )
                )
            }

            if let errorMessage = model.errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 620)
        .onAppear {
            model.refresh()
            tutorInstructionsDraft = model.tutorInstructions
        }
    }

}
