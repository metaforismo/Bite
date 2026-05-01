import Foundation
import AuthenticationServices

#if canImport(FirebaseAuth)
import FirebaseAuth
import FirebaseCore
#endif

enum AuthProvider: String, Sendable {
    case apple, google, email, anonymous
}

struct AuthSession: Sendable, Equatable {
    let uid: String
    let email: String?
    let displayName: String?
    let provider: AuthProvider
}

/// Concrete Firebase-backed auth implementation that also supports a dev-anonymous fallback when
/// the FirebaseAuth SwiftPM package hasn't been added to the project yet. As soon as the package
/// is wired in (Xcode → File → Add Package Dependencies → https://github.com/firebase/firebase-ios-sdk),
/// the `#if canImport(FirebaseAuth)` paths take over.
@MainActor
final class AuthService: AuthTokenProviding {
    static let shared = AuthService()

    private let userDefaults = UserDefaults.standard
    private let lastUIDKey = "bite_auth_last_uid"

    private(set) var session: AuthSession?

    private init() {
        #if canImport(FirebaseAuth)
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        if let user = Auth.auth().currentUser {
            self.session = AuthSession(
                uid: user.uid,
                email: user.email,
                displayName: user.displayName,
                provider: Self.provider(for: user)
            )
        }
        #else
        // Dev fallback: synthesize a stable anonymous UID so the rest of the app works.
        let stored = userDefaults.string(forKey: lastUIDKey)
        let uid = stored ?? "dev_" + UUID().uuidString.lowercased()
        if stored == nil { userDefaults.set(uid, forKey: lastUIDKey) }
        self.session = AuthSession(uid: uid, email: nil, displayName: nil, provider: .anonymous)
        #endif
    }

    // MARK: AuthTokenProviding

    func currentIDToken() async throws -> String {
        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else { throw BiteAPIError.notAuthenticated }
        return try await user.getIDToken()
        #else
        return try makeDevToken(forceRefresh: false)
        #endif
    }

    func refreshIDToken() async throws -> String {
        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else { throw BiteAPIError.notAuthenticated }
        return try await user.getIDTokenResult(forcingRefresh: true).token
        #else
        return try makeDevToken(forceRefresh: true)
        #endif
    }

    // MARK: Sign-in flows

    /// Sign in with Apple — uses ASAuthorizationAppleIDProvider, then federates to Firebase Auth.
    /// In the dev fallback, this just stamps an anonymous session.
    func signInWithApple(authorization: ASAuthorization) async throws -> AuthSession {
        #if canImport(FirebaseAuth)
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            throw BiteAPIError.notAuthenticated
        }
        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: AppleSignInNonce.shared.lastNonce ?? "",
            fullName: credential.fullName
        )
        let result = try await Auth.auth().signIn(with: firebaseCredential)
        let session = AuthSession(
            uid: result.user.uid,
            email: result.user.email,
            displayName: result.user.displayName ?? credential.fullName?.givenName,
            provider: .apple
        )
        self.session = session
        return session
        #else
        let session = AuthSession(uid: try devUID(), email: nil, displayName: "Dev User", provider: .apple)
        self.session = session
        return session
        #endif
    }

    func signInWithEmail(_ email: String, password: String) async throws -> AuthSession {
        #if canImport(FirebaseAuth)
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        let session = AuthSession(uid: result.user.uid, email: result.user.email, displayName: result.user.displayName, provider: .email)
        self.session = session
        return session
        #else
        let session = AuthSession(uid: try devUID(), email: email, displayName: nil, provider: .email)
        self.session = session
        return session
        #endif
    }

    func signOut() throws {
        #if canImport(FirebaseAuth)
        try Auth.auth().signOut()
        #endif
        session = nil
        userDefaults.removeObject(forKey: lastUIDKey)
    }

    // MARK: Dev fallback helpers

    private func devUID() throws -> String {
        if let s = session?.uid { return s }
        let uid = "dev_" + UUID().uuidString.lowercased()
        userDefaults.set(uid, forKey: lastUIDKey)
        return uid
    }

    private func makeDevToken(forceRefresh: Bool) throws -> String {
        // Synthesizes an unsigned dev token. The Worker should reject these in production
        // by enforcing real Firebase JWT verification — this is only for local development
        // before the FirebaseAuth SDK has been wired in.
        guard let session else { throw BiteAPIError.notAuthenticated }
        let now = Int(Date().timeIntervalSince1970)
        let payload: [String: Any] = [
            "iss": "bite-dev",
            "sub": session.uid,
            "iat": now,
            "exp": now + 3600,
            "dev": true,
        ]
        let header: [String: Any] = ["alg": "none", "typ": "JWT"]
        let h = try JSONSerialization.data(withJSONObject: header).base64URL
        let p = try JSONSerialization.data(withJSONObject: payload).base64URL
        return "\(h).\(p)."
    }

    #if canImport(FirebaseAuth)
    private static func provider(for user: User) -> AuthProvider {
        if let id = user.providerData.first?.providerID {
            switch id {
            case "apple.com": return .apple
            case "google.com": return .google
            case "password": return .email
            default: return .anonymous
            }
        }
        return .anonymous
    }
    #endif
}

private extension Data {
    var base64URL: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

/// Holds the nonce for Sign in with Apple between the request and the Firebase credential.
@MainActor
final class AppleSignInNonce {
    static let shared = AppleSignInNonce()
    private(set) var lastNonce: String?
    private init() {}
    func generate() -> String {
        let nonce = UUID().uuidString + "-" + UUID().uuidString
        lastNonce = nonce
        return nonce
    }
}
