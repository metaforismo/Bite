import Foundation
import SwiftData

@Model
final class BiologicalAgeSnapshot {
    @Attribute(.unique) var id: UUID
    var computedAt: Date
    var chronologicalAge: Int
    var biologicalAge: Double
    var confidence: Double          // 0...1
    var breakdownJSON: Data         // JSON-encoded BioAgeBreakdown

    init(
        id: UUID = UUID(),
        computedAt: Date = Date(),
        chronologicalAge: Int,
        biologicalAge: Double,
        confidence: Double,
        breakdown: BioAgeBreakdown
    ) {
        self.id = id
        self.computedAt = computedAt
        self.chronologicalAge = chronologicalAge
        self.biologicalAge = biologicalAge
        self.confidence = confidence
        self.breakdownJSON = (try? JSONEncoder().encode(breakdown)) ?? Data()
    }

    var breakdown: BioAgeBreakdown {
        (try? JSONDecoder().decode(BioAgeBreakdown.self, from: breakdownJSON)) ?? .empty
    }

    var deltaYears: Double { Double(chronologicalAge) - biologicalAge }
}

nonisolated struct BioAgeBreakdown: Codable, Sendable {
    var sleep: [Driver]
    var activity: [Driver]
    var fitness: [Driver]
    var lifestyle: [Driver]
    var blood: [Driver]

    static let empty = BioAgeBreakdown(sleep: [], activity: [], fitness: [], lifestyle: [], blood: [])

    /// One micro-metric contributing to the age estimate (positive deltaYears
    /// means this metric is *adding* years to the estimate, negative means it
    /// is taking years off).
    nonisolated struct Driver: Codable, Sendable, Identifiable {
        var id: UUID
        var label: String
        var deltaYears: Double

        init(id: UUID = UUID(), label: String, deltaYears: Double) {
            self.id = id
            self.label = label
            self.deltaYears = deltaYears
        }
    }
}
