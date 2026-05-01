import Foundation
import SwiftData

/// Tracks the user's high-level activity status (Active / Sick / Injured / On a break).
/// Append-only — the latest row by `startedAt` is the current state. Drives the Today
/// status pill (B3) and prepended into the Coach system prompt server-side.
enum ActivityStatusKind: String, Codable, CaseIterable, Sendable {
    case active
    case sick
    case injured
    case onBreak = "on_break"

    var displayName: String {
        switch self {
        case .active: return "Active"
        case .sick: return "Sick"
        case .injured: return "Injured"
        case .onBreak: return "On a break"
        }
    }

    var icon: String {
        switch self {
        case .active: return "bolt.fill"
        case .sick: return "thermometer.medium"
        case .injured: return "bandage.fill"
        case .onBreak: return "pause.circle.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .active: return "Training as planned"
        case .sick: return "Fighting something off"
        case .injured: return "Recovering from an injury"
        case .onBreak: return "Intentional rest period"
        }
    }
}

@Model
final class SDActivityStatus {
    @Attribute(.unique) var id: UUID
    var kindRaw: String
    var startedAt: Date
    var note: String?
    var createdAt: Date

    init(id: UUID = UUID(), kind: ActivityStatusKind, startedAt: Date = Date(), note: String? = nil) {
        self.id = id
        self.kindRaw = kind.rawValue
        self.startedAt = startedAt
        self.note = note
        self.createdAt = Date()
    }

    var kind: ActivityStatusKind {
        ActivityStatusKind(rawValue: kindRaw) ?? .active
    }

    /// Whole days since the status started. Drives the "Injured · 7d+" red-tint logic.
    var daysActive: Int {
        let comps = Calendar.current.dateComponents([.day], from: startedAt, to: Date())
        return max(0, comps.day ?? 0)
    }
}
