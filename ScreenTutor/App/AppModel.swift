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
    var capturedApplicationName: String?
    let settings: AppSettingsModel
    let history: ConversationHistoryModel

    let captureService: ActiveWindowCaptureService
    let screenTools: ScreenToolCoordinator
    let realtimeClient = RealtimeClient()
    let audioIO = RealtimeAudioIO()
    let idleTimer = ListeningIdleTimer()
    var audioUploadTask: Task<Void, Never>?
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
    var activeAssistantItemID: String?
    var userIsSpeaking = false
    var lastSnapshotWindowContext: CapturedWindowContext?
    var historyIdentity = ConversationHistoryIdentity()
    var pendingUserHistoryTurns: [String: PendingUserHistoryTurn] = [:]
    var pendingAssistantHistory: [String: PendingAssistantHistoryMessage] = [:]
    @ObservationIgnored var showHighlight: ((TeachingHighlight) throws -> Void)?
    @ObservationIgnored var clearHighlight: (() -> Void)?
    @ObservationIgnored private var hotKeyErrorMessage: String?

    init(history: ConversationHistoryModel? = nil) {
        let captureService = ActiveWindowCaptureService()
        self.captureService = captureService
        screenTools = ScreenToolCoordinator(captureService: captureService)
        self.history = history ?? ConversationHistoryModel()
        settings = AppSettingsModel(
            apiKeyStore: APIKeyStore(),
            captureService: captureService,
            launchAtLoginService: LaunchAtLoginService()
        )
    }

    var statusDetail: String {
        if let errorMessage { return errorMessage }
        if phase == .paused { return "Conversation retained · microphone off" }
        if let capturedApplicationName, phase.hasConversation {
            return "Seeing \(capturedApplicationName)"
        }
        return phase == .idle
            ? "\(settings.hotKeyShortcut.accessibilityName) to start"
            : "Screen-aware Realtime voice"
    }

    var ambientTranscriptPresentation: AmbientTranscriptPresentation {
        AmbientTranscriptPresentation(
            isEnabled: showsTranscriptOverlay,
            phase: phase,
            userText: latestUserTranscript,
            assistantText: assistantTranscript
        )
    }

    func toggleTranscriptOverlay() {
        showsTranscriptOverlay.toggle()
    }

    func toggleSession() {
        Task {
            switch phase {
            case .idle:
                await startSession()
            case .paused:
                await resumeListening()
            case .listening, .thinking, .speaking:
                await pauseListening()
            case .requestingPermissions, .connecting, .pausing, .resuming, .stopping:
                break
            }
        }
    }

    func startNewConversation() {
        Task {
            await teardownSession(preserving: nil)
            await startSession()
        }
    }

    func stopSession() async {
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
        show: @escaping (TeachingHighlight) throws -> Void,
        clear: @escaping () -> Void
    ) {
        showHighlight = show
        clearHighlight = clear
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
