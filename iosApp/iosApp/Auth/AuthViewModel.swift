import AuthenticationServices
import CryptoKit
import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isLoading       = false
    @Published var errorMessage    = ""
    @Published var showError       = false
    @Published var isAuthenticated = false

    // Stored so Apple callback can reference it
    private var currentNonce: String?

    // MARK: - Email / Password

    func signIn(email: String, password: String) async {
        await run {
            try await SupabaseService.shared.signIn(email: email, password: password)
            self.isAuthenticated = true
        }
    }

    func signUp(email: String, password: String) async {
        await run {
            try await SupabaseService.shared.signUp(email: email, password: password)
            // Show "check your email" — don't mark authenticated yet
            self.errorMessage = "Check your email to confirm your account."
            self.showError    = true
        }
    }

    // MARK: - Sign in with Apple

    func handleAppleCredential(_ credential: ASAuthorizationAppleIDCredential) async {
        guard
            let tokenData = credential.identityToken,
            let idToken   = String(data: tokenData, encoding: .utf8),
            let nonce     = currentNonce
        else {
            fail("Apple sign-in failed: missing token.")
            return
        }

        let fullName = [
            credential.fullName?.givenName,
            credential.fullName?.familyName
        ].compactMap { $0 }.joined(separator: " ")

        await run {
            try await SupabaseService.shared.signInWithApple(
                idToken:  idToken,
                nonce:    nonce,
                fullName: fullName.isEmpty ? nil : fullName
            )
            self.isAuthenticated = true
        }
    }

    func prepareAppleRequest(_ request: ASAuthorizationOpenIDRequest) {
        let nonce       = randomNonce()
        currentNonce    = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce   = sha256(nonce)
    }

    // MARK: - Helpers

    private func run(_ block: @escaping () async throws -> Void) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await block()
        } catch {
            fail(error.localizedDescription)
        }
    }

    private func fail(_ msg: String) {
        errorMessage = msg
        showError    = true
    }

    // MARK: - Nonce

    private func randomNonce(length: Int = 32) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    private func sha256(_ input: String) -> String {
        let data   = Data(input.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
