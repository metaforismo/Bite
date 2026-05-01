import Foundation

/// Anything that can supply a Firebase ID token and force a refresh on demand.
/// `AuthService` (Firebase-backed) conforms to this once added.
protocol AuthTokenProviding: Sendable {
    func currentIDToken() async throws -> String
    func refreshIDToken() async throws -> String
}
