import Foundation
import Security

/// The stream keys, one per destination, in the keychain (wave W14). A key is a password to the
/// musician's channel, so it lives only here: never in a song, never in `UserDefaults`, never in
/// the diagnostic log. Kept on this device only (`ThisDeviceOnly`, no iCloud keychain sync) and
/// readable after the first unlock, so a stream started from the lock screen's audio controls
/// still finds it.
enum StreamKeyStore {
    private static let service = "com.echoelmusic.app.stream-key"

    /// The key of the destination `id`; nil when none is stored or the keychain refuses.
    static func key(for id: UUID) -> String? {
        var query = baseQuery(id)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Whether a key is stored, without reading it out.
    static func hasKey(for id: UUID) -> Bool {
        var query = baseQuery(id)
        query[kSecReturnData as String] = false
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    /// Stores `key` for `id`, replacing the one before; an empty key removes it. False when the
    /// keychain refused, so the page can say the key was not kept.
    @discardableResult
    static func setKey(_ key: String, for id: UUID) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return removeKey(for: id) }
        let data = Data(trimmed.utf8)
        let update: [String: Any] = [kSecValueData as String: data,
                                     kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let status = SecItemUpdate(baseQuery(id) as CFDictionary, update as CFDictionary)
        if status == errSecSuccess { return true }
        guard status == errSecItemNotFound else { return false }
        var add = baseQuery(id)
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    /// Removes the key of `id` (the destination was deleted, or its key cleared).
    @discardableResult
    static func removeKey(for id: UUID) -> Bool {
        let status = SecItemDelete(baseQuery(id) as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    private static func baseQuery(_ id: UUID) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: id.uuidString,
         kSecAttrSynchronizable as String: false]
    }
}
