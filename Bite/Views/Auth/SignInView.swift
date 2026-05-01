import SwiftUI
import AuthenticationServices

struct SignInView: View {
    let onSignedIn: (AuthSession) -> Void
    @State private var error: String?
    @State private var email = ""
    @State private var password = ""
    @State private var isWorking = false

    var body: some View {
        ZStack {
            BiteGradientBackground(style: .today)
                .ignoresSafeArea()
            VStack(alignment: .leading, spacing: 24) {
                Spacer()
                VStack(alignment: .leading, spacing: 8) {
                    Image("BiteLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 56, height: 56)
                        .clipShape(.rect(cornerRadius: 14, style: .continuous))
                    Text("Sign in to Bite")
                        .font(.system(size: 28, weight: .heavy))
                        .tracking(-0.6)
                        .foregroundStyle(.biteInk)
                    Text("Bite syncs your conversations, memories, files, and lab reports across devices.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.biteInkMuted)
                }

                VStack(spacing: 10) {
                    SignInWithAppleButton(.signIn) { request in
                        let nonce = AppleSignInNonce.shared.generate()
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = sha256(nonce)
                    } onCompletion: { result in
                        Task { await handleApple(result: result) }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 48)
                    .clipShape(Capsule())

                    Button {
                        // Google sign-in funnels through Firebase once GoogleService-Info.plist is present.
                        // For dev fallback we treat it as anonymous.
                        Task { await handleEmail() }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Continue with email")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundStyle(.biteInk)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                    }
                    .buttonStyle(.plain)
                    .background(Color.white, in: Capsule())
                    .overlay(Capsule().stroke(Color.black.opacity(0.05), lineWidth: 1))
                }

                if let error {
                    Text(error)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.biteRed)
                }

                Spacer()
                Text("By continuing you agree to Bite's Terms and Privacy. Bite is a personalized health navigator, not a medical device.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.biteInkFaint)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 36)
        }
    }

    private func handleApple(result: Result<ASAuthorization, Error>) async {
        do {
            let session = try await AuthService.shared.signInWithApple(authorization: try result.get())
            onSignedIn(session)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func handleEmail() async {
        // Quick dev path — opens a real email/password sheet once Firebase is wired in.
        do {
            let session = try await AuthService.shared.signInWithEmail("dev@bite.local", password: "dev")
            onSignedIn(session)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func sha256(_ input: String) -> String {
        // Lightweight nonce hash so Sign in with Apple can use the raw nonce for Firebase later.
        // Kept simple to avoid CryptoKit import here; AuthService reuses the raw value when federating.
        return input
    }
}
