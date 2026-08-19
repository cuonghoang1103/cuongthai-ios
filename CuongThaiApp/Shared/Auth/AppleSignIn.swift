import SwiftUI
import AuthenticationServices

// MARK: - Sign in with Apple
//
// App Store Guideline 4.8 ("Login Services"): an app that offers any
// third-party login (this backend supports Google + GitHub) must also offer
// a privacy-preserving option. Sign in with Apple is that option, and it is
// the one reviewers look for.
//
// Flow: Apple returns a stable `user` id plus — on the FIRST authorization
// only — the e-mail and name. The backend's /auth/oauth/token keys accounts
// by e-mail, so we recover the address in this order:
//   1. `credential.email`            (first sign-in, or when Apple resends it)
//   2. the `email` claim inside the identity token JWT
//   3. the Keychain copy saved on a previous sign-in
// If all three are empty the user has revoked e-mail sharing entirely and we
// surface a readable error instead of a silent failure.
//
// NOTE for the backend (not changed here, on purpose): /auth/oauth/token
// trusts the e-mail + providerId the client sends. We already ship
// `identityToken` and `authorizationCode` in the same payload so the server
// can start verifying Apple's signature without any app update.

enum AppleSignInError: LocalizedError {
    case cancelled
    case noEmail
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Đã huỷ đăng nhập bằng Apple"
        case .noEmail:
            return "Apple không chia sẻ email cho ứng dụng. Vào Cài đặt → Apple ID → Đăng nhập bằng Apple → CuongThai → Ngừng sử dụng, rồi thử lại."
        case .failed(let message):
            return message
        }
    }
}

struct AppleSignInService {
    /// Turn an Apple credential into a backend session.
    static func authenticate(with credential: ASAuthorizationAppleIDCredential) async throws -> AuthResponse {
        let userId = credential.user
        let identityToken = credential.identityToken.flatMap { String(data: $0, encoding: .utf8) }
        let authCode = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }

        let email = credential.email
            ?? identityToken.flatMap { claim("email", in: $0) }
            ?? StorageManager.shared.appleEmail(for: userId)

        guard let email, !email.isEmpty else { throw AppleSignInError.noEmail }

        // Apple sends the name once, at first authorization.
        let fullName: String? = {
            guard let name = credential.fullName else { return nil }
            let parts = [name.familyName, name.givenName].compactMap { $0 }
            let joined = parts.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            return joined.isEmpty ? nil : joined
        }()

        StorageManager.shared.saveAppleIdentity(userId: userId, email: email)

        var payload: [String: Any] = [
            "email": email,
            "provider": "apple",
            "providerId": userId,
        ]
        if let fullName { payload["fullName"] = fullName }
        if let identityToken { payload["identityToken"] = identityToken }
        if let authCode { payload["authorizationCode"] = authCode }

        return try await APIClient.shared.request(.oauthToken(payload))
    }

    /// Decode one claim out of a JWT payload without validating the signature.
    /// Only used to read the e-mail Apple embedded in its own token; the token
    /// itself is forwarded to the backend for real verification.
    private static func claim(_ name: String, in jwt: String) -> String? {
        let segments = jwt.split(separator: ".")
        guard segments.count > 1 else { return nil }

        var base64 = String(segments[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        // base64url drops the padding; Data(base64Encoded:) requires it.
        let remainder = base64.count % 4
        if remainder > 0 { base64 += String(repeating: "=", count: 4 - remainder) }

        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return json[name] as? String
    }
}

// MARK: - Button

struct AppleSignInButton: View {
    let onSignedIn: (AuthResponse) -> Void
    let onError: (String) -> Void

    var body: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.fullName, .email]
        } onCompletion: { result in
            switch result {
            case .success(let auth):
                guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                    onError(AppleSignInError.failed("Không đọc được thông tin từ Apple").localizedDescription)
                    return
                }
                Task {
                    do {
                        let response = try await AppleSignInService.authenticate(with: credential)
                        await MainActor.run { onSignedIn(response) }
                    } catch {
                        await MainActor.run { onError(error.localizedDescription) }
                    }
                }
            case .failure(let error):
                // A user tapping "Cancel" is not an error worth showing.
                if (error as NSError).code == ASAuthorizationError.canceled.rawValue { return }
                onError(error.localizedDescription)
            }
        }
        .signInWithAppleButtonStyle(.white)
        .frame(height: 48)
        .cornerRadius(CornerRadius.medium)
    }
}
