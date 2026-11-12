import SwiftUI

/// Desk window: live overhead preview, camera choice and rotation, observer
/// controls, the active task, and the observer's running notes.
struct DeskCameraView: View {
    let model: AppModel

    private var camera: DeskCameraService { model.deskCamera }
    private var observer: DeskObserver { model.deskObserver }
    private var settings: AppSettingsModel { model.settings }

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 10) {
                preview
                cameraControls
            }
            .padding(14)
            .frame(minWidth: 420)

            VStack(alignment: .leading, spacing: 12) {
                observerControls
                Divider()
                if let task = observer.activeTask { taskCard(task) }
                notesList
            }
            .padding(14)
            .frame(minWidth: 320, idealWidth: 360)
        }
        .frame(minWidth: 780, minHeight: 520)
        .onAppear { camera.refreshDevices() }
    }

    private var preview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12).fill(.black.opacity(0.85))
            if let image = camera.previewImage {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "camera.on.rectangle")
                        .font(.system(size: 34))
                    Text(camera.isStarting ? "Starting camera…" : "Camera off")
                    Text("Mount your iPhone above the desk and pick it below (Continuity Camera or Desk View).")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 280)
                }
                .foregroundStyle(.white.opacity(0.75))
            }
            if observer.isAnalyzing {
                VStack {
                    HStack {
                        Spacer()
                        Label("Observer looking", systemImage: "eye")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    Spacer()
                }
                .padding(10)
            }
        }
        .frame(minHeight: 300)
    }

    private var cameraControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Picker("Camera", selection: Binding(
                    get: { camera.selectedDeviceID ?? "" },
                    set: { camera.selectDevice($0) }
                )) {
                    if camera.devices.isEmpty { Text("No cameras found").tag("") }
                    ForEach(camera.devices) { device in
                        Text("\(device.name) · \(device.kind)").tag(device.id)
                    }
                }
                Button {
                    camera.refreshDevices()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh cameras")
            }
            HStack {
                Picker("Orientation", selection: Binding(
                    get: { camera.rotation },
                    set: { camera.setRotation($0) }
                )) {
                    ForEach(DeskRotation.allCases) { rotation in
                        Text(rotation.displayName).tag(rotation)
                    }
                }
                Spacer()
                if camera.isRunning {
                    Button("Stop camera", role: .destructive) {
                        observer.stopWatching()
                        camera.stop()
                    }
                } else {
                    Button("Start camera") { Task { await camera.start() } }
                        .disabled(camera.isStarting)
                }
            }
            if let error = camera.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.red)
            }
            Text("Frames stay on this Mac. The observer sends a frame to OpenRouter only when the page changes or you seem stuck; the voice tutor gets a frame when it calls look_at_desk.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var observerControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Desk observer").font(.headline)
                Spacer()
                if observer.isWatching {
                    Button("Stop watching") { observer.stopWatching() }
                } else {
                    Button("Watch desk") { Task { await observer.startWatching() } }
                        .buttonStyle(.borderedProminent)
                        .disabled(!settings.hasOpenRouterKey || !settings.observerEnabled)
                }
            }
            Picker("Interjections", selection: Binding(
                get: { settings.deskProactivity },
                set: { settings.setDeskProactivity($0) }
            )) {
                ForEach(DeskProactivity.allCases) { Text($0.displayName).tag($0) }
            }
            HStack {
                Text(settings.observerModel).font(.caption.monospaced()).foregroundStyle(.secondary)
                Spacer()
                Button("Look now") { Task { await observer.analyzeNow() } }
                    .disabled(!camera.isRunning || observer.isAnalyzing || !settings.hasOpenRouterKey)
                Button("Board") { model.visualBoard?.toggle() }
            }
            if !settings.hasOpenRouterKey {
                Label("Add an OpenRouter key in Settings to enable the observer.", systemImage: "key")
                    .font(.caption).foregroundStyle(.orange)
            }
            if let error = observer.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.red).lineLimit(3)
            }
        }
    }

    private func taskCard(_ task: DeskTask) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("ACTIVE TASK").font(.caption2.weight(.semibold)).foregroundStyle(.tint)
            Text(task.title).font(.subheadline.weight(.semibold))
            Text(task.prompt).font(.caption).lineLimit(4)
            HStack {
                Spacer()
                Button("Clear") { observer.finishTask(outcome: "abandoned", note: "cleared by learner") }
                    .font(.caption)
            }
        }
        .padding(10)
        .background(.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private var notesList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Observer notes").font(.subheadline.weight(.semibold))
            if observer.observations.isEmpty {
                Text("No observations yet. Start the camera and Watch desk, or press Look now.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(observer.observations.reversed()) { observation in
                        observationRow(observation)
                    }
                }
            }
        }
    }

    private func observationRow(_ observation: DeskObservation) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(observation.payload.progress.displayName).font(.caption.weight(.semibold))
                if let interjection = observation.payload.interjection {
                    Label(interjection.kind.rawValue, systemImage: "bubble.left.fill")
                        .font(.caption2).foregroundStyle(.orange)
                }
                Spacer()
                Text(observation.capturedAt, style: .time).font(.caption2).foregroundStyle(.secondary)
                Text(String(format: "%.1fs", observation.latency)).font(.caption2).foregroundStyle(.secondary)
            }
            Text(observation.payload.summary).font(.caption)
            if let issue = observation.payload.issue {
                Text("⚠︎ \(issue.location): \(issue.description)").font(.caption).foregroundStyle(.orange)
            }
            if !observation.payload.workTranscription.isEmpty {
                Text(observation.payload.workTranscription)
                    .font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(4)
                    .textSelection(.enabled)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }
}
