import AppKit
import Observation

@MainActor
@Observable
final class AppSettingsModel {
    private(set) var hasAPIKey = false
    private(set) var screenPermissionGranted = false
    private(set) var microphonePermissionGranted = false
    private(set) var cameraPermissionGranted = false
    private(set) var launchAtLoginState: LaunchAtLoginState = .disabled
    private(set) var tutorLanguage: TutorLanguage
    private(set) var tutorInstructions: String
    private(set) var realtimeModel: RealtimeModel
    private(set) var reasoningEffort: ReasoningEffort
    private(set) var hotKeyShortcut: GlobalHotKeyShortcut
    private(set) var errorMessage: String?
    private(set) var hasOpenRouterKey = false
    private(set) var observerModel: String
    private(set) var observerEnabled: Bool
    private(set) var deskProactivity: DeskProactivity
    private(set) var computerControlEnabled: Bool
    private(set) var computerModel: String
    private(set) var inputControlPermissionGranted = false

    static let defaultObserverModel = "google/gemini-3.5-flash-lite"
    static let defaultComputerModel = "google/gemini-3.5-flash"

    private let apiKeyStore: APIKeyStore
    private let openRouterKeyStore: APIKeyStore
    private let captureService: ActiveWindowCaptureService
    private let launchAtLoginService: LaunchAtLoginService
    private let userDefaults: UserDefaults
    @ObservationIgnored
    private var hotKeyRegistration: ((GlobalHotKeyShortcut) throws -> Void)?

    private static let tutorLanguageKey = "com.sebastianboehler.ScreenTutor.tutorLanguage"
    private static let tutorInstructionsKey =
        "com.sebastianboehler.ScreenTutor.tutorInstructions"
    private static let realtimeModelKey = "com.sebastianboehler.ScreenTutor.realtimeModel"
    private static let reasoningEffortKey = "com.sebastianboehler.ScreenTutor.reasoningEffort"
    private static let hotKeyShortcutKey = "com.sebastianboehler.ScreenTutor.hotKeyShortcut"
    private static let observerModelKey = "com.sebastianboehler.ScreenTutor.observerModel"
    private static let observerEnabledKey = "com.sebastianboehler.ScreenTutor.observerEnabled"
    private static let deskProactivityKey = "com.sebastianboehler.ScreenTutor.deskProactivity"
    private static let computerControlKey = "com.sebastianboehler.ScreenTutor.computerControl"
    private static let computerModelKey = "com.sebastianboehler.ScreenTutor.computerModel"

    init(
        apiKeyStore: APIKeyStore,
        captureService: ActiveWindowCaptureService,
        launchAtLoginService: LaunchAtLoginService,
        openRouterKeyStore: APIKeyStore = .openRouter(),
        userDefaults: UserDefaults = .standard
    ) {
        self.apiKeyStore = apiKeyStore
        self.openRouterKeyStore = openRouterKeyStore
        self.captureService = captureService
        self.launchAtLoginService = launchAtLoginService
        self.userDefaults = userDefaults
        tutorLanguage = userDefaults.string(forKey: Self.tutorLanguageKey)
            .flatMap(TutorLanguage.init(rawValue:)) ?? .automatic
        tutorInstructions = userDefaults.object(forKey: Self.tutorInstructionsKey) as? String
            ?? RealtimeConstants.defaultTutorInstructions
        realtimeModel = userDefaults.string(forKey: Self.realtimeModelKey)
            .flatMap(RealtimeModel.init(rawValue:)) ?? .flagship
        reasoningEffort = userDefaults.string(forKey: Self.reasoningEffortKey)
            .flatMap(ReasoningEffort.init(rawValue:)) ?? .low
        hotKeyShortcut = Self.loadHotKeyShortcut(from: userDefaults)
        observerModel = userDefaults.string(forKey: Self.observerModelKey)
            ?? Self.defaultObserverModel
        observerEnabled = userDefaults.object(forKey: Self.observerEnabledKey) as? Bool ?? true
        deskProactivity = userDefaults.string(forKey: Self.deskProactivityKey)
            .flatMap(DeskProactivity.init(rawValue:)) ?? .gentle
        computerControlEnabled = userDefaults.bool(forKey: Self.computerControlKey)
        computerModel = userDefaults.string(forKey: Self.computerModelKey)
            ?? Self.defaultComputerModel
        refresh()
    }

    func loadAPIKey() throws -> String? {
        try apiKeyStore.load()
    }

