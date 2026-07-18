import ServiceManagement

@MainActor
final class LaunchAtLoginService {
    var state: LaunchAtLoginState {
        switch SMAppService.mainApp.status {
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        case .notRegistered: .disabled
        case .notFound: .unavailable
        @unknown default: .unavailable
        }
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}

enum LaunchAtLoginState: Sendable {
    case enabled
    case requiresApproval
    case disabled
    case unavailable

    var isEnabled: Bool { self == .enabled }
}
