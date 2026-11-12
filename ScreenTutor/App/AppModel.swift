import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    var phase: SessionPhase = .idle
    var errorMessage: String?
    var assistantTranscript = ""
    var latestUserTranscript = ""
    var showsTranscriptOverlay = true
    var isMicrophoneMuted = false
    var liveToolActivities: [LiveToolActivity] = []
    var recoverableConversation: ConversationProjection?
    var capturedApplicationName: String?
    let settings: AppSettingsModel
    let history: ConversationHistoryModel

    let captureService: ActiveWindowCaptureService
    let screenTools: ScreenToolCoordinator
    let deskCamera: DeskCameraService
    let deskObserver: DeskObserver
    let desktopActions = DesktopActions()
    @ObservationIgnored var visualBoard: VisualBoardController?
    @ObservationIgnored var lastInjectedDeskObservationID: UUID?
    let realtimeClient: RealtimeClient
    let idleTimer = ListeningIdleTimer()
    var screenToolTask: Task<Void, Never>?
    var screenToolTaskID: UUID?
    var teardownTask: Task<Void, Never>?
    var teardownTaskID: UUID?
    var sessionGeneration = 0
    var realtimeConnectionID: RealtimeConnectionID?
    var turnTracker = ConversationTurnTracker()
    var activeResponseID: String?
    var activeResponseTurn: Int?
    var currentUserItemID: String?
    var currentUserItemTurn: Int?
    var pendingResponseCancels: [String: String] = [:]
    var pendingResponseCreates: [String: Int] = [:]
    var activeAudioResponseID: String?
    var userIsSpeaking = false
    var lastSnapshotWindowContext: CapturedWindowContext?
    var historyIdentity = ConversationHistoryIdentity()
    var pendingUserHistoryTurns: [String: PendingUserHistoryTurn] = [:]
    var pendingAssistantHistory: [String: PendingAssistantHistoryMessage] = [:]
    var pendingHistoryReplay: [ConversationMessage] = []
    @ObservationIgnored var showTeachingPointer: ((TeachingPointer) throws -> Void)?
    @ObservationIgnored var clearTeachingPointer: (() -> Void)?
    @ObservationIgnored var playScreenInspectionCue: @MainActor () -> Void =
        ScreenInspectionCue.play
    @ObservationIgnored private var hotKeyErrorMessage: String?

    init(
        history: ConversationHistoryModel? = nil,
        realtimeClient: RealtimeClient? = nil
    ) {
        let captureService = ActiveWindowCaptureService()
        self.captureService = captureService
        screenTools = ScreenToolCoordinator(captureService: captureService)
        self.history = history ?? ConversationHistoryModel()
        self.realtimeClient = realtimeClient ?? RealtimeClient()
        let settings = AppSettingsModel(
            apiKeyStore: APIKeyStore(),
            captureService: captureService,
            launchAtLoginService: LaunchAtLoginService()
        )
        self.settings = settings
        let deskCamera = DeskCameraService()
        self.deskCamera = deskCamera
        deskObserver = DeskObserver(camera: deskCamera, settings: settings)
        deskObserver.deliverInterjection = { [weak self] observation, jpeg in
            await self?.deliverDeskInterjection(observation, jpeg: jpeg) ?? false
        }
        deskObserver.conversationContext = { [weak self] in
            self?.observerConversationContext() ?? ""
        }
        deskObserver.onTaskChanged = { [weak self] task in
            self?.visualBoard?.setTask(task)
        }
    }

    var deskStatus: String {
        guard deskCamera.isRunning else { return "Desk camera off" }
        var parts = [deskCamera.activeDeviceName ?? "Desk camera"]
        if deskObserver.isAnalyzing {
            parts.append("looking…")
        } else if deskObserver.isWatching {
            parts.append(
                deskObserver.latest.map { "watching · last look \(DeskObservation.relative($0.capturedAt))" }
                    ?? "watching"
            )
        }
        return parts.joined(separator: " · ")
    }

    var statusDetail: String {
        if let errorMessage { return errorMessage }
        if isMicrophoneMuted, phase.hasConversation {
            return "ScreenTutor microphone muted · conversation connected"
        }
        if let capturedApplicationName, phase.hasConversation {
            return "Seeing \(capturedApplicationName)"
        }
        return phase == .idle
            ? "\(settings.hotKeyShortcut.accessibilityName) to start"
            : "Screen-aware Realtime voice"
    }

    var statusTitle: String {
        if errorMessage != nil { return "Needs attention" }
        if isMicrophoneMuted, phase.hasConversation { return "Microphone muted" }
        return phase.title
    }

    var statusSymbolName: String {
        if errorMessage != nil { return "exclamationmark.triangle.fill" }
        if isMicrophoneMuted, phase.hasConversation { return "mic.slash.fill" }
        return phase.symbolName
    }

    var ambientTranscriptPresentation: AmbientTranscriptPresentation {
        AmbientTranscriptPresentation(
            isEnabled: showsTranscriptOverlay,
            phase: phase,
            userText: latestUserTranscript,
            assistantText: assistantTranscript,
            hasToolActivity: !liveToolActivities.isEmpty
        )
    }

    var microphoneControlState: MicrophoneControlState {
        MicrophoneControlState(
            phase: phase,
            isMuted: isMicrophoneMuted,
            canReconnect: recoverableConversation != nil
        )
    }

    func toggleTranscriptOverlay() {
        showsTranscriptOverlay.toggle()
    }

    func toggleSession() {
        Task {
            switch phase {
            case .idle:
                await startSession(continuing: recoverableConversation)
            case .listening, .thinking, .speaking:
                await setMicrophoneMuted(!isMicrophoneMuted)
            case .paused:
                await setMicrophoneMuted(false)
            case .requestingPermissions, .connecting, .pausing, .resuming, .stopping:
                break
            }
        }
    }

    func startNewConversation() {
        Task {
            recoverableConversation = nil
            await teardownSession(preserving: nil)
            await startSession()
        }
    }

    func continueConversation(_ conversation: ConversationProjection) {
        guard phase == .idle else { return }
        Task {
            await startSession(continuing: conversation)
        }
    }

    func stopSession() async {
        recoverableConversation = nil
        await teardownSession(preserving: nil)
    }

    func reportHotKeyError(_ error: Error) {
        let message = error.localizedDescription
        hotKeyErrorMessage = message
        errorMessage = message
    }

    func clearHotKeyError() {
        if errorMessage == hotKeyErrorMessage { errorMessage = nil }
        hotKeyErrorMessage = nil
    }

    func configureTeachingPointer(
        show: @escaping (TeachingPointer) throws -> Void,
        clear: @escaping () -> Void
    ) {
        showTeachingPointer = show
        clearTeachingPointer = clear
    }

    func isCurrentSession(
        generation: Int,
        connectionID: RealtimeConnectionID
    ) -> Bool {
        generation == sessionGeneration && realtimeConnectionID == connectionID
    }

    func isCurrentTurn(
        _ turn: Int,
        generation: Int,
        connectionID: RealtimeConnectionID
    ) -> Bool {
        isCurrentSession(generation: generation, connectionID: connectionID)
            && turnTracker.isCurrent(turn)
    }
}
