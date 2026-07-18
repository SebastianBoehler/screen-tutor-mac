import AVFAudio
import Foundation

actor RealtimeAudioIO {
    typealias PlaybackHandler = @Sendable (String) async -> Void

    private var engine: AVAudioEngine?
    private var ownerID: RealtimeConnectionID?
    private var player: AVAudioPlayerNode?
    private var networkFormat: AVAudioFormat?
    private var inputContinuation: AsyncThrowingStream<Data, any Error>.Continuation?
    private var configurationObserver: NSObjectProtocol?
    private var playbackHandler: PlaybackHandler?
    private var accumulator = PCM16Accumulator()
    private var currentItemID: String?
    private var currentItemStartFrame: AVAudioFramePosition = 0
    private var scheduledFrames: AVAudioFramePosition = 0
    private var playbackOriginFrame: AVAudioFramePosition?
    private var drainMarkerID: UUID?

    func start(
        ownerID: RealtimeConnectionID,
        onPlaybackDrained: @escaping PlaybackHandler
    ) throws
        -> AsyncThrowingStream<Data, any Error> {
        guard engine == nil else { throw AudioIOError.alreadyRunning }
        guard
            let networkFormat = AVAudioFormat(
                commonFormat: .pcmFormatInt16,
                sampleRate: RealtimeConstants.sampleRate,
                channels: 1,
                interleaved: true
            ),
            let voiceProcessingFormat = AVAudioFormat(
                standardFormatWithSampleRate: RealtimeConstants.sampleRate,
                channels: 1
            )
        else {
            throw AudioIOError.invalidInputFormat
        }

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let inputNode = engine.inputNode
        do {
            try inputNode.setVoiceProcessingEnabled(true)
        } catch {
            throw AudioIOError.voiceProcessingUnavailable(error.localizedDescription)
        }

        let inputDeviceFormat = inputNode.outputFormat(forBus: 0)
        guard inputDeviceFormat.sampleRate > 0, inputDeviceFormat.channelCount > 0 else {
            throw AudioIOError.noInputDevice
        }
        let converter = try PCMInputConverter(
            inputFormat: voiceProcessingFormat,
            outputFormat: networkFormat
        )
        let pair = AsyncThrowingStream<Data, any Error>.makeStream(
            bufferingPolicy: .bufferingNewest(20)
        )
        let continuation = pair.continuation
        let bufferSize = AVAudioFrameCount(voiceProcessingFormat.sampleRate * 0.1)
        inputNode.installTap(
            onBus: 0,
            bufferSize: bufferSize,
            format: voiceProcessingFormat
        ) { buffer, _ in
            do {
                let data = try converter.convert(buffer)
                guard !data.isEmpty else { return }
                switch continuation.yield(data) {
                case .enqueued:
                    break
                case .dropped:
                    continuation.finish(throwing: AudioIOError.inputBackpressure)
                case .terminated:
                    break
                @unknown default:
                    continuation.finish(throwing: AudioIOError.inputBackpressure)
                }
            } catch {
                continuation.finish(throwing: error)
            }
        }

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: networkFormat)
        engine.connect(
            engine.mainMixerNode,
            to: engine.outputNode,
            format: voiceProcessingFormat
        )
        engine.prepare()
        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            throw AudioIOError.engineStartFailed(error.localizedDescription)
        }

        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: nil
        ) { _ in
            continuation.finish(throwing: AudioIOError.deviceConfigurationChanged)
        }
        self.engine = engine
        self.ownerID = ownerID
        self.player = player
        self.networkFormat = networkFormat
        inputContinuation = continuation
        playbackHandler = onPlaybackDrained
        return pair.stream
    }

    func enqueueAssistantPCM16(
        _ data: Data,
        itemID: String,
        ownerID: RealtimeConnectionID
    ) throws {
        guard
            self.ownerID == ownerID,
            let player,
            let networkFormat
        else { throw RealtimeClientError.notConnected }
        let alignedData = accumulator.append(data)
        guard !alignedData.isEmpty else { return }

        let frameCount = AVAudioFrameCount(alignedData.count / MemoryLayout<Int16>.size)
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: networkFormat,
            frameCapacity: frameCount
        ) else {
            throw AudioIOError.malformedOutputPCM
        }
        buffer.frameLength = frameCount
        let audioBuffer = buffer.mutableAudioBufferList.pointee.mBuffers
        guard let destination = audioBuffer.mData else {
            throw AudioIOError.malformedOutputPCM
        }
        alignedData.copyBytes(
            to: destination.assumingMemoryBound(to: UInt8.self),
            count: alignedData.count
        )

        if currentItemID != itemID {
            currentItemID = itemID
            currentItemStartFrame = scheduledFrames
        }
        player.scheduleBuffer(buffer)
        scheduledFrames += AVAudioFramePosition(frameCount)
        if !player.isPlaying {
            player.play()
            playbackOriginFrame = currentPlayerFrame() ?? 0
        }
    }

    func finishAssistantAudio(itemID: String, ownerID: RealtimeConnectionID) throws {
        guard self.ownerID == ownerID else { return }
        try accumulator.finish()
        guard currentItemID == itemID, let player, let networkFormat else { return }

        let markerID = UUID()
        drainMarkerID = markerID
        guard let marker = AVAudioPCMBuffer(pcmFormat: networkFormat, frameCapacity: 1) else {
            throw AudioIOError.malformedOutputPCM
        }
        marker.frameLength = 1
        marker.mutableAudioBufferList.pointee.mBuffers.mData?
            .assumingMemoryBound(to: Int16.self).pointee = 0
        scheduledFrames += 1
        let drainTarget = self
        player.scheduleBuffer(marker, completionCallbackType: .dataPlayedBack) { _ in
            Task { await drainTarget.playbackDidDrain(itemID: itemID, markerID: markerID) }
        }
    }

    func interruptAssistantAudio(ownerID: RealtimeConnectionID) -> PlaybackCutoff? {
        guard self.ownerID == ownerID else { return nil }
        guard let itemID = currentItemID, let player else { return nil }
        let renderedFrame = currentPlayerFrame() ?? playbackOriginFrame ?? 0
        let origin = playbackOriginFrame ?? 0
        let latencyFrames = AVAudioFramePosition(
            (engine?.outputNode.presentationLatency ?? 0) * RealtimeConstants.sampleRate
        )
        let heardAbsolute = max(0, renderedFrame - origin - latencyFrames)
        let heardForItem = max(0, heardAbsolute - currentItemStartFrame)
        let generatedForItem = max(0, scheduledFrames - currentItemStartFrame)
        let clampedFrames = min(heardForItem, generatedForItem)
        let cutoff = PlaybackCutoff(
            itemID: itemID,
            audioEndMilliseconds: Int(
                Double(clampedFrames) / RealtimeConstants.sampleRate * 1_000
            )
        )

        player.stop()
        player.reset()
        resetPlaybackState()
        return clampedFrames < generatedForItem ? cutoff : nil
    }

    func stop(ownerID: RealtimeConnectionID) {
        guard self.ownerID == ownerID else { return }
        if let engine {
            engine.inputNode.removeTap(onBus: 0)
            player?.stop()
            engine.stop()
        }
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
        }
        inputContinuation?.finish()
        inputContinuation = nil
        configurationObserver = nil
        playbackHandler = nil
        networkFormat = nil
        player = nil
        engine = nil
        self.ownerID = nil
        resetPlaybackState()
    }

    private func playbackDidDrain(itemID: String, markerID: UUID) async {
        guard currentItemID == itemID, drainMarkerID == markerID else { return }
        player?.stop()
        player?.reset()
        resetPlaybackState()
        await playbackHandler?(itemID)
    }

    private func currentPlayerFrame() -> AVAudioFramePosition? {
        guard
            let player,
            let renderTime = player.lastRenderTime,
            let playerTime = player.playerTime(forNodeTime: renderTime)
        else { return nil }
        return playerTime.sampleTime
    }

    private func resetPlaybackState() {
        accumulator.reset()
        currentItemID = nil
        currentItemStartFrame = 0
        scheduledFrames = 0
        playbackOriginFrame = nil
        drainMarkerID = nil
    }
}