    func saveAPIKey(_ apiKey: String) {
        do {
            try apiKeyStore.save(apiKey)
            hasAPIKey = true
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteAPIKey() {
        do {
            try apiKeyStore.delete()
            hasAPIKey = false
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Keychain first; falls back to OPENROUTER_API_KEY when launched from a shell or Xcode.
    func loadOpenRouterKey() -> String? {
        if let key = try? openRouterKeyStore.load() { return key }
        let environmentKey = ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return environmentKey?.isEmpty == false ? environmentKey : nil
    }

    var openRouterKeySource: String? {
        if openRouterKeyStore.hasAPIKey { return "Keychain" }
        return loadOpenRouterKey() == nil ? nil : "OPENROUTER_API_KEY environment"
    }

    func saveOpenRouterKey(_ apiKey: String) {
        do {
            try openRouterKeyStore.save(apiKey)
            hasOpenRouterKey = true
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteOpenRouterKey() {
        do {
            try openRouterKeyStore.delete()
            hasOpenRouterKey = loadOpenRouterKey() != nil
        inputControlPermissionGranted = CGPreflightPostEventAccess()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setObserverModel(_ model: String) {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        observerModel = trimmed.isEmpty ? Self.defaultObserverModel : trimmed
        userDefaults.set(observerModel, forKey: Self.observerModelKey)
    }

    func setObserverEnabled(_ enabled: Bool) {
        observerEnabled = enabled
        userDefaults.set(enabled, forKey: Self.observerEnabledKey)
    }

    func setDeskProactivity(_ proactivity: DeskProactivity) {
        deskProactivity = proactivity
        userDefaults.set(proactivity.rawValue, forKey: Self.deskProactivityKey)
    }

    func setComputerControlEnabled(_ enabled: Bool) {
        computerControlEnabled = enabled
        userDefaults.set(enabled, forKey: Self.computerControlKey)
        if enabled, !CGPreflightPostEventAccess() { requestInputControlPermission() }
    }

    func setComputerModel(_ model: String) {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        computerModel = trimmed.isEmpty ? Self.defaultComputerModel : trimmed
        userDefaults.set(computerModel, forKey: Self.computerModelKey)
    }

    func requestInputControlPermission() {
        inputControlPermissionGranted = CGRequestPostEventAccess()
        if !inputControlPermissionGranted {
            errorMessage = "Allow ScreenTutor in Privacy & Security > Accessibility, then return here."
        }
    }

    func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    func requestScreenPermission() {
        _ = captureService.hasPermission || captureService.requestPermission()
        screenPermissionGranted = captureService.hasPermission
        errorMessage = screenPermissionGranted
            ? nil
            : AppModelError.screenPermissionRequiresRestart.localizedDescription
    }

    func requestCameraPermission() {
        Task {
            cameraPermissionGranted = await CameraPermissionService.request()
            errorMessage = cameraPermissionGranted
                ? nil
                : "Camera access is disabled. Enable ScreenTutor in Privacy & Security > Camera."
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try launchAtLoginService.setEnabled(enabled)
            launchAtLoginState = launchAtLoginService.state
            errorMessage = launchAtLoginState == .requiresApproval
                ? "Approve ScreenTutor in System Settings > General > Login Items."
                : nil
        } catch {
            errorMessage = error.localizedDescription
            launchAtLoginState = launchAtLoginService.state
        }
    }

    func setTutorLanguage(_ language: TutorLanguage) {
        tutorLanguage = language
        userDefaults.set(language.rawValue, forKey: Self.tutorLanguageKey)
    }

    func saveTutorInstructions(_ instructions: String) {
        tutorInstructions = instructions
        userDefaults.set(instructions, forKey: Self.tutorInstructionsKey)
    }

    func restoreDefaultTutorInstructions() {
        userDefaults.removeObject(forKey: Self.tutorInstructionsKey)
        tutorInstructions = RealtimeConstants.defaultTutorInstructions
    }

    func setReasoningEffort(_ effort: ReasoningEffort) {
        reasoningEffort = effort
        userDefaults.set(effort.rawValue, forKey: Self.reasoningEffortKey)
    }

    func setRealtimeModel(_ model: RealtimeModel) {
        realtimeModel = model
        userDefaults.set(model.rawValue, forKey: Self.realtimeModelKey)
    }

    func configureHotKeyRegistration(
        _ registration: @escaping (GlobalHotKeyShortcut) throws -> Void
    ) {
        hotKeyRegistration = registration
    }

    @discardableResult
    func setHotKeyShortcut(_ shortcut: GlobalHotKeyShortcut) -> Bool {
        do {
            let data = try JSONEncoder().encode(shortcut)
            try hotKeyRegistration?(shortcut)
            userDefaults.set(data, forKey: Self.hotKeyShortcutKey)
            hotKeyShortcut = shortcut
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func restoreDefaultHotKeyShortcut() {
        setHotKeyShortcut(.defaultShortcut)
    }

    func reportHotKeyError(_ error: Error) {
        errorMessage = error.localizedDescription
    }

    func refresh() {
        hasAPIKey = apiKeyStore.hasAPIKey
        hasOpenRouterKey = loadOpenRouterKey() != nil
        inputControlPermissionGranted = CGPreflightPostEventAccess()
        screenPermissionGranted = captureService.hasPermission
        microphonePermissionGranted = MicrophonePermissionService.isGranted
        cameraPermissionGranted = CameraPermissionService.isGranted
        launchAtLoginState = launchAtLoginService.state
    }

    func openScreenRecordingSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    func openCameraSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    private static func loadHotKeyShortcut(from userDefaults: UserDefaults) -> GlobalHotKeyShortcut {
        guard
            let data = userDefaults.data(forKey: hotKeyShortcutKey),
            let shortcut = try? JSONDecoder().decode(GlobalHotKeyShortcut.self, from: data)
        else { return .defaultShortcut }
        return shortcut
    }
}
