import AVFAudio

@MainActor
enum MicrophonePermissionService {
    static var isGranted: Bool {
        AVAudioApplication.shared.recordPermission == .granted
    }

    static func request() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
