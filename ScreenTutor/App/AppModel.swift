import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    private(set) var phase: SessionPhase = .idle
    private(set) var errorMessage: String?
    private(set) var assistantTranscript = ""
    private(set) var capturedApplicationName: String?
    let settings: AppSettingsModel

    private let captureService: ActiveWindowCaptureService
    private let applicationTracker = ActiveApplicationTracker()
    private let realtimeClient = RealtimeClient()
    private let audioIO = RealtimeAudioIO()
    private var audioUploadTask: Task<Void, Never>?
    private var snapshotTask: Task<ActiveWindowSnapshot, any Error>?
    private var activeResponseID: String?
    private var activeAssistantItemID: String?
    private var userIsSpeaking = false
    private var lastSnapshotWindowFrame: CGRect?
    @ObservationIgnored private var showHighlight: ((TeachingHighlight) -> Void)?
    @ObservationIgnored private var clearHighlight: (() -> Void)?

    init() {
        let captureService = ActiveWindowCaptureService()
        self.captureService = captureService
        settings = AppSettingsModel(
            apiKeyStore: APIKeyStore(),
            captureService: captureService,
            launchAtLoginService: LaunchAtLoginService()
        )
    }

    var statusDetail: String {
        if let errorMessage { return errorMessage }
        if let capturedApplicationName, phase.isActive {
            return "Seeing \(capturedApplicationName)"
        }
        return phase == .idle
            ? "Command-Shift-Space to start"
            : "Screen-aware Realtime voice"
    }

    func toggleSession() {
        Task {
            if phase.isActive || phase == .stopping {
                await stopSession()
            } else {
                await startSession()
            }
        }
    }

    func startSession() async {
        guard phase == .idle else { return }
        errorMessage = nil
        assistantTranscript = ""
        phase = .requestingPermissions

        do {
            guard let apiKey = try settings.loadAPIKey() else {
                throw AppModelError.missingAPIKey
            }
            guard await MicrophonePermissionService.request() else {
                throw AudioIOError.microphonePermissionDenied
            }
            settings.refresh()
            guard captureService.hasPermission || captureService.requestPermission() else {
                throw ScreenCaptureError.permissionDenied
            }
            settings.refresh()
            guard settings.screenPermissionGranted else {
                throw AppModelError.screenPermissionRequiresRestart
            }
            guard applicationTracker.processIdentifier != nil else {
                throw AppModelError.noExternalApplication
            }

            phase = .connecting
            try await realtimeClient.connect(
                apiKey: apiKey,
                onEvent: { [weak self] event in
                    await self?.handle(event)
                },
                onDisconnect: { [weak self] message in
                    await self?.handleDisconnect(message)
                }
            )
        } catch {
            await stopSession(preserving: error.localizedDescription)
        }
    }

    func stopSession() async {
        await stopSession(preserving: nil)
    }

    func reportHotKeyError(_ error: Error) {
        errorMessage = error.localizedDescription
    }

    func configureTeachingPointer(
        show: @escaping (TeachingHighlight) -> Void,
        clear: @escaping () -> Void
    ) {
        showHighlight = show
        clearHighlight = clear
    }

    private func handle(_ event: RealtimeServerEvent) async {
        do {
            switch event.type {
            case "session.created":
                try await realtimeClient.send(RealtimeSessionUpdateEvent.screenTutor)
            case "session.updated":
                try await startAudioStreaming()
                phase = .listening
            case "input_audio_buffer.speech_started":
                await speechStarted()
            case "input_audio_buffer.speech_stopped":
                userIsSpeaking = false
            case "input_audio_buffer.committed":
                try await committedUserTurn()
            case "response.created":
                activeResponseID = event.response?.id
                assistantTranscript = ""
            case "response.output_audio.delta":
                try await receiveAudioDelta(event)
            case "response.output_audio.done":
                if belongsToActiveResponse(event), let itemID = event.itemID {
                    try await audioIO.finishAssistantAudio(itemID: itemID)
                }
            case "response.output_audio_transcript.delta":
                if belongsToActiveResponse(event) {
                    assistantTranscript += event.delta ?? ""
                }
            case "response.output_audio_transcript.done":
                if belongsToActiveResponse(event), let transcript = event.transcript {
                    assistantTranscript = transcript
                }
            case "response.done":
                try await handleResponseDone(event.response)
            case "error":
                errorMessage = event.error?.message ?? "The Realtime API returned an error."
            default:
                break
            }
        } catch {
            await stopSession(preserving: error.localizedDescription)
        }
    }

    private func startAudioStreaming() async throws {
        let stream = try await audioIO.start { [weak self] itemID in
            await self?.playbackDrained(itemID: itemID)
        }
        audioUploadTask = Task { [weak self] in
            do {
                for try await pcmData in stream {
                    guard let self else { return }
                    try await self.realtimeClient.send(InputAudioAppendEvent(pcmData: pcmData))
                }
            } catch {
                await self?.handleAudioFailure(error)
            }
        }
    }

    private func speechStarted() async {
        userIsSpeaking = true
        phase = .listening
        if let cutoff = await audioIO.interruptAssistantAudio() {
            try? await realtimeClient.send(
                ConversationTruncateEvent(
                    itemID: cutoff.itemID,
                    audioEndMilliseconds: cutoff.audioEndMilliseconds
                )
            )
        }
        activeResponseID = nil
        activeAssistantItemID = nil
        clearHighlight?()
        guard let processID = applicationTracker.processIdentifier else {
            errorMessage = AppModelError.noExternalApplication.localizedDescription
            return
        }
        let applicationName = applicationTracker.applicationName
        snapshotTask?.cancel()
        snapshotTask = Task {
            try await captureService.capture(
                processID: processID,
                applicationName: applicationName
            )
        }
    }

    private func committedUserTurn() async throws {
        phase = .thinking
        guard let snapshotTask else { throw AppModelError.missingSnapshot }
        let snapshot = try await snapshotTask.value
        self.snapshotTask = nil
        capturedApplicationName = snapshot.applicationName
        lastSnapshotWindowFrame = snapshot.windowFrame
        try await realtimeClient.send(ConversationImageEvent(jpegData: snapshot.jpegData))
        try await realtimeClient.send(ResponseCreateEvent())
    }

    private func receiveAudioDelta(_ event: RealtimeServerEvent) async throws {
        guard
            belongsToActiveResponse(event),
            let delta = event.delta,
            let data = Data(base64Encoded: delta),
            let itemID = event.itemID
        else { throw AudioIOError.malformedOutputPCM }
        activeAssistantItemID = itemID
        try await audioIO.enqueueAssistantPCM16(data, itemID: itemID)
        phase = .speaking
    }

    private func handleResponseDone(_ response: RealtimeResponse?) async throws {
        guard let status = response?.status else { return }
        guard
            response?.id == activeResponseID
                || (activeResponseID == nil && status != "cancelled")
        else { return }
        activeResponseID = nil
        if status == "failed" || status == "incomplete" {
            throw AppModelError.responseFailed(status)
        }
        if let functionCall = response?.output?.first(where: { $0.type == "function_call" }) {
            try await handleFunctionCall(functionCall)
            return
        }
        if status == "cancelled", !userIsSpeaking, phase != .thinking {
            phase = .listening
        }
    }

    private func belongsToActiveResponse(_ event: RealtimeServerEvent) -> Bool {
        guard let activeResponseID else { return false }
        return event.responseID == nil || event.responseID == activeResponseID
    }

    private func handleFunctionCall(_ item: RealtimeItem) async throws {
        guard
            item.name == "highlight_screen_region",
            let arguments = item.arguments,
            let callID = item.callID
        else { throw TeachingHighlightError.invalidArguments }
        guard let lastSnapshotWindowFrame else {
            throw TeachingHighlightError.noWindowContext
        }

        let highlight = try TeachingHighlight(
            argumentsJSON: arguments,
            windowFrame: lastSnapshotWindowFrame
        )
        showHighlight?(highlight)
        phase = .thinking
        try await realtimeClient.send(FunctionCallOutputEvent(callID: callID))
        try await realtimeClient.send(ResponseCreateEvent())
    }

    private func playbackDrained(itemID: String) {
        guard activeAssistantItemID == itemID else { return }
        activeAssistantItemID = nil
        if !userIsSpeaking && phase == .speaking { phase = .listening }
    }

    private func handleAudioFailure(_ error: Error) async {
        await stopSession(preserving: error.localizedDescription)
    }

    private func handleDisconnect(_ message: String) async {
        await stopSession(preserving: message)
    }

    private func stopSession(preserving message: String?) async {
        if phase != .idle { phase = .stopping }
        audioUploadTask?.cancel()
        audioUploadTask = nil
        snapshotTask?.cancel()
        snapshotTask = nil
        await audioIO.stop()
        await realtimeClient.disconnect()
        activeResponseID = nil
        activeAssistantItemID = nil
        userIsSpeaking = false
        lastSnapshotWindowFrame = nil
        clearHighlight?()
        phase = .idle
        errorMessage = message
        settings.refresh()
    }
}
