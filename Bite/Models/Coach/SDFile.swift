import Foundation
import SwiftData

@Model
final class SDFile {
    @Attribute(.unique) var id: UUID
    var r2Key: String
    var displayName: String
    var mimeType: String
    var sizeBytes: Int
    var uploadedAt: Date
    var labReportId: UUID?
    var folder: String          // "Health Records" | "Notes" | ...

    init(
        id: UUID = UUID(),
        r2Key: String,
        displayName: String,
        mimeType: String,
        sizeBytes: Int,
        uploadedAt: Date = Date(),
        labReportId: UUID? = nil,
        folder: String = "Health Records"
    ) {
        self.id = id
        self.r2Key = r2Key
        self.displayName = displayName
        self.mimeType = mimeType
        self.sizeBytes = sizeBytes
        self.uploadedAt = uploadedAt
        self.labReportId = labReportId
        self.folder = folder
    }
}
