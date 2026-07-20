import Foundation

struct RealtimeConnectionID: Equatable, Sendable {
    private let value = UUID()
}

struct RealtimeConnectionState: Sendable {
    private var current: RealtimeConnectionID?

    mutating func activate(_ connectionID: RealtimeConnectionID) throws {
        guard current == nil else { throw RealtimeClientError.alreadyConnected }
        current = connectionID
    }

    func matches(_ connectionID: RealtimeConnectionID) -> Bool {
        current == connectionID
    }

    @discardableResult
    mutating func clear(ifCurrent connectionID: RealtimeConnectionID) -> Bool {
        guard current == connectionID else { return false }
        current = nil
        return true
    }
}

@MainActor
final class RealtimeClient {
    typealias EventHandler = @Sendable (RealtimeServerEvent) async -> Void
    typealias DisconnectHandler = @Sendable (String) async -> Void

    private var connectionState = RealtimeConnectionState()
    private var transport: (any RealtimeTransporting)?
    private let makeTransport: () -> any RealtimeTransporting
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(makeTransport: @escaping () -> any RealtimeTransporting = {
        RealtimeWebRTCTransport()
    }) {
        self.makeTransport = makeTransport
    }

    func connect(
        connectionID: RealtimeConnectionID,
        apiKey: String,
        model: RealtimeModel,
        onEvent: @escaping EventHandler,
        onDisconnect: @escaping DisconnectHandler
    ) async throws {
        try connectionState.activate(connectionID)
        let transport = makeTransport()
        self.transport = transport
        do {
            try await transport.connect(
                apiKey: apiKey,
                model: model,
                onMessage: { [weak self] text in
                    await self?.receive(
                        text,
                        connectionID: connectionID,
                        onEvent: onEvent,
                        onDisconnect: onDisconnect
                    )
                },
                onDisconnect: { [weak self] message in
                    await self?.transportDisconnected(
                        message,
                        connectionID: connectionID,
                        onDisconnect: onDisconnect
                    )
                }
            )
        } catch {
            _ = connectionState.clear(ifCurrent: connectionID)
            if self.transport === transport { self.transport = nil }
            transport.disconnect()
            throw error
        }
    }

    func send<Event: Encodable & Sendable>(
        _ event: Event,
        connectionID: RealtimeConnectionID
    ) async throws {
        guard connectionState.matches(connectionID), let transport else {
            throw RealtimeClientError.notConnected
        }
        let data = try encoder.encode(event)
        guard let text = String(data: data, encoding: .utf8) else {
            throw RealtimeClientError.encodingFailed
        }
        try await transport.send(text)
        guard connectionState.matches(connectionID) else {
            throw RealtimeClientError.notConnected
        }
    }

    func setMicrophoneMuted(
        _ muted: Bool,
        connectionID: RealtimeConnectionID
    ) async throws {
        guard connectionState.matches(connectionID), let transport else {
            throw RealtimeClientError.notConnected
        }
        try await transport.setMicrophoneMuted(muted)
    }

    func disconnect(connectionID: RealtimeConnectionID) {
        guard connectionState.clear(ifCurrent: connectionID) else { return }
        transport?.disconnect()
        transport = nil
    }

    private func receive(
        _ text: String,
        connectionID: RealtimeConnectionID,
        onEvent: @escaping EventHandler,
        onDisconnect: @escaping DisconnectHandler
    ) async {
        guard connectionState.matches(connectionID) else { return }
        do {
            let event = try decoder.decode(RealtimeServerEvent.self, from: Data(text.utf8))
            await onEvent(event)
        } catch {
            await transportDisconnected(
                error.localizedDescription,
                connectionID: connectionID,
                onDisconnect: onDisconnect
            )
        }
    }

    private func transportDisconnected(
        _ message: String,
        connectionID: RealtimeConnectionID,
        onDisconnect: @escaping DisconnectHandler
    ) async {
        guard connectionState.clear(ifCurrent: connectionID) else { return }
        transport?.disconnect()
        transport = nil
        await onDisconnect(message)
    }
}

enum RealtimeClientError: LocalizedError {
    case alreadyConnected
    case notConnected
    case encodingFailed
    case invalidCallResponse
    case callFailed(String)

    var errorDescription: String? {
        switch self {
        case .alreadyConnected: "A Realtime session is already connected."
        case .notConnected: "The Realtime session is not connected."
        case .encodingFailed: "A Realtime event could not be encoded."
        case .invalidCallResponse: "OpenAI returned an invalid WebRTC answer."
        case .callFailed(let detail): "The Realtime WebRTC connection failed: \(detail)"
        }
    }
}
