import Foundation
@preconcurrency import WebRTC

@MainActor
final class RealtimeWebRTCTransport: NSObject, RealtimeTransporting {
    private static let sslInitialized = RTCInitializeSSL()
    private let negotiator: RealtimeCallNegotiator
    private var factory: RTCPeerConnectionFactory?
    private var peerConnection: RTCPeerConnection?
    private var dataChannel: RTCDataChannel?
    private var audioTrack: RTCAudioTrack?
    private var onMessage: ((String) async -> Void)?
    private var onDisconnect: ((String) async -> Void)?
    private var openContinuation: CheckedContinuation<Void, any Error>?
    private var openTimeoutTask: Task<Void, Never>?
    private var iceContinuation: CheckedContinuation<Void, any Error>?
    private var iceTimeoutTask: Task<Void, Never>?
    private var isClosing = false

    init(negotiator: RealtimeCallNegotiator = RealtimeCallNegotiator()) {
        self.negotiator = negotiator
    }

    func connect(
        apiKey: String,
        model: RealtimeModel,
        onMessage: @escaping (String) async -> Void,
        onDisconnect: @escaping (String) async -> Void
    ) async throws {
        guard peerConnection == nil else { throw RealtimeClientError.alreadyConnected }
        _ = Self.sslInitialized
        self.onMessage = onMessage
        self.onDisconnect = onDisconnect
        isClosing = false

        let audioDevice = SharedWebRTCAudioDevice()
        let factory = RTCPeerConnectionFactory(
            encoderFactory: nil,
            decoderFactory: nil,
            audioDevice: audioDevice
        )
        let configuration = RTCConfiguration()
        configuration.sdpSemantics = .unifiedPlan
        let peerConstraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: nil
        )
        guard let peer = factory.peerConnection(
            with: configuration,
            constraints: peerConstraints,
            delegate: self
        ) else {
            throw RealtimeClientError.callFailed("WebRTC could not create a peer connection.")
        }
        self.factory = factory
        peerConnection = peer

