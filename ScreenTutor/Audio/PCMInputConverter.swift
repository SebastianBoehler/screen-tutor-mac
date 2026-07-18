import AVFAudio
import Foundation

final class PCMInputConverter: @unchecked Sendable {
    private let converter: AVAudioConverter
    private let outputFormat: AVAudioFormat

    init(inputFormat: AVAudioFormat, outputFormat: AVAudioFormat) throws {
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw AudioIOError.converterCreationFailed
        }
        self.converter = converter
        self.outputFormat = outputFormat
    }

    func convert(_ input: AVAudioPCMBuffer) throws -> Data {
        let ratio = outputFormat.sampleRate / input.format.sampleRate
        let capacity = AVAudioFrameCount(ceil(Double(input.frameLength) * ratio)) + 64
        guard let output = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: capacity
        ) else {
            throw AudioIOError.converterCreationFailed
        }

        var conversionError: NSError?
        // AVAudioConverter invokes this block synchronously and nonconcurrently.
        nonisolated(unsafe) let synchronousInput = input
        nonisolated(unsafe) var suppliedInput = false
        let status = converter.convert(to: output, error: &conversionError) { _, inputStatus in
            guard !suppliedInput else {
                inputStatus.pointee = .noDataNow
                return nil
            }
            suppliedInput = true
            inputStatus.pointee = .haveData
            return synchronousInput
        }

        if status == .error {
            throw AudioIOError.conversionFailed(
                conversionError?.localizedDescription ?? "Unknown conversion error"
            )
        }
        guard output.frameLength > 0 else { return Data() }
        let audioBuffer = output.audioBufferList.pointee.mBuffers
        guard let bytes = audioBuffer.mData else {
            throw AudioIOError.conversionFailed("The converter returned no audio bytes.")
        }
        let byteCount = Int(output.frameLength) * MemoryLayout<Int16>.size
        return Data(bytes: bytes, count: byteCount)
    }
}
