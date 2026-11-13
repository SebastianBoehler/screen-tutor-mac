import CoreGraphics
import Foundation
import Observation

/// Watches the desk camera locally and asks a fast OpenRouter vision model
/// (Gemini Flash Lite by default) for a structured look whenever the page
/// materially changes, or when an active task shows no progress for a while.
/// When the observer recommends stepping in, the app model decides whether the
/// voice tutor may speak now.
@MainActor
@Observable
final class DeskObserver {
    private(set) var isWatching = false
    private(set) var isAnalyzing = false
    private(set) var observations: [DeskObservation] = []
    private(set) var activeTask: DeskTask?
    private(set) var lastError: String?
    private(set) var lastInterjectionAt: Date?
    private(set) var completedTasks: [String] = []

    var latest: DeskObservation? { observations.last }

    @ObservationIgnored private let camera: DeskCameraService
    @ObservationIgnored private let settings: AppSettingsModel
    @ObservationIgnored private let client: OpenRouterClient
    @ObservationIgnored private var gate = DeskChangeGate()
    @ObservationIgnored private var loopTask: Task<Void, Never>?
    @ObservationIgnored private var pendingInterjection: (DeskObservation, Data, Date)?

    /// Returns true when the interjection was handed to the voice tutor.
    @ObservationIgnored var deliverInterjection:
        (@MainActor (DeskObservation, Data) async -> Bool)?
    /// Short text of the latest spoken exchange, used only as observer context.
    @ObservationIgnored var conversationContext: (@MainActor () -> String)?
    @ObservationIgnored var onTaskChanged: (@MainActor (DeskTask?) -> Void)?

    init(camera: DeskCameraService, settings: AppSettingsModel, client: OpenRouterClient = OpenRouterClient()) {
        self.camera = camera
        self.settings = settings
        self.client = client
    }

    func startWatching() async {
        guard !isWatching else { return }
        if !camera.isRunning { await camera.start() }
        guard camera.isRunning else {
            lastError = camera.errorMessage
            return
        }
        lastError = nil
        gate.reset()
        isWatching = true
        loopTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                await self?.tick()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func stopWatching() {
        loopTask?.cancel()
        loopTask = nil
        isWatching = false
        pendingInterjection = nil
    }

    func assignTask(
        title: String,
        prompt: String,
        expectedEvidence: String,
        kind: TaskKind = .practice,
        topic: String? = nil,
        subskill: String? = nil
    ) -> DeskTask {
        let task = DeskTask(
            id: UUID(),
            title: title,
            prompt: prompt,
            expectedEvidence: expectedEvidence,
            assignedAt: Date(),
            kind: kind,
            topic: topic,
            subskill: subskill
        )
        activeTask = task
        gate.reset()
        onTaskChanged?(task)
        return task
    }

    @discardableResult
    func finishTask(outcome: String, note: String) -> DeskTask? {
        let finished = activeTask
        if let activeTask {
            completedTasks.append("\(activeTask.title): \(outcome)\(note.isEmpty ? "" : " — \(note)")")
        }
        activeTask = nil
        pendingInterjection = nil
        onTaskChanged?(nil)
        return finished
    }

    /// Analyses the current frame immediately (used by "Analyze now" and the tutor's tools).
    @discardableResult
    func analyzeNow() async -> DeskObservation? {
        guard let frame = camera.latestFrame() else {
            lastError = "The desk camera has no frame yet."
            return nil
        }
        return await analyze(frame.image, at: frame.capturedAt, reason: .requested)
    }

    func recentNotes(limit: Int = 6) -> String {
        let notes = observations.suffix(limit).map(\.tutorNote)
        var text = notes.isEmpty ? "No desk observations yet." : notes.joined(separator: "\n---\n")
        if let activeTask {
            text += "\n\nActive task: \(activeTask.title) — \(activeTask.prompt)"
        }
        if !completedTasks.isEmpty {
            text += "\n\nFinished tasks this session: " + completedTasks.suffix(5).joined(separator: "; ")
        }
        return text
    }

    private func tick() async {
        guard isWatching, camera.isRunning else { return }
        if let pending = pendingInterjection {
            if Date().timeIntervalSince(pending.2) > 30 {
                pendingInterjection = nil
            } else if await deliverInterjection?(pending.0, pending.1) == true {
                pendingInterjection = nil
                lastInterjectionAt = Date()
            }
        }
        guard
            !isAnalyzing,
            settings.observerEnabled,
            let frame = camera.latestFrame(),
            let fingerprint = DeskFrameFingerprint(image: frame.image)
        else { return }
        let decision = gate.evaluate(fingerprint, at: Date(), hasActiveTask: activeTask != nil)
        guard case .analyze(let reason) = decision else { return }
        await analyze(frame.image, at: frame.capturedAt, reason: reason)
    }

    @discardableResult
    private func analyze(
        _ image: CGImage,
        at capturedAt: Date,
        reason: DeskAnalysisReason
    ) async -> DeskObservation? {
        guard !isAnalyzing else { return latest }
        guard let apiKey = settings.loadOpenRouterKey() else {
            lastError = OpenRouterError.missingKey.localizedDescription
            return nil
        }
        guard let jpeg = camera.jpegData(for: image) else {
            lastError = "The desk frame could not be encoded."
            return nil
        }
        if let fingerprint = DeskFrameFingerprint(image: image) {
            gate.recordAnalysis(of: fingerprint, at: Date())
        }
        isAnalyzing = true
        defer { isAnalyzing = false }
        let secondsSinceChange = gate.lastMaterialChange.map { Int(Date().timeIntervalSince($0)) }
        do {
            let completion = try await client.complete(
                apiKey: apiKey,
                model: settings.observerModel,
                system: DeskObserverPrompt.system,
                userText: DeskObserverPrompt.userText(
                    reason: reason,
                    task: activeTask,
                    previous: latest,
                    conversation: conversationContext?() ?? "",
                    secondsSinceLastChange: secondsSinceChange
                ),
                jpegData: jpeg
            )
            let observation = DeskObservation(
                capturedAt: capturedAt,
                reason: reason,
                payload: try DeskObservationPayload.parse(completion.text),
                model: completion.model,
                latency: completion.latency
            )
            observations.append(observation)
            if observations.count > 40 { observations.removeFirst(observations.count - 40) }
            lastError = nil
            if reason != .requested { considerInterjection(observation, jpeg: jpeg) }
            return observation
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    private func considerInterjection(_ observation: DeskObservation, jpeg: Data) {
        guard let interjection = observation.payload.interjection else { return }
        let proactivity = settings.deskProactivity
        guard proactivity.allows(interjection.kind) else { return }
        // Stalls and finished work only make sense against an assigned task.
        if [.stalled, .completed, .offTrack].contains(interjection.kind), activeTask == nil { return }
        if let lastInterjectionAt, Date().timeIntervalSince(lastInterjectionAt) < proactivity.cooldown {
            return
        }
        pendingInterjection = (observation, jpeg, Date())
    }
}
