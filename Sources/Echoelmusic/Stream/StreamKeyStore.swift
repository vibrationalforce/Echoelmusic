//
//  StreamKeyStore.swift
//  Echoelmusic — Stream
//
//  Where the broadcast stream key lives: the Keychain, never UserDefaults (Broadcast S1).
//
//  A stream key is a credential — whoever holds it can publish to the owner's channel. Until
//  this slice it sat in `UserDefaults` under `broadcast.streamKey`, i.e. in a plaintext plist
//  inside the app container and in every device backup. It now lives in a generic-password
//  Keychain item with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`: readable only while the
//  phone is unlocked, and never migrated to another device by a backup restore.
//
//  MIGRATION RULE (one pass, at `BroadcastPublisher.init`): a key left in UserDefaults by an
//  older build is copied into the Keychain and then deleted from UserDefaults. If the Keychain
//  write FAILS, the old value stays where it is — losing a user's key to a transient Keychain
//  error is worse than keeping it one more launch in the old place; the next launch retries.
//  If the Keychain already holds a key, the Keychain wins and the stale copy is deleted.
//
//  NEVER LOGGED: nothing in this file writes to any log, and the key never appears in a
//  status message. `TheStreamKeyLivesInTheKeychainTests` pins both.
//

import Foundation
#if canImport(Security)
import Security
#endif

/// One secret value behind a narrow read/write/delete seam, so the migration rule can be
/// driven in a test without touching the real Keychain.
protocol StreamSecretStore: AnyObject {
    /// The stored secret, or `nil` when there is none (or it cannot be read).
    func read() -> String?
    /// Stores the secret, replacing any previous one. Returns `false` on failure.
    @discardableResult func write(_ secret: String) -> Bool
    /// Removes the secret. Returns `false` on failure (a missing item is success).
    @discardableResult func delete() -> Bool
}

/// The Keychain-backed store the app uses.
final class KeychainStreamSecretStore: StreamSecretStore {

    private let service: String
    private let account: String

    init(service: String = "com.echoelmusic.broadcast", account: String = "streamKey") {
        self.service = service
        self.account = account
    }

    #if canImport(Security)
    private var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    func read() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    func write(_ secret: String) -> Bool {
        guard !secret.isEmpty else { return delete() }
        let data = Data(secret.utf8)
        let update: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        let status = SecItemUpdate(baseQuery as CFDictionary, update as CFDictionary)
        if status == errSecSuccess { return true }
        guard status == errSecItemNotFound else { return false }
        var add = baseQuery
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    @discardableResult
    func delete() -> Bool {
        let status = SecItemDelete(baseQuery as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    #else
    // No Keychain on this platform: hold nothing rather than fall back to plaintext.
    func read() -> String? { nil }
    @discardableResult func write(_ secret: String) -> Bool { false }
    @discardableResult func delete() -> Bool { true }
    #endif
}

/// The one-pass move of a legacy UserDefaults stream key into the secret store.
enum StreamKeyMigration {

    /// The UserDefaults key older builds wrote the stream key under.
    static let legacyDefaultsKey = "broadcast.streamKey"

    /// Returns the stream key to use, moving a legacy UserDefaults copy into `store` on the way.
    static func loadMigrating(defaults: UserDefaults,
                              store: StreamSecretStore,
                              legacyKey: String = legacyDefaultsKey) -> String {
        let stored = store.read() ?? ""
        guard let legacy = defaults.string(forKey: legacyKey) else { return stored }
        if !stored.isEmpty || legacy.isEmpty {
            // The Keychain already holds a key (it wins), or the legacy copy is empty.
            defaults.removeObject(forKey: legacyKey)
            return stored
        }
        guard store.write(legacy) else {
            // Keep the legacy copy: a failed Keychain write must not lose the user's key.
            return legacy
        }
        defaults.removeObject(forKey: legacyKey)
        return legacy
    }
}
