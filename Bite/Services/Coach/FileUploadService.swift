import Foundation
import UIKit
import SwiftData

struct FileUploadResponse: Decodable, Sendable {
    let fileId: UUID
    let uploadUrl: URL
}

struct FileAnalyzeResponse: Decodable, Sendable {
    let fileId: UUID
    let labReportId: UUID?
    let status: String          // "queued" | "processing" | "complete" | "failed"
}

enum FileKind: String, Sendable {
    case pdf, image
    var mimeType: String {
        switch self {
        case .pdf: return "application/pdf"
        case .image: return "image/jpeg"
        }
    }
}

/// Two-step upload + analyze flow:
/// 1. POST /v1/files/upload-url -> presigned R2 URL + fileId
/// 2. PUT bytes directly to R2
/// 3. POST /v1/files/{id}/analyze -> kicks off lab parsing job
@MainActor
final class FileUploadService {
    let api: BiteAPIClient

    init(api: BiteAPIClient) {
        self.api = api
    }

    func upload(data: Data, kind: FileKind, displayName: String, in context: ModelContext) async throws -> SDFile {
        struct Body: Encodable {
            let mimeType: String
            let displayName: String
            let sizeBytes: Int
        }
        let resp: FileUploadResponse = try await api.post(
            "/v1/files/upload-url",
            body: Body(mimeType: kind.mimeType, displayName: displayName, sizeBytes: data.count)
        )

        var put = URLRequest(url: resp.uploadUrl)
        put.httpMethod = "PUT"
        put.setValue(kind.mimeType, forHTTPHeaderField: "Content-Type")
        put.httpBody = data
        let (_, putResponse) = try await URLSession.shared.data(for: put)
        guard let http = putResponse as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw BiteAPIError.server(status: (putResponse as? HTTPURLResponse)?.statusCode ?? 0, message: "R2 upload failed")
        }

        let row = SDFile(
            id: resp.fileId,
            r2Key: "users/uploads/\(resp.fileId.uuidString)",
            displayName: displayName,
            mimeType: kind.mimeType,
            sizeBytes: data.count,
            uploadedAt: Date(),
            folder: "Health Records"
        )
        context.insert(row)
        try context.save()
        return row
    }

    func analyze(fileId: UUID) async throws -> FileAnalyzeResponse {
        try await api.postEmpty("/v1/files/\(fileId.uuidString)/analyze")
    }

    /// Convenience: upload + analyze in one call. Returns the SDFile + analyze response.
    func uploadAndAnalyze(image: UIImage, displayName: String, in context: ModelContext) async throws -> (SDFile, FileAnalyzeResponse) {
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw BiteAPIError.unknown
        }
        let file = try await upload(data: data, kind: .image, displayName: displayName, in: context)
        let analyze = try await analyze(fileId: file.id)
        return (file, analyze)
    }

    func uploadAndAnalyze(pdf: Data, displayName: String, in context: ModelContext) async throws -> (SDFile, FileAnalyzeResponse) {
        let file = try await upload(data: pdf, kind: .pdf, displayName: displayName, in: context)
        let analyze = try await analyze(fileId: file.id)
        return (file, analyze)
    }
}
