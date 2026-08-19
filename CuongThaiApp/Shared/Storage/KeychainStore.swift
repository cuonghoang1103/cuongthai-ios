import Foundation
import Security
import os

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

    private static let log = Logger(subsystem: "com.cuongthai.app", category: "keychain")

    /// Mã lỗi của lần ghi gần nhất, `errSecSuccess` nếu ổn. Ghi Keychain hỏng
    /// là hỏng CÂM: phiên đăng nhập không được lưu, mở lại app là mất, mà
    /// không một dòng lỗi nào hiện ra. Giữ lại mã để nói được lý do.
    private(set) static var maLoiCuoi: OSStatus = errSecSuccess

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
        if updateStatus == errSecSuccess {
            maLoiCuoi = errSecSuccess
            return true
        }

        var insert = query
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(insert as CFDictionary, nil)
        maLoiCuoi = addStatus
        if addStatus != errSecSuccess {
            // -34018 errSecMissingEntitlement: bản dựng không có entitlement
            //        (hay gặp khi build với CODE_SIGNING_ALLOWED=NO).
            // -25300 errSecItemNotFound trên đường update là bình thường.
            log.error("Ghi Keychain '\(key, privacy: .public)' HỎNG: OSStatus \(addStatus, privacy: .public)")
            return false
        }
        return true
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

    /// Thử ghi–đọc–xoá một mục rác để biết Keychain có dùng được không.
    /// Trả về `nil` nếu ổn, hoặc mã lỗi để hiện cho người dùng.
    @discardableResult
    static func tuKiem() -> OSStatus? {
        let key = "__tu_kiem__"
        guard set("ok", for: key) else {
            log.error("Keychain KHÔNG dùng được — OSStatus \(maLoiCuoi, privacy: .public)")
            return maLoiCuoi
        }
        let docLai = get(key)
        delete(key)
        if docLai != "ok" {
            log.error("Keychain ghi được nhưng đọc lại KHÔNG khớp")
            return errSecIO
        }
        log.notice("Keychain dùng được")
        return nil
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
