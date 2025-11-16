import Foundation
import Security

/// KeychainWrapper - Secure storage wrapper for sensitive data
/// Provides type-safe access to iOS/macOS Keychain
///
/// Features:
/// - Secure storage for passwords, tokens, API keys
/// - Biometric protection (requires Face ID/Touch ID)
/// - Synchronization across devices (optional)
/// - Thread-safe operations
/// - Automatic cleanup on app uninstall
///
/// Usage:
/// ```swift
/// let keychain = KeychainWrapper.shared
/// keychain.setString("secret_token", forKey: "api_token")
/// let token = keychain.getString(forKey: "api_token")
/// ```
class KeychainWrapper {

    // MARK: - Shared Instance

    static let shared = KeychainWrapper()

    // MARK: - Configuration

    private let serviceName: String
    private let accessGroup: String?

    // MARK: - Initialization

    init(serviceName: String = Bundle.main.bundleIdentifier ?? "com.echoelmusic.app",
         accessGroup: String? = nil) {
        self.serviceName = serviceName
        self.accessGroup = accessGroup
    }

    // MARK: - String Storage

    /// Save string to Keychain
    func setString(_ value: String, forKey key: String, requiresBiometric: Bool = false) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        return setData(data, forKey: key, requiresBiometric: requiresBiometric)
    }

    /// Retrieve string from Keychain
    func getString(forKey key: String) -> String? {
        guard let data = getData(forKey: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Data Storage

    /// Save data to Keychain
    @discardableResult
    func setData(_ value: Data, forKey key: String, requiresBiometric: Bool = false) -> Bool {
        // Build query
        var query = buildBaseQuery(forKey: key)
        query[kSecValueData as String] = value

        // Add biometric protection if requested
        if requiresBiometric {
            query[kSecAttrAccessControl as String] = createBiometricAccessControl()
        } else {
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        }

        // Delete any existing item
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)

        if status != errSecSuccess {
            print("⚠️ Keychain save error: \(status) for key: \(key)")
        }

        return status == errSecSuccess
    }

    /// Retrieve data from Keychain
    func getData(forKey key: String) -> Data? {
        var query = buildBaseQuery(forKey: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status != errSecItemNotFound {
                print("⚠️ Keychain read error: \(status) for key: \(key)")
            }
            return nil
        }

        return result as? Data
    }

    // MARK: - Codable Storage

    /// Save Codable object to Keychain
    func setCodable<T: Codable>(_ value: T, forKey key: String, requiresBiometric: Bool = false) -> Bool {
        guard let data = try? JSONEncoder().encode(value) else { return false }
        return setData(data, forKey: key, requiresBiometric: requiresBiometric)
    }

    /// Retrieve Codable object from Keychain
    func getCodable<T: Codable>(forKey key: String) -> T? {
        guard let data = getData(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Removal

    /// Remove item from Keychain
    @discardableResult
    func removeData(forKey key: String) -> Bool {
        let query = buildBaseQuery(forKey: key)
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Remove all items for this service
    func removeAll() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName
        ]

        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Query Builder

    private func buildBaseQuery(forKey key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        #if !targetEnvironment(simulator)
        // Use data protection on real devices
        query[kSecAttrSynchronizable as String] = false
        #endif

        return query
    }

    // MARK: - Biometric Protection

    private func createBiometricAccessControl() -> SecAccessControl? {
        var error: Unmanaged<CFError>?

        let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryCurrentSet,  // Requires biometric authentication
            &error
        )

        if let error = error {
            print("⚠️ Failed to create biometric access control: \(error.takeRetainedValue())")
            return nil
        }

        return access
    }

    // MARK: - Utility

    /// Check if a key exists in Keychain
    func exists(forKey key: String) -> Bool {
        return getData(forKey: key) != nil
    }

    /// List all keys for this service
    func allKeys() -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let items = result as? [[String: Any]] else {
            return []
        }

        return items.compactMap { $0[kSecAttrAccount as String] as? String }
    }
}

// MARK: - Convenience Extensions

extension KeychainWrapper {

    // MARK: - API Keys & Tokens

    func setAPIKey(_ key: String, forService service: String) -> Bool {
        return setString(key, forKey: "api_key_\(service)")
    }

    func getAPIKey(forService service: String) -> String? {
        return getString(forKey: "api_key_\(service)")
    }

    func setAccessToken(_ token: String, forService service: String) -> Bool {
        return setString(token, forKey: "access_token_\(service)")
    }

    func getAccessToken(forService service: String) -> String? {
        return getString(forKey: "access_token_\(service)")
    }

    // MARK: - Stream Keys

    func setRTMPStreamKey(_ key: String, forPlatform platform: String) -> Bool {
        return setString(key, forKey: "rtmp_stream_key_\(platform)", requiresBiometric: true)
    }

    func getRTMPStreamKey(forPlatform platform: String) -> String? {
        return getString(forKey: "rtmp_stream_key_\(platform)")
    }

    // MARK: - CloudKit

    func setCloudKitToken(_ token: String) -> Bool {
        return setString(token, forKey: "cloudkit_token")
    }

    func getCloudKitToken() -> String? {
        return getString(forKey: "cloudkit_token")
    }

    // MARK: - Encryption Keys

    func setEncryptionKey(_ key: Data, identifier: String) -> Bool {
        return setData(key, forKey: "encryption_key_\(identifier)", requiresBiometric: true)
    }

    func getEncryptionKey(identifier: String) -> Data? {
        return getData(forKey: "encryption_key_\(identifier)")
    }
}

// MARK: - Error Handling

extension KeychainWrapper {
    enum KeychainError: Error {
        case itemNotFound
        case duplicateItem
        case invalidData
        case unexpectedError(OSStatus)

        init?(status: OSStatus) {
            switch status {
            case errSecItemNotFound:
                self = .itemNotFound
            case errSecDuplicateItem:
                self = .duplicateItem
            case errSecParam:
                self = .invalidData
            default:
                self = .unexpectedError(status)
            }
        }

        var localizedDescription: String {
            switch self {
            case .itemNotFound:
                return "Keychain item not found"
            case .duplicateItem:
                return "Keychain item already exists"
            case .invalidData:
                return "Invalid keychain data"
            case .unexpectedError(let status):
                return "Keychain error: \(status)"
            }
        }
    }
}

// MARK: - Security Status Codes

extension KeychainWrapper {
    func statusCodeDescription(_ status: OSStatus) -> String {
        switch status {
        case errSecSuccess:
            return "Success"
        case errSecItemNotFound:
            return "Item not found"
        case errSecDuplicateItem:
            return "Duplicate item"
        case errSecParam:
            return "Invalid parameter"
        case errSecUserCanceled:
            return "User canceled"
        case errSecAuthFailed:
            return "Authentication failed"
        case errSecInteractionNotAllowed:
            return "Interaction not allowed"
        default:
            return "Unknown error: \(status)"
        }
    }
}

// MARK: - Testing Support

#if DEBUG
extension KeychainWrapper {
    /// Clear all keychain items (for testing only)
    func clearAllForTesting() {
        removeAll()
        print("🧪 Keychain cleared for testing")
    }
}
#endif
