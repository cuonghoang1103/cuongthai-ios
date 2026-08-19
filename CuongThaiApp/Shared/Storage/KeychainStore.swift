import Foundation
import Security

/// Keychain-backed storage for anything that must not sit in a plist.
///
/// WHY: auth tokens used to live in `UserDefaults`, which is an unencrypted
/// plist inside the app container — readable from a device backup and from
/// any jailbroken device. The Keychain is encrypted at rest and (with
/// `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`) never leaves the
/// device in an iCloud/iTunes backup.
///
/// Items are plain generic passwords under one service name, so a single
/// `wipe()` clears the whole session.
enum KeychainStore {
    private static let service = "com.cuongthai.app.secure"

    // MARK: - Write

    @discardableResult
    static func set(_ value: String?, for key: String) -> Bool {
        guard let value, !value.isEmpty else { return delete(key) }
        guard let data = value.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]

        // Update first — SecItemAdd fails with errSecDuplicateItem otherwise.
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return true }

        var insert = query
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(insert as CFDictionary, nil) == errSecSuccess
    }

    // MARK: - Read

    static func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8)
        else { return nil }
        return value
    }

    // MARK: - Delete

    @discardableResult
    static func delete(_ key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Remove every item this app wrote. Used on logout and on account erasure.
    static func wipe() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
