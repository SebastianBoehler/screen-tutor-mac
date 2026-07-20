import Foundation

enum RealtimeEventSizePolicy {
    static let maximumTextBytes = 250_000
}

enum RealtimeWebRTCAudioConstraints {
    static let optional = [
        "googEchoCancellation": "true",
        "googNoiseSuppression": "true",
        "googAutoGainControl": "true",
        "googHighpassFilter": "true"
    ]
}

@MainActor
protocol RealtimeTransporting: AnyObject {
    func connect(
        apiKey: String,
        model: RealtimeModel,
        onMessage: @escaping (String) async -> Void,
        onDisconnect: @escaping (String) async -> Void
    ) async throws
    func send(_ text: String) async throws
    func setMicrophoneMuted(_ muted: Bool) async throws
    func disconnect()
}
