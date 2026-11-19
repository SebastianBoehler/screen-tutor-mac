import SwiftUI

struct SettingsView: View {
    let model: AppSettingsModel
    let historyModel: ConversationHistoryModel
    @State private var apiKey = ""
    @State private var tutorInstructionsDraft = ""
    @State private var openRouterKey = ""
    @State private var observerModelDraft = ""
    @State private var computerModelDraft = ""
    @State private var overlayModelDraft = ""
    @State private var studyRoomURLDraft = ""

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

            Section("OpenRouter — screen, desk and computer") {
                SecureField("OpenRouter API key", text: $openRouterKey)
                    .textContentType(.password)
                HStack {
                    Button("Save in Keychain") {
                        model.saveOpenRouterKey(openRouterKey)
                        if model.hasOpenRouterKey { openRouterKey = "" }
                    }
                    .disabled(openRouterKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if let source = model.openRouterKeySource {
                        Label(source, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Spacer()
                        Button("Delete", role: .destructive) { model.deleteOpenRouterKey() }
                    }
                }
                HStack {
                    TextField("Vision model", text: $observerModelDraft)
                        .font(.body.monospaced())
                    Button("Save") { model.setObserverModel(observerModelDraft) }
                        .disabled(observerModelDraft == model.observerModel)
                    Button("Default") {
                        model.setObserverModel(AppSettingsModel.defaultObserverModel)
                        observerModelDraft = model.observerModel
                    }
                }
                Toggle(
                    "Observe the desk automatically when the page changes",
                    isOn: Binding(get: { model.observerEnabled }, set: { model.setObserverEnabled($0) })
                )
                Text(
                    "A fast vision model (default Gemini Flash Lite, routed for throughput with "
                        + "zero data retention) reads the paper under the desk camera and tells the "
                        + "voice tutor what you wrote, where an error is, or when you seem stuck."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section("Screen annotations and videos") {
                HStack {
                    TextField("Annotation model", text: $overlayModelDraft)
                        .font(.body.monospaced())
                    Button("Save") { model.setOverlayModel(overlayModelDraft) }
                        .disabled(overlayModelDraft == model.overlayModel)
                    Button("Default") {
                        model.setOverlayModel(AppSettingsModel.defaultOverlayModel)
                        overlayModelDraft = model.overlayModel
                    }
                }
                Text(
                    "The tutor can box, circle, underline, point at and spotlight things on your "
                        + "screen. Text is found on this Mac; a fast OpenRouter vision model only picks "
                        + "what to mark. Videos the tutor picks open in its own player, so it can pause, "
                        + "replay, loop and slow them down while you talk."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section("Computer control") {
                Toggle(
                    "Let the tutor control the mouse and keyboard",
                    isOn: Binding(
                        get: { model.computerControlEnabled },
                        set: { model.setComputerControlEnabled($0) }
                    )
                )
                HStack {
                    Label(
                        "Accessibility (post input events)",
                        systemImage: model.inputControlPermissionGranted
                            ? "checkmark.circle.fill"
                            : "circle.dashed"
                    )
                    .foregroundStyle(model.inputControlPermissionGranted ? .green : .secondary)
                    Spacer()
                    if !model.inputControlPermissionGranted {
                        Button("Grant Access") { model.requestInputControlPermission() }
                        Button("Open Settings") { model.openAccessibilitySettings() }
                    }
                }
                HStack {
                    TextField("Agent model", text: $computerModelDraft)
                        .font(.body.monospaced())
                    Button("Save") { model.setComputerModel(computerModelDraft) }
                        .disabled(computerModelDraft == model.computerModel)
                    Button("Default") {
                        model.setComputerModel(AppSettingsModel.defaultComputerModel)
                        computerModelDraft = model.computerModel
                    }
                }
                Text(
                    "Off by default. When on, the voice tutor can click, type, press shortcuts and "
                        + "scroll in a window it captured, and hand multi-step goals to a background "
                        + "agent that reads screenshots through OpenRouter. It acts only when you ask "
                        + "or agree, never handles passwords, payments, messages or deletions, and "
                        + "stops the moment you move the mouse."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section("Study room") {
                HStack {
                    TextField("Room URL", text: $studyRoomURLDraft)
                        .font(.body.monospaced())
                    Button("Save") { model.setStudyRoomURL(studyRoomURLDraft) }
                        .disabled(studyRoomURLDraft == model.studyRoomURL)
                }
                Text(
                    "Group mode runs in the study room server (room/ in this repository): learners join "
                        + "from a browser with their mic and desk camera, and the tutor listens, watches "
                        + "each desk, and writes on a shared board. Start it with bun run dev in room/."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section("Tutor") {
                Picker(
                    "Realtime model",
                    selection: Binding(
                        get: { model.realtimeModel },
                        set: { model.setRealtimeModel($0) }
                    )
                ) {
                    ForEach(RealtimeModel.allCases) { realtimeModel in
                        Text(realtimeModel.displayName).tag(realtimeModel)
                    }
                }
                Text(model.realtimeModel.guidance + " Changes apply to new connections.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

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
                Text(
                    "ScreenTutor mute affects only audio sent to the tutor. It is not a system-wide "
                        + "mute, so OBS and other permitted apps can record the same microphone. "
                        + "In OBS, keep a separate Audio Input Capture source enabled."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
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
                HStack {
                    Label(
                        "Camera",
                        systemImage: model.cameraPermissionGranted
                            ? "checkmark.circle.fill"
                            : "circle.dashed"
                    )
                    .foregroundStyle(model.cameraPermissionGranted ? .green : .secondary)
                    Spacer()
                    if !model.cameraPermissionGranted {
                        Button("Grant Access") { model.requestCameraPermission() }
                    }
                }
                Text(
                    "The desk camera runs only while you start it in the Desk window. Frames stay "
                        + "on this Mac until the observer (OpenRouter) or the voice tutor (OpenAI) "
                        + "needs a look at the paper."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                Button("Open Camera Settings") {
                    model.openCameraSettings()
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

            ConversationStorageSettingsView(model: historyModel)

            if let errorMessage = model.errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 580, height: 680)
        .onAppear {
            model.refresh()
            tutorInstructionsDraft = model.tutorInstructions
            observerModelDraft = model.observerModel
            computerModelDraft = model.computerModel
            overlayModelDraft = model.overlayModel
            studyRoomURLDraft = model.studyRoomURL
        }
    }

}
