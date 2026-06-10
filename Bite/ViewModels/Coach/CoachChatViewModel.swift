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
    var researchCitations: [ResearchCitation] = []
    var activeToolName: String?
    var recentToolActivities: [ToolActivity] = []
    /// Set by the tool_result handler so the chat scroll can render an
    /// inline "View in [tab]" chip without an artifact card. Cleared
    /// after the host view forwards it to BiteRouter.
    var lastInlineReceipt: CoachToolReceipt?

    struct ThinkingStep: Identifiable, Hashable {
        let id = UUID()
        var label: String
        var done: Bool
    }

    struct ResearchCitation: Identifiable, Hashable {
        let id = UUID()
        var title: String
        var url: URL
        var source: String
        var journal: String?
        var publishedAt: String?
    }

    struct ToolActivity: Identifiable, Hashable {
        enum Status: String, Hashable { case running, done, failed }
        let id = UUID()
        var name: String
        var label: String
        var status: Status
        var timestamp: Date = Date()
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

    func openThread(_ thread: CoachThread) {
        streamTask?.cancel()
        streamTask = nil
        self.thread = thread
        thinkingSteps.removeAll()
        streamingText = ""
        researchCitations.removeAll()
        activeToolName = nil
        recentToolActivities.removeAll()
        lastInlineReceipt = nil
        lastError = nil
        isStreaming = false
        mode = thread.messages.isEmpty ? .idle : .response
    }

    func resetForNewThread() {
        streamTask?.cancel()
        streamTask = nil
        thread = nil
        thinkingSteps.removeAll()
        streamingText = ""
        researchCitations.removeAll()
        activeToolName = nil
        recentToolActivities.removeAll()
        lastInlineReceipt = nil
        lastError = nil
        isStreaming = false
        mode = .idle
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
    func send(_ text: String, attachments: [ChatAttachmentRef] = [], contextHint: String? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        streamTask?.cancel()
        streamingText = ""
        thinkingSteps.removeAll()
        researchCitations.removeAll()
        activeToolName = nil
        recentToolActivities.removeAll()
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
            let outboundText: String
            if let hint = contextHint, !hint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                outboundText = "\(hint)\n\nUser message: \(trimmed)"
            } else {
                outboundText = trimmed
            }
            let stream = remote.sendMessage(threadId: thread.id, text: outboundText, attachments: attachments, snapshot: snapshot)

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
                    case .toolCall(let name, _):
                        startToolActivity(name)
                    case .toolResult(let name, let resultJSON):
                        finishToolActivity(name, status: .done)
                        if name == "research_science" {
                            researchCitations = Self.decodeResearchCitations(resultJSON)
                        }
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
                        failActiveTool()
                        lastError = message
                        mode = .error
                    case .done:
                        activeToolName = nil
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
                failActiveTool()
                lastError = error.localizedDescription
                mode = .error
            }

            isStreaming = false
            activeToolName = nil
            if mode != .error { mode = .idle }
        }
    }

    func cancelStream() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        activeToolName = nil
        mode = .idle
    }

    private func startToolActivity(_ name: String) {
        activeToolName = name
        if let idx = recentToolActivities.firstIndex(where: { $0.name == name && $0.status == .running }) {
            recentToolActivities[idx].timestamp = Date()
        } else {
            recentToolActivities.insert(
                ToolActivity(name: name, label: Self.friendlyToolLabel(name), status: .running),
                at: 0
            )
        }
        recentToolActivities = Array(recentToolActivities.prefix(4))
    }

    private func finishToolActivity(_ name: String, status: ToolActivity.Status) {
        if let idx = recentToolActivities.firstIndex(where: { $0.name == name }) {
            recentToolActivities[idx].status = status
            recentToolActivities[idx].timestamp = Date()
        } else {
            recentToolActivities.insert(
                ToolActivity(name: name, label: Self.friendlyToolLabel(name), status: status),
                at: 0
            )
        }
        if activeToolName == name {
            activeToolName = nil
        }
        recentToolActivities = Array(recentToolActivities.prefix(4))
    }

    private func failActiveTool() {
        guard let activeToolName else { return }
        finishToolActivity(activeToolName, status: .failed)
    }

    private static func decodeResearchCitations(_ json: String) -> [ResearchCitation] {
        guard let data = json.data(using: .utf8) else { return [] }
        struct Payload: Decodable {
            struct Source: Decodable {
                let title: String
                let url: URL
                let source: String
                let journal: String?
                let publishedAt: String?
            }
            let sources: [Source]
        }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else { return [] }
        return payload.sources.map {
            ResearchCitation(
                title: $0.title,
                url: $0.url,
                source: $0.source,
                journal: $0.journal,
                publishedAt: $0.publishedAt
            )
        }
    }

    private static func friendlyToolLabel(_ name: String) -> String {
        switch name {
        case "research_science": return "Researching papers"
        case "search_memories": return "Checking memory"
        case "log_food": return "Logging food"
        case "log_water", "log_hydration": return "Logging hydration"
        case "log_caffeine": return "Logging caffeine"
        case "log_activity_status": return "Updating status"
        case "attach_lab_report": return "Reading lab file"
        case "generate_plan": return "Building plan"
        case "log_workout": return "Saving workout"
        case "add_weight_entry": return "Saving weight"
        default:
            return name
                .split(separator: "_")
                .map { $0.prefix(1).uppercased() + $0.dropFirst() }
                .joined(separator: " ")
        }
    }
}
