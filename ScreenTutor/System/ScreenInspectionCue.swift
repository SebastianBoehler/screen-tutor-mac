import AppKit

enum ScreenInspectionCue {
    @MainActor
    static func play() {
        guard let sound = NSSound(named: NSSound.Name("Tink")) else { return }
        sound.volume = 0.35
        sound.play()
    }
}
