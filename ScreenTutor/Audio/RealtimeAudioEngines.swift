import AVFAudio

struct RealtimeAudioEngines {
    let input: AVAudioEngine
    let output: AVAudioEngine

    init(
        input: AVAudioEngine = AVAudioEngine(),
        output: AVAudioEngine = AVAudioEngine()
    ) {
        precondition(input !== output)
        self.input = input
        self.output = output
    }
}
