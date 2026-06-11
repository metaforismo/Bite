import Foundation

/// Strongly typed Bite Worker client.
/// - Auth: attaches Firebase ID token via `AuthTokenProviding` on every request.
///         Retries once with a refreshed token on 401.
/// - Streaming: returns an `AsyncThrowingStream<SSEEvent, Error>` for SSE endpoints.
final class BiteAPIClient: Sendable {
    private let baseURL: URL
    private let session: URLSession
    private let auth: any AuthTokenProviding
    private let decoder: JSONDecoder

    init(
        baseURL: URL = BiteAPIConfig.baseURL,
        auth: any AuthTokenProviding,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.auth = auth
        self.session = session
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    // MARK: Request building

    private func request(path: String, method: String = "GET", body: Data? = nil, token: String) -> URLRequest {
        var url = baseURL
        url.append(path: path)
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = body
        return req
    }

    // MARK: Plain JSON requests with auto-refresh

    func get<Out: Decodable>(_ path: String) async throws -> Out {
        try await jsonRequest(path: path, method: "GET", body: nil)
    }

    func post<In: Encodable, Out: Decodable>(_ path: String, body: In) async throws -> Out {
        let data = try JSONEncoder.bite.encode(body)
        return try await jsonRequest(path: path, method: "POST", body: data)
    }

    func postEmpty<Out: Decodable>(_ path: String) async throws -> Out {
        try await jsonRequest(path: path, method: "POST", body: nil)
    }

    func patch<In: Encodable, Out: Decodable>(_ path: String, body: In) async throws -> Out {
        let data = try JSONEncoder.bite.encode(body)
        return try await jsonRequest(path: path, method: "PATCH", body: data)
    }

    func delete<Out: Decodable>(_ path: String) async throws -> Out {
        try await jsonRequest(path: path, method: "DELETE", body: nil)
    }

    private func jsonRequest<Out: Decodable>(path: String, method: String, body: Data?) async throws -> Out {
        let token = try await auth.currentIDToken()
        let req = request(path: path, method: method, body: body, token: token)

        let (data, response) = try await dataTask(req)
        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            // One-shot refresh + retry.
            let newToken = try await auth.refreshIDToken()
            let retry = request(path: path, method: method, body: body, token: newToken)
            let (retryData, retryResp) = try await dataTask(retry)
            try Self.assertSuccess(response: retryResp, data: retryData)
            return try decoder.decode(Out.self, from: retryData)
        }
        try Self.assertSuccess(response: response, data: data)
        return try decoder.decode(Out.self, from: data)
    }

    private func dataTask(_ req: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: req)
        } catch {
            throw BiteAPIError.transport(error)
        }
    }

    /// Authenticated raw PUT (used for the same-origin file upload proxy,
    /// which sits behind Firebase auth like every other /v1 route).
    func authorizedPUT(url: URL, data: Data, contentType: String) async throws {
        func makeRequest(token: String) -> URLRequest {
            var req = URLRequest(url: url)
            req.httpMethod = "PUT"
            req.setValue(contentType, forHTTPHeaderField: "Content-Type")
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.httpBody = data
            return req
        }
        let token = try await auth.currentIDToken()
        let (respData, response) = try await dataTask(makeRequest(token: token))
        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            let newToken = try await auth.refreshIDToken()
            let (retryData, retryResp) = try await dataTask(makeRequest(token: newToken))
            try Self.assertSuccess(response: retryResp, data: retryData)
            return
        }
        try Self.assertSuccess(response: response, data: respData)
    }

    private static func assertSuccess(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw BiteAPIError.unknown }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401 { throw BiteAPIError.unauthorized }
            let message = String(data: data, encoding: .utf8)
            throw BiteAPIError.server(status: http.statusCode, message: message)
        }
    }

    // MARK: SSE streaming

    /// POST with a JSON body that returns an SSE stream of events.
    /// Auto-refreshes the token once on 401 and replays the request.
    func sseStream<In: Encodable>(path: String, body: In) -> AsyncThrowingStream<SSEEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await self.runSSE(path: path, body: body, continuation: continuation, allowRefresh: true)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func runSSE<In: Encodable>(
        path: String,
        body: In,
        continuation: AsyncThrowingStream<SSEEvent, Error>.Continuation,
        allowRefresh: Bool
    ) async throws {
        let token = try await auth.currentIDToken()
        let bodyData = try JSONEncoder.bite.encode(body)
        var req = request(path: path, method: "POST", body: bodyData, token: token)
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        let (bytes, response) = try await session.bytes(for: req)
        guard let http = response as? HTTPURLResponse else { throw BiteAPIError.unknown }
        if http.statusCode == 401 {
            guard allowRefresh else { throw BiteAPIError.unauthorized }
            _ = try await auth.refreshIDToken()
            try await runSSE(path: path, body: body, continuation: continuation, allowRefresh: false)
            return
        }
        guard (200..<300).contains(http.statusCode) else {
            throw BiteAPIError.server(status: http.statusCode, message: nil)
        }

        var parser = SSEParser()
        var lineBuffer: [UInt8] = []
        for try await byte in bytes {
            try Task.checkCancellation()
            lineBuffer.append(byte)
            // Flush once we see "\n\n" or every ~4KB whichever first.
            if lineBuffer.count >= 4_096 || (lineBuffer.count >= 2 && lineBuffer.suffix(2) == [0x0A, 0x0A]) {
                let chunk = Data(lineBuffer)
                lineBuffer.removeAll(keepingCapacity: true)
                for event in parser.feed(chunk) {
                    continuation.yield(event)
                }
            }
        }
        if !lineBuffer.isEmpty {
            let chunk = Data(lineBuffer)
            for event in parser.feed(chunk) {
                continuation.yield(event)
            }
        }
        for event in parser.drain() {
            continuation.yield(event)
        }
    }
}

extension JSONEncoder {
    /// Wire encoder for the Bite Worker. The worker validates camelCase keys
    /// with strict Zod schemas — keys must pass through unchanged.
    static let bite: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}
