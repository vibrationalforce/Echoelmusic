import Foundation
import Security

/// Apple token manager implementing TN3194 requirements
///
/// **Purpose:** Securely store and manage Apple authentication tokens
///
/// **TN3194 Requirements:**
/// - Store identity_token, refresh_token, access_token
/// - Validate refresh_token daily
/// - Revoke tokens on account deletion
/// - Use secure storage (Keychain)
///
/// **Token Flow:**
/// 1. Initial auth: Get identity_token + authorization_code
/// 2. Exchange code: Get refresh_token + access_token
/// 3. Daily validation: Verify refresh_token
/// 4. On deletion: Revoke tokens via REST API
///
/// **Security:**
/// - Tokens stored in Keychain (kSecAttrAccessibleAfterFirstUnlock)
/// - Secure network communication (HTTPS only)
/// - Token encryption at rest
///
@MainActor
public class AppleTokenManager {

    // MARK: - Properties

    private let keychainService = "com.echoelmusic.apple.tokens"
    private let clientID = "com.echoelmusic.app" // Replace with your app's bundle ID
    private let teamID = "YOUR_TEAM_ID" // Replace with your Apple Developer Team ID
    private let keyID = "YOUR_KEY_ID" // Replace with your Sign in with Apple Key ID

    // Apple REST API endpoints
    private let tokenEndpoint = "https://appleid.apple.com/auth/token"
    private let revokeEndpoint = "https://appleid.apple.com/auth/revoke"

    // MARK: - Token Storage

    /// Store tokens securely in Keychain
    func storeTokens(identityToken: String, authorizationCode: String?) {
        // Store identity token
        saveToKeychain(key: "identityToken", value: identityToken)

        // Store authorization code (for token exchange)
        if let authCode = authorizationCode {
            saveToKeychain(key: "authorizationCode", value: authCode)
        }

        print("[AppleTokens] ✅ Tokens stored securely")
    }

    /// Store refresh and access tokens after exchange
    func storeRefreshAndAccessTokens(refreshToken: String, accessToken: String) {
        saveToKeychain(key: "refreshToken", value: refreshToken)
        saveToKeychain(key: "accessToken", value: accessToken)

        print("[AppleTokens] ✅ Refresh and access tokens stored")
    }

    /// Clear all tokens
    func clearTokens() {
        deleteFromKeychain(key: "identityToken")
        deleteFromKeychain(key: "authorizationCode")
        deleteFromKeychain(key: "refreshToken")
        deleteFromKeychain(key: "accessToken")

        print("[AppleTokens] 🗑️ All tokens cleared")
    }

    // MARK: - Token Exchange (TN3194 Step 2)

    /// Exchange authorization code for refresh and access tokens
    func exchangeAuthorizationCode(_ authorizationCode: String) async throws {
        // Create client secret (JWT signed with your private key)
        // This requires your Sign in with Apple private key
        // For now, we'll store tokens when we get them

        let url = URL(string: tokenEndpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "client_id": clientID,
            "client_secret": createClientSecret(), // Requires private key
            "code": authorizationCode,
            "grant_type": "authorization_code"
        ]

        request.httpBody = body.percentEncoded()

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw TokenError.exchangeFailed
            }

            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

            // Store refresh and access tokens (TN3194 requirement)
            storeRefreshAndAccessTokens(
                refreshToken: tokenResponse.refresh_token,
                accessToken: tokenResponse.access_token
            )

