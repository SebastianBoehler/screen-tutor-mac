import Foundation

actor RealtimeClient {
    typealias EventHandler = @Sendable (RealtimeServerEvent) async -> Void
    typealias DisconnectHandler = @Sendable (String) async -> Void

    private var webSocket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var eventHandler: EventHandler?
    private var disconnectHandler: DisconnectHandler?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func connect(
        apiKey: String,
        onEvent: @escaping EventHandler,
        onDisconnect: @escaping DisconnectHandler
    ) throws {
        guard webSocket == nil else { throw RealtimeClientError.alreadyConnected }

        var request = URLRequest(url: RealtimeConstants.endpoint)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 20

        let socket = URLSession.shared.webSocketTask(with: request)
        webSocket = socket
        eventHandler = onEvent
        disconnectHandler = onDisconnect
        socket.resume()

        receiveTask = Task { [weak self] in
            await self?.receiveLoop()
        }
    }

    func send<Event: Encodable & Sendable>(_ event: Event) async throws {
        guard let webSocket else { throw RealtimeClientError.notConnected }
        let data = try encoder.encode(event)
        guard let text = String(data: data, encoding: .utf8) else {
            throw RealtimeClientError.encodingFailed
        }
        try await webSocket.send(.string(text))
    }

    func disconnect() {
        receiveTask?.cancel()
        receiveTask = nil
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        eventHandler = nil
        disconnectHandler = nil
    }

    private func receiveLoop() async {
        guard let webSocket else { return }

        do {
            while !Task.isCancelled {
                let message = try await webSocket.receive()
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
                await eventHandler?(event)
            }
        } catch is CancellationError {
            return
        } catch {
            let message = Self.describe(error)
            webSocket.cancel(with: .abnormalClosure, reason: nil)
            self.webSocket = nil
            await disconnectHandler?(message)
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
