import Foundation
import SwiftData

enum CoachMessageRole: String, Codable, Sendable {
    case user
    case assistant
    case system
}

@Model
class CoachMessage {
    var id: UUID
    var roleRaw: String
    var text: String
    var createdAt: Date

    @Relationship var thread: CoachThread?

    var role: CoachMessageRole {
        get { CoachMessageRole(rawValue: roleRaw) ?? .system }
        set { roleRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        role: CoachMessageRole,
        text: String,
        createdAt: Date = Date(),
        thread: CoachThread? = nil
    ) {
        self.id = id
        self.roleRaw = role.rawValue
        self.text = text
        self.createdAt = createdAt
        self.thread = thread
    }
}

@available(iOS 26.0, *)
@Model
final class ArtifactMessage: CoachMessage {
    var artifactType: String
    var payloadJSON: Data
    var version: Int

    init(
        id: UUID = UUID(),
        role: CoachMessageRole = .assistant,
        text: String = "",
        createdAt: Date = Date(),
        thread: CoachThread? = nil,
        artifactType: String,
        payloadJSON: Data,
        version: Int = 1
    ) {
        self.artifactType = artifactType
        self.payloadJSON = payloadJSON
        self.version = version
        super.init(id: id, role: role, text: text, createdAt: createdAt, thread: thread)
    }
}
