import Foundation

// MARK: - Storage Manager
//
// Auth tokens live in the Keychain (see KeychainStore). Non-secret UI cache
// (the last-known profile, the EULA acceptance flag) stays in UserDefaults.
//
// Builds up to 1.0.0 wrote the tokens into UserDefaults; `migrateLegacyTokens()`
// moves them once on first launch of this build so existing users are not
// silently logged out, then scrubs the plist copy.
final class StorageManager: @unchecked Sendable {
    static let shared = StorageManager()

    private let defaults = UserDefaults.standard
    private let prefix = "com.cuongthai.app."

    private enum Key {
        static let token = "auth_token"
        static let refresh = "refresh_token"
        /// Apple only returns the e-mail on the FIRST authorization, so we cache
        /// it to keep repeat Sign in with Apple logins working.
        static let appleEmail = "apple_email"
        static let appleUserId = "apple_user_id"
    }

    private init() { migrateLegacyTokens() }

    // MARK: - Auth tokens (Keychain)

    func saveAuthToken(_ token: String, refreshToken: String? = nil) {
        KeychainStore.set(token, for: Key.token)
        if let refresh = refreshToken {
            KeychainStore.set(refresh, for: Key.refresh)
        }
    }

    func getAuthToken() -> String? { KeychainStore.get(Key.token) }

    func getRefreshToken() -> String? { KeychainStore.get(Key.refresh) }

    func clearAuthTokens() {
        KeychainStore.delete(Key.token)
        KeychainStore.delete(Key.refresh)
    }

    // MARK: - Sign in with Apple identity cache (Keychain)

    func saveAppleIdentity(userId: String, email: String?) {
        KeychainStore.set(userId, for: Key.appleUserId)
        if let email, !email.isEmpty {
            KeychainStore.set(email, for: Key.appleEmail)
        }
    }

    /// The e-mail we recorded for this Apple user id, if any.
    func appleEmail(for userId: String) -> String? {
        guard KeychainStore.get(Key.appleUserId) == userId else { return nil }
        return KeychainStore.get(Key.appleEmail)
    }

    // MARK: - Profile cache (UserDefaults — not secret, re-fetched on launch)

    func saveCurrentUser(_ user: User) {
        if let data = try? JSONEncoder().encode(user) {
            defaults.set(data, forKey: prefix + "current_user")
        }
    }

    func getCurrentUser() -> User? {
        guard let data = defaults.data(forKey: prefix + "current_user") else { return nil }
        return try? JSONDecoder().decode(User.self, from: data)
    }

    func clearCurrentUser() {
        defaults.removeObject(forKey: prefix + "current_user")
    }

    // MARK: - EULA acceptance (App Store Guideline 1.2)

    var hasAcceptedTerms: Bool {
        get { defaults.bool(forKey: prefix + "terms_accepted_v1") }
        set { defaults.set(newValue, forKey: prefix + "terms_accepted_v1") }
    }

    // MARK: - Wipe

    func clearAll() {
        clearAuthTokens()
        clearCurrentUser()
    }

    /// Full erasure — used after the account-deletion request is filed and the
    /// user signs out for good.
    func wipeEverything() {
        KeychainStore.wipe()
        clearCurrentUser()
        defaults.removeObject(forKey: prefix + "blocked_user_ids")
        defaults.removeObject(forKey: prefix + "hidden_post_ids")
    }

    // MARK: - Legacy migration

    private func migrateLegacyTokens() {
        let legacyToken = prefix + "auth_token"
        let legacyRefresh = prefix + "refresh_token"
        if let token = defaults.string(forKey: legacyToken) {
            if KeychainStore.get(Key.token) == nil {
                KeychainStore.set(token, for: Key.token)
                KeychainStore.set(defaults.string(forKey: legacyRefresh), for: Key.refresh)
            }
            defaults.removeObject(forKey: legacyToken)
            defaults.removeObject(forKey: legacyRefresh)
        }
    }
}