        let audioConstraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: RealtimeWebRTCAudioConstraints.optional
        )
        let source = factory.audioSource(with: audioConstraints)
        let track = factory.audioTrack(with: source, trackId: "screen-tutor-microphone")
        guard peer.add(track, streamIds: ["screen-tutor"]) != nil else {
            throw RealtimeClientError.callFailed("WebRTC could not add the microphone track.")
        }
        audioTrack = track

        let channelConfiguration = RTCDataChannelConfiguration()
        guard let channel = peer.dataChannel(
            forLabel: "oai-events",
            configuration: channelConfiguration
        ) else {
            throw RealtimeClientError.callFailed("WebRTC could not create its event channel.")
        }
        channel.delegate = self
        dataChannel = channel

        do {
            let offer = try await createOffer(peer: peer)
            try await setLocalDescription(offer, peer: peer)
            try await waitForICEGathering(peer: peer)
            guard let localSDP = peer.localDescription?.sdp else {
                throw RealtimeClientError.invalidCallResponse
            }
            let answerSDP = try await negotiator.answerSDP(
                apiKey: apiKey,
                offerSDP: localSDP,
                model: model
            )
            let answer = RTCSessionDescription(type: .answer, sdp: answerSDP)
            try await setRemoteDescription(answer, peer: peer)
            if channel.readyState != .open {
                try await waitForDataChannel(channel: channel, peer: peer)
            }
        } catch {
            disconnect()
            throw error
        }
    }

    func send(_ text: String) async throws {
        guard let channel = dataChannel, channel.readyState == .open else {
            throw RealtimeClientError.notConnected
        }
        let data = Data(text.utf8)
        guard data.count <= RealtimeEventSizePolicy.maximumTextBytes else {
            throw RealtimeClientError.callFailed(
                "The \(eventType(in: data)) event is too large for the Realtime data channel "
                    + "(\(data.count) bytes)."
            )
        }
        let buffer = RTCDataBuffer(data: data, isBinary: false)
        guard channel.sendData(buffer) else {
            throw RealtimeClientError.callFailed(
                "The Realtime event channel rejected the \(eventType(in: data)) event "
                    + "(\(data.count) bytes; \(channel.bufferedAmount) bytes queued)."
            )
        }
    }

    private func eventType(in data: Data) -> String {
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        return object?["type"] as? String ?? "unknown"
    }

    func setMicrophoneMuted(_ muted: Bool) async throws {
        guard let audioTrack, peerConnection != nil else {
            throw RealtimeClientError.notConnected
        }
        audioTrack.isEnabled = !muted
    }

    func disconnect() {
        guard peerConnection != nil || openContinuation != nil else { return }
        isClosing = true
        openContinuation?.resume(throwing: CancellationError())
        openContinuation = nil
        openTimeoutTask?.cancel()
        openTimeoutTask = nil
        iceTimeoutTask?.cancel()
        iceTimeoutTask = nil
        iceContinuation?.resume(throwing: CancellationError())
        iceContinuation = nil
        audioTrack?.isEnabled = false
        dataChannel?.delegate = nil
        dataChannel?.close()
        peerConnection?.delegate = nil
        peerConnection?.close()
        audioTrack = nil
        dataChannel = nil
        peerConnection = nil
        factory = nil
        onMessage = nil
        onDisconnect = nil
    }

    private func createOffer(peer: RTCPeerConnection) async throws -> RTCSessionDescription {
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: ["OfferToReceiveAudio": "true"],
            optionalConstraints: nil
        )
        return try await withCheckedThrowingContinuation { continuation in
            peer.offer(for: constraints) { offer, error in
                if let offer { continuation.resume(returning: offer) }
                else { continuation.resume(throwing: error ?? RealtimeClientError.invalidCallResponse) }
            }
        }
    }

    private func setLocalDescription(
        _ description: RTCSessionDescription,
        peer: RTCPeerConnection
    ) async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, any Error>) in
            peer.setLocalDescription(description) { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }
    }

    private func setRemoteDescription(
        _ description: RTCSessionDescription,
        peer: RTCPeerConnection
    ) async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, any Error>) in
            peer.setRemoteDescription(description) { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }
    }

    private func waitForDataChannel(
        channel: RTCDataChannel,
        peer: RTCPeerConnection
    ) async throws {
        guard channel.readyState != .closed, peer.connectionState != .failed else {
            throw RealtimeClientError.callFailed("The Realtime event channel could not open.")
        }
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, any Error>) in
            openContinuation = continuation
            openTimeoutTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled, let self, let continuation = self.openContinuation else {
                    return
                }
                self.openContinuation = nil
                continuation.resume(throwing: RealtimeClientError.callFailed(
                    "Timed out while opening the Realtime event channel."
                ))
            }
        }
    }

    private func waitForICEGathering(peer: RTCPeerConnection) async throws {
        guard peer.iceGatheringState != .complete else { return }
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, any Error>) in
            iceContinuation = continuation
            iceTimeoutTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled, let self, let continuation = self.iceContinuation else {
                    return
                }
                self.iceContinuation = nil
                continuation.resume(throwing: RealtimeClientError.callFailed(
                    "Timed out while gathering local network candidates."
                ))
            }
        }
    }

    func iceGatheringCompleted() {
        iceTimeoutTask?.cancel()
        iceTimeoutTask = nil
        iceContinuation?.resume()
        iceContinuation = nil
    }

    private func channelOpened() {
        openTimeoutTask?.cancel()
        openTimeoutTask = nil
        openContinuation?.resume()
        openContinuation = nil
    }

    func fail(_ message: String) {
        if let continuation = openContinuation {
            openTimeoutTask?.cancel()
            openTimeoutTask = nil
            openContinuation = nil
            continuation.resume(throwing: RealtimeClientError.callFailed(message))
        } else if !isClosing {
            Task { await onDisconnect?(message) }
        }
    }

}

extension RealtimeWebRTCTransport: RTCDataChannelDelegate {
    nonisolated func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        let state = dataChannel.readyState
        Task { @MainActor [weak self] in
            if state == .open { self?.channelOpened() }
            else if state == .closed { self?.fail("The Realtime event channel closed.") }
        }
    }

    nonisolated func dataChannel(
        _ dataChannel: RTCDataChannel,
        didReceiveMessageWith buffer: RTCDataBuffer
    ) {
        guard let text = String(data: buffer.data, encoding: .utf8) else { return }
        Task { @MainActor [weak self] in await self?.onMessage?(text) }
    }
}
