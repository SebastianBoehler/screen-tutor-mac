import AppKit
import Observation

@MainActor
@Observable
final class AppSettingsModel {
    private(set) var hasAPIKey = false
    private(set) var screenPermissionGranted = false
    private(set) var microphonePermissionGranted = false
    private(set) var launchAtLoginState: LaunchAtLoginState = .disabled
    private(set) var tutorLanguage: TutorLanguage
    private(set) var hotKeyShortcut: GlobalHotKeyShortcut
    private(set) var errorMessage: String?

    private let apiKeyStore: APIKeyStore
    private let captureService: ActiveWindowCaptureService
    private let launchAtLoginService: LaunchAtLoginService
    private let userDefaults: UserDefaults
    @ObservationIgnored
    private var hotKeyRegistration: ((GlobalHotKeyShortcut) throws -> Void)?

    private static let tutorLanguageKey = "com.sebastianboehler.ScreenTutor.tutorLanguage"
    private static let hotKeyShortcutKey = "com.sebastianboehler.ScreenTutor.hotKeyShortcut"

    init(
        apiKeyStore: APIKeyStore,
        captureService: ActiveWindowCaptureService,
        launchAtLoginService: LaunchAtLoginService,
        userDefaults: UserDefaults = .standard
    ) {
        self.apiKeyStore = apiKeyStore
        self.captureService = captureService
        self.launchAtLoginService = launchAtLoginService
        self.userDefaults = userDefaults
        tutorLanguage = userDefaults.string(forKey: Self.tutorLanguageKey)
            .flatMap(TutorLanguage.init(rawValue:)) ?? .automatic
        hotKeyShortcut = Self.loadHotKeyShortcut(from: userDefaults)
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

    func requestScreenPermission() {
        _ = captureService.hasPermission || captureService.requestPermission()
        screenPermissionGranted = captureService.hasPermission
        errorMessage = screenPermissionGranted
            ? nil
            : AppModelError.screenPermissionRequiresRestart.localizedDescription
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
        screenPermissionGranted = captureService.hasPermission
        microphonePermissionGranted = MicrophonePermissionService.isGranted
        launchAtLoginState = launchAtLoginService.state
    }

    func openScreenRecordingSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
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
