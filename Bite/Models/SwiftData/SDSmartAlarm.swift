import Foundation
import SwiftData

enum AlarmHapticIntensity: String, Codable, CaseIterable, Sendable {
    case progressive
    case gentle
    case medium
    case intense

    var displayName: String {
        switch self {
        case .progressive: return "Progressive"
        case .gentle: return "Gentle"
        case .medium: return "Medium"
        case .intense: return "Intense"
        }
    }

    var subtitle: String {
        switch self {
        case .progressive: return "Soft → loud over the window"
        case .gentle: return "Light single buzz"
        case .medium: return "Standard alarm haptic"
        case .intense: return "Strong continuous haptic"
        }
    }
}

@Model
final class SDSmartAlarm {
    @Attribute(.unique) var id: UUID
    var targetHour: Int
    var targetMinute: Int
    var windowMinutes: Int             // 10 / 15 / 20 / 30
    var hapticIntensityRaw: String
    var savedToWatch: Bool
    var enabled: Bool
    var candidateAlarmIDsRaw: String   // CSV of UUIDs scheduled for this alarm
    var createdAt: Date

    init(
        id: UUID = UUID(),
        targetHour: Int,
        targetMinute: Int,
        windowMinutes: Int,
        hapticIntensity: AlarmHapticIntensity,
        savedToWatch: Bool = true,
        enabled: Bool = true,
        candidateAlarmIDs: [UUID] = []
    ) {
        self.id = id
        self.targetHour = targetHour
        self.targetMinute = targetMinute
        self.windowMinutes = windowMinutes
        self.hapticIntensityRaw = hapticIntensity.rawValue
        self.savedToWatch = savedToWatch
        self.enabled = enabled
        self.candidateAlarmIDsRaw = candidateAlarmIDs.map(\.uuidString).joined(separator: ",")
        self.createdAt = Date()
    }

    var hapticIntensity: AlarmHapticIntensity {
        AlarmHapticIntensity(rawValue: hapticIntensityRaw) ?? .medium
    }

    var candidateAlarmIDs: [UUID] {
        candidateAlarmIDsRaw
            .split(separator: ",")
            .compactMap { UUID(uuidString: String($0)) }
    }

    /// Human readable wake time, e.g. "7:00 AM".
    var formattedWakeTime: String {
        var comps = DateComponents()
        comps.hour = targetHour
        comps.minute = targetMinute
        guard let date = Calendar.current.date(from: comps) else { return "—" }
        return date.formatted(date: .omitted, time: .shortened)
    }
}
