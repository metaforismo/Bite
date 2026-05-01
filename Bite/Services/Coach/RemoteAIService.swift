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
}

struct ThreadDTO: Decodable, Sendable {
    let id: UUID
    let title: String
    let createdAt: Date
    let lastMessageAt: Date
    enum CodingKeys: String, CodingKey {
        case id, title
        case createdAt = "created_at"
        case lastMessageAt = "last_message_at"
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
        try await api.get("/v1/chat/threads")
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
        let path = "/v1/chat/threads/\(threadId.uuidString)/messages"
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
