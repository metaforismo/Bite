import Foundation
import SwiftData

@Model
final class LabReport {
    @Attribute(.unique) var id: UUID
    var fileId: UUID?
    var title: String
    var takenAt: Date
    var sourceUrl: String?
    var confidence: Double      // 0...1
    var createdAt: Date

    init(
        id: UUID = UUID(),
        fileId: UUID? = nil,
        title: String,
        takenAt: Date,
        sourceUrl: String? = nil,
        confidence: Double = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.fileId = fileId
        self.title = title
        self.takenAt = takenAt
        self.sourceUrl = sourceUrl
        self.confidence = confidence
        self.createdAt = createdAt
    }
}
