import Foundation

enum BiteAPIError: Error, LocalizedError {
    case notAuthenticated
    case unauthorized
    case server(status: Int, message: String?)
    case decoding(Error)
    case transport(Error)
    case streamMalformed
    case unknown

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Not signed in."
        case .unauthorized: return "Session expired. Please sign in again."
        case .server(let status, let message): return "Server error (\(status))\(message.map { ": \($0)" } ?? "")"
        case .decoding(let err): return "Decoding failed: \(err.localizedDescription)"
        case .transport(let err): return err.localizedDescription
        case .streamMalformed: return "Streaming response was malformed."
        case .unknown: return "An unknown error occurred."
        }
    }
}
