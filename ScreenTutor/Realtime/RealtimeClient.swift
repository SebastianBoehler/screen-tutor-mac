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

actor RealtimeClient {
    typealias EventHandler = @Sendable (RealtimeServerEvent) async -> Void
    typealias DisconnectHandler = @Sendable (String) async -> Void

    private var connectionState = RealtimeConnectionState()
    private var webSocket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func connect(
        connectionID: RealtimeConnectionID,
        apiKey: String,
        onEvent: @escaping EventHandler,
        onDisconnect: @escaping DisconnectHandler
    ) throws {
        try connectionState.activate(connectionID)

        var request = URLRequest(url: RealtimeConstants.endpoint)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 20

        let socket = URLSession.shared.webSocketTask(with: request)
        webSocket = socket
        socket.resume()

        receiveTask = Task { [weak self] in
            await self?.receiveLoop(
                socket: socket,
                connectionID: connectionID,
                eventHandler: onEvent,
                disconnectHandler: onDisconnect
            )
        }
    }

    func send<Event: Encodable & Sendable>(
        _ event: Event,
        connectionID: RealtimeConnectionID
    ) async throws {
        guard connectionState.matches(connectionID), let webSocket else {
            throw RealtimeClientError.notConnected
        }
        let data = try encoder.encode(event)
        guard let text = String(data: data, encoding: .utf8) else {
            throw RealtimeClientError.encodingFailed
        }
        try await webSocket.send(.string(text))
        guard connectionState.matches(connectionID) else {
            throw RealtimeClientError.notConnected
        }
    }

    func disconnect(connectionID: RealtimeConnectionID) {
        guard connectionState.clear(ifCurrent: connectionID) else { return }
        receiveTask?.cancel()
        receiveTask = nil
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
    }

    private func receiveLoop(
        socket: URLSessionWebSocketTask,
        connectionID: RealtimeConnectionID,
        eventHandler: @escaping EventHandler,
        disconnectHandler: @escaping DisconnectHandler
    ) async {
        do {
            while !Task.isCancelled {
                let message = try await socket.receive()
                guard connectionState.matches(connectionID) else { return }
                let data: Data
                switch message {
                case .string(let text):
                    data = Data(text.utf8)
                case .data(let bytes):
                    data = bytes
                @unknown default:
                    continue
                }
                let event = try decoder.decode(RealtimeServerEvent.self, from: data)
                await eventHandler(event)
            }
        } catch is CancellationError {
            return
        } catch {
            guard connectionState.clear(ifCurrent: connectionID) else { return }
            let message = Self.describe(error)
            socket.cancel(with: .abnormalClosure, reason: nil)
            if webSocket === socket { webSocket = nil }
            receiveTask = nil
            await disconnectHandler(message)
        }
    }

    private static func describe(_ error: Error) -> String {
        if let urlError = error as? URLError {
            return urlError.localizedDescription
        }
        return error.localizedDescription
    }
}

enum RealtimeClientError: LocalizedError {
    case alreadyConnected
    case notConnected
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .alreadyConnected: "A Realtime session is already connected."
        case .notConnected: "The Realtime session is not connected."
        case .encodingFailed: "A Realtime event could not be encoded."
        }
    }
}
