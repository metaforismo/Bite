import Foundation
import SwiftData
import SwiftUI

/// Manages a single chat conversation: thread lifecycle, streaming, persistence.
@MainActor
@Observable
final class CoachChatViewModel {
    enum Mode: String { case idle, typed, thinking, response, listening, error }

    var mode: Mode = .idle
    var thread: CoachThread?
    var thinkingSteps: [ThinkingStep] = []
    var streamingText: String = ""
    var isStreaming: Bool = false
    var lastError: String?
    /// Set by the tool_result handler so the chat scroll can render an
    /// inline "View in [tab]" chip without an artifact card. Cleared
    /// after the host view forwards it to BiteRouter.
    var lastInlineReceipt: CoachToolReceipt?

    struct ThinkingStep: Identifiable, Hashable {
        let id = UUID()
        var label: String
        var done: Bool
    }

    private let modelContext: ModelContext
    private let remote: RemoteAIService
    private let auth: AuthTokenProviding
    private var streamTask: Task<Void, Never>?

    init(modelContext: ModelContext, remote: RemoteAIService, auth: AuthTokenProviding) {
        self.modelContext = modelContext
        self.remote = remote
        self.auth = auth
    }

    func startNewThreadIfNeeded() async {
        guard thread == nil else { return }
        do {
            let dto = try await remote.createThread()
            let local = CoachThread(
                id: dto.id,
                title: dto.title,
                pinned: false,
                lastMessageAt: dto.lastMessageAt,
                createdAt: dto.createdAt,
                firebaseUID: AuthService.shared.session?.uid
            )
            modelContext.insert(local)
            try modelContext.save()
            self.thread = local
        } catch {
            self.lastError = error.localizedDescription
            self.mode = .error
        }
    }

    /// Submits a user message + optional photo (already uploaded with a fileId).
    func send(_ text: String, attachments: [ChatAttachmentRef] = []) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        streamTask?.cancel()
        streamingText = ""
        thinkingSteps.removeAll()
        mode = .thinking
        isStreaming = true

        streamTask = Task { [weak self] in
            guard let self else { return }
            await self.startNewThreadIfNeeded()
            guard let thread = self.thread else { return }

            // Persist user message immediately.
            let userMsg = CoachMessage(role: .user, text: trimmed, thread: thread)
            modelContext.insert(userMsg)
            thread.lastMessageAt = Date()
            try? modelContext.save()

            let snapshot = await HealthKitService.shared.snapshot()
            let stream = remote.sendMessage(threadId: thread.id, text: trimmed, attachments: attachments, snapshot: snapshot)

            do {
                var assistantText = ""
                var assistantMessage: CoachMessage?
                for try await event in stream {
                    try Task.checkCancellation()
                    switch event {
                    case .threadId:
                        break
                    case .thinkingStep(let label, let status):
                        if let idx = thinkingSteps.firstIndex(where: { $0.label == label }) {
                            thinkingSteps[idx].done = status == .done
                        } else {
                            thinkingSteps.append(.init(label: label, done: status == .done))
                        }
                    case .textDelta(let chunk):
                        assistantText += chunk
                        streamingText = assistantText
                        if mode != .response { mode = .response }
                    case .toolCall:
                        // Worker is invoking a tool. Telemetry only — the
                        // resulting state is reflected via `.artifact` (food)
                        // or `.toolResult` (drink/activity/weight) below.
                        break
                    case .toolResult(let name, let resultJSON):
                        // Mirror non-food tool outcomes (food goes via the
                        // food_cart artifact path so confirmation can gate
                        // the local write). The dispatcher returns a
                        // receipt the host view forwards to BiteRouter.
                        if let receipt = CoachToolDispatcher.shared.handleToolResult(name: name, resultJSON: resultJSON) {
                            lastInlineReceipt = receipt
                        }
                    case .artifact(let payload):
                        let payloadData = payload.payload.json.data(using: .utf8) ?? Data()
                        let artifact = ArtifactMessage(
                            id: payload.id,
                            role: .assistant,
                            text: assistantText,
                            thread: thread,
                            artifactType: payload.type,
                            payloadJSON: payloadData,
                            version: payload.version
                        )
                        // Update-in-place if the same artifact id already exists (versioned edits).
                        if let existing = thread.messages.compactMap({ $0 as? ArtifactMessage }).first(where: { $0.id == payload.id }) {
                            existing.payloadJSON = payloadData
                            existing.version = payload.version
                            existing.text = assistantText
                        } else {
                            modelContext.insert(artifact)
                        }
                        try? modelContext.save()
                    case .error(let message):
                        lastError = message
                        mode = .error
                    case .done:
                        if !assistantText.isEmpty, assistantMessage == nil {
                            let msg = CoachMessage(role: .assistant, text: assistantText, thread: thread)
                            modelContext.insert(msg)
                            assistantMessage = msg
                        }
                        thread.lastMessageAt = Date()
                        try? modelContext.save()
                    }
                }
            } catch is CancellationError {
                // Swallow.
            } catch {
                lastError = error.localizedDescription
                mode = .error
            }

            isStreaming = false
            if mode != .error { mode = .idle }
        }
    }

    func cancelStream() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        mode = .idle
    }
}
