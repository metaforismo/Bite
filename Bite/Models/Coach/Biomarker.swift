import Foundation
import SwiftData

enum BiomarkerStatus: String, Codable, Sendable {
    case low, inRange, high, unknown
}

@Model
final class Biomarker {
    @Attribute(.unique) var id: UUID
    var labReportId: UUID?
    var name: String           // e.g. "LDL Cholesterol"
    var category: String       // "Lipids" | "Inflammation" | "Metabolic" | ...
    var value: Double
    var unit: String           // e.g. "mg/dL"
    var refLow: Double?
    var refHigh: Double?
    var statusRaw: String
    var takenAt: Date

    var status: BiomarkerStatus {
        get { BiomarkerStatus(rawValue: statusRaw) ?? .unknown }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        labReportId: UUID? = nil,
        name: String,
        category: String,
        value: Double,
        unit: String,
        refLow: Double? = nil,
        refHigh: Double? = nil,
        status: BiomarkerStatus = .unknown,
        takenAt: Date = Date()
    ) {
        self.id = id
        self.labReportId = labReportId
        self.name = name
        self.category = category
        self.value = value
        self.unit = unit
        self.refLow = refLow
        self.refHigh = refHigh
        self.statusRaw = status.rawValue
        self.takenAt = takenAt
    }
}
