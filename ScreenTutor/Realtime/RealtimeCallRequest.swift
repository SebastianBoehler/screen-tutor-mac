import Foundation

struct RealtimeCallRequest {
    let urlRequest: URLRequest

    init(
        apiKey: String,
        offerSDP: String,
        model: RealtimeModel,
        boundary: String = "ScreenTutor-\(UUID().uuidString)"
    ) throws {
        let session = RealtimeBootstrapSession(type: "realtime", model: model.rawValue)
        let sessionData = try JSONEncoder().encode(session)
        guard let sessionJSON = String(data: sessionData, encoding: .utf8) else {
            throw RealtimeClientError.encodingFailed
        }

        var request = URLRequest(url: RealtimeConstants.callsEndpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )
        request.httpBody = Self.multipartBody(
            boundary: boundary,
            offerSDP: offerSDP,
            sessionJSON: sessionJSON
        )
        urlRequest = request
    }

    private static func multipartBody(
        boundary: String,
        offerSDP: String,
        sessionJSON: String
    ) -> Data {
        var body = Data()
        func append(_ value: String) {
            body.append(Data(value.utf8))
        }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"sdp\"\r\n")
        append("Content-Type: application/sdp\r\n\r\n")
        append(offerSDP)
        append("\r\n--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"session\"\r\n")
        append("Content-Type: application/json\r\n\r\n")
        append(sessionJSON)
        append("\r\n--\(boundary)--\r\n")
        return body
    }
}

private struct RealtimeBootstrapSession: Encodable {
    let type: String
    let model: String
}

struct RealtimeCallNegotiator: Sendable {
    var dataForRequest: @Sendable (URLRequest) async throws -> (Data, URLResponse) = {
        try await URLSession.shared.data(for: $0)
    }

    func answerSDP(
        apiKey: String,
        offerSDP: String,
        model: RealtimeModel
    ) async throws -> String {
        let request = try RealtimeCallRequest(
            apiKey: apiKey,
            offerSDP: offerSDP,
            model: model
        ).urlRequest
        let (data, response) = try await dataForRequest(request)
        guard let http = response as? HTTPURLResponse else {
            throw RealtimeClientError.invalidCallResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let detail = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw RealtimeClientError.callFailed(detail)
        }
        guard let answer = String(data: data, encoding: .utf8), !answer.isEmpty else {
            throw RealtimeClientError.invalidCallResponse
        }
        return answer
    }
}
