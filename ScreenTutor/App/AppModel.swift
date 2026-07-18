import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    var phase: SessionPhase = .idle
    var errorMessage: String?
    var assistantTranscript = ""
    var capturedApplicationName: String?
    let settings: AppSettingsModel

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
    var lastSnapshotWindowFrame: CGRect?
    @ObservationIgnored var showHighlight: ((TeachingHighlight) -> Void)?
    @ObservationIgnored var clearHighlight: (() -> Void)?

    init() {
        let captureService = ActiveWindowCaptureService()
        self.captureService = captureService
        screenTools = ScreenToolCoordinator(captureService: captureService)
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
            ? "Command-Shift-Space to start"
            : "Screen-aware Realtime voice"
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
        errorMessage = error.localizedDescription
    }

    func configureTeachingPointer(
        show: @escaping (TeachingHighlight) -> Void,
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
