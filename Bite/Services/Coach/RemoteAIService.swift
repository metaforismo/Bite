import Foundation
import SwiftData

struct ChatRequest: Encodable {
    let text: String
    let healthSnapshot: HealthSnapshot
    let attachments: [ChatAttachmentRef]
}

struct ChatAttachmentRef: Encodable, Sendable {
    let fileId: UUID
    let kind: String        // "image" | "pdf" | ...

    enum CodingKeys: String, CodingKey { case fileId, kind }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        // The worker stores UUIDs lowercase; D1 lookups are case-sensitive.
        try c.encode(fileId.uuidString.lowercased(), forKey: .fileId)
        try c.encode(kind, forKey: .kind)
    }
}

struct ThreadDTO: Decodable, Sendable {
    let id: UUID
    let title: String
    let createdAt: Date
    let lastMessageAt: Date

    enum CodingKeys: String, CodingKey { case id, title, createdAt, lastMessageAt }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        // The worker sends epoch milliseconds.
        let createdMs = try c.decode(Double.self, forKey: .createdAt)
        createdAt = Date(timeIntervalSince1970: createdMs / 1000)
        let lastMs = try c.decodeIfPresent(Double.self, forKey: .lastMessageAt)
        lastMessageAt = lastMs.map { Date(timeIntervalSince1970: $0 / 1000) } ?? createdAt
    }
}

/// Production AIService impl that hits the Cloudflare Worker. Replaces `MockAIService`
/// in production builds — `MockAIService` remains only for SwiftUI #Preview.
@MainActor
final class RemoteAIService {
    let api: BiteAPIClient

    init(api: BiteAPIClient) {
        self.api = api
    }

    func createThread(title: String = "New chat") async throws -> ThreadDTO {
        struct Body: Encodable { let title: String }
        return try await api.post("/v1/chat/threads", body: Body(title: title))
    }

    func listThreads() async throws -> [ThreadDTO] {
        struct Envelope: Decodable { let threads: [ThreadDTO] }
        let envelope: Envelope = try await api.get("/v1/chat/threads")
        return envelope.threads
    }

    /// Sends a user message in `threadId`, streaming back typed events.
    /// Persists the inbound stream into the SwiftData ModelContext on the fly.
    func sendMessage(
        threadId: UUID,
        text: String,
        attachments: [ChatAttachmentRef] = [],
        snapshot: HealthSnapshot
    ) -> AsyncThrowingStream<CoachStreamEvent, Error> {
        let request = ChatRequest(text: text, healthSnapshot: snapshot, attachments: attachments)
        let path = "/v1/chat/threads/\(threadId.uuidString.lowercased())/messages"
        let raw = api.sseStream(path: path, body: request)

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await event in raw {
                        if let decoded = event.decoded() {
                            continuation.yield(decoded)
                            if case .done = decoded { break }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