            print("[AppleTokens] ✅ Authorization code exchanged successfully")

        } catch {
            print("[AppleTokens] ❌ Token exchange failed: \(error)")
            throw error
        }
    }

    // MARK: - Token Validation (TN3194 Step 3)

    /// Validate refresh token with Apple (call daily)
    func validateRefreshToken() async throws {
        guard let refreshToken = loadFromKeychain(key: "refreshToken") else {
            throw TokenError.missingRefreshToken
        }

        let url = URL(string: tokenEndpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "client_id": clientID,
            "client_secret": createClientSecret(),
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]

        request.httpBody = body.percentEncoded()

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw TokenError.validationFailed
            }

            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

            // Update tokens
            storeRefreshAndAccessTokens(
                refreshToken: refreshToken, // Keep same refresh token
                accessToken: tokenResponse.access_token // New access token
            )

            print("[AppleTokens] ✅ Refresh token validated")

        } catch {
            print("[AppleTokens] ❌ Token validation failed: \(error)")
            throw error
        }
    }

    // MARK: - Token Revocation (TN3194 Step 4)

    /// Revoke tokens with Apple (on account deletion)
    func revokeTokens() async throws {
        // Try to revoke with refresh token first (preferred)
        if let refreshToken = loadFromKeychain(key: "refreshToken") {
            try await revokeToken(refreshToken, tokenType: "refresh_token")
            return
        }

        // Fallback to access token
        if let accessToken = loadFromKeychain(key: "accessToken") {
            try await revokeToken(accessToken, tokenType: "access_token")
            return
        }

        // No tokens available
        print("[AppleTokens] ⚠️ No tokens to revoke")
    }

    private func revokeToken(_ token: String, tokenType: String) async throws {
        let url = URL(string: revokeEndpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "client_id": clientID,
            "client_secret": createClientSecret(),
            "token": token,
            "token_type_hint": tokenType
        ]

        request.httpBody = body.percentEncoded()

        do {
            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw TokenError.revocationFailed
            }

            print("[AppleTokens] ✅ Token revoked successfully")

        } catch {
            print("[AppleTokens] ❌ Token revocation failed: \(error)")
            throw error
        }
    }

    // MARK: - Client Secret Generation

    /// Create JWT client secret (requires private key from Apple Developer)
    private func createClientSecret() -> String {
        // TODO: Implement JWT signing with your private key
        // This requires:
        // 1. Download private key from Apple Developer portal
        // 2. Sign JWT with ES256 algorithm
        // 3. Include headers: kid, alg
        // 4. Include payload: iss (team ID), iat, exp, aud, sub (client ID)

        // For now, return placeholder
        // In production, use a JWT library like SwiftJWT
        return "YOUR_CLIENT_SECRET"
    }

    // MARK: - Keychain Operations

    private func saveToKeychain(key: String, value: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: value.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        // Delete existing item
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)

        if status != errSecSuccess {
            print("[AppleTokens] ⚠️ Keychain save failed: \(status)")
        }
    }

    private func loadFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Supporting Types

struct TokenResponse: Codable {
    let access_token: String
    let token_type: String
    let expires_in: Int
    let refresh_token: String
    let id_token: String?
}

enum TokenError: LocalizedError {
    case missingRefreshToken
    case exchangeFailed
    case validationFailed
    case revocationFailed

    var errorDescription: String? {
        switch self {
        case .missingRefreshToken:
            return "Refresh token not found"
        case .exchangeFailed:
            return "Failed to exchange authorization code"
        case .validationFailed:
            return "Failed to validate refresh token"
        case .revocationFailed:
            return "Failed to revoke token"
        }
    }
}

// MARK: - Dictionary Extension

extension Dictionary {
    func percentEncoded() -> Data? {
        map { key, value in
            let escapedKey = "\(key)".addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? ""
            let escapedValue = "\(value)".addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? ""
            return "\(escapedKey)=\(escapedValue)"
        }
        .joined(separator: "&")
        .data(using: .utf8)
    }
}

extension CharacterSet {
    static let urlQueryValueAllowed: CharacterSet = {
        let generalDelimitersToEncode = ":#[]@" // does not include "?" or "/" due to RFC 3986 - Section 3.4
        let subDelimitersToEncode = "!$&'()*+,;="
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "\(generalDelimitersToEncode)\(subDelimitersToEncode)")
        return allowed
    }()
}
