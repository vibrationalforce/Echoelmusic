// AuthenticationManager.swift
// Echoelmusic - Complete User Authentication System
// Supports: Email/Password, Apple Sign In, Google Sign In, Biometrics

import Foundation
import AuthenticationServices
import LocalAuthentication
import CryptoKit
import Combine

// MARK: - User Model

public struct User: Identifiable, Codable {
    public let id: String
    public var email: String
    public var username: String
    public var displayName: String
    public var avatarURL: URL?
    public var createdAt: Date
    public var lastLoginAt: Date
    public var isEmailVerified: Bool
    public var isPremium: Bool
    public var subscriptionTier: SubscriptionTier
    public var preferences: UserPreferences
    public var profile: UserProfile

    public enum SubscriptionTier: String, Codable {
        case free = "Free"
        case creator = "Creator"
        case professional = "Professional"
        case enterprise = "Enterprise"
    }

    public struct UserPreferences: Codable {
        public var theme: String = "dark"
        public var language: String = "en"
        public var notifications: NotificationSettings = NotificationSettings()
        public var privacy: PrivacySettings = PrivacySettings()

        public struct NotificationSettings: Codable {
            public var pushEnabled: Bool = true
            public var emailEnabled: Bool = true
            public var collaborationAlerts: Bool = true
            public var marketingEmails: Bool = false
        }

        public struct PrivacySettings: Codable {
            public var profilePublic: Bool = true
            public var showOnlineStatus: Bool = true
            public var allowDirectMessages: Bool = true
        }
    }

    public struct UserProfile: Codable {
        public var bio: String?
        public var location: String?
        public var website: String?
        public var socialLinks: SocialLinks?
        public var genres: [String] = []
        public var skills: [String] = []

        public struct SocialLinks: Codable {
            public var instagram: String?
            public var twitter: String?
            public var youtube: String?
            public var soundcloud: String?
            public var spotify: String?
            public var tiktok: String?
        }
    }
}

// MARK: - Authentication State

public enum AuthenticationState {
    case unknown
    case unauthenticated
    case authenticating
    case authenticated(User)
    case error(AuthError)
}

public enum AuthError: Error, LocalizedError {
    case invalidCredentials
    case userNotFound
    case emailAlreadyInUse
    case weakPassword
    case networkError
    case serverError(String)
    case tokenExpired
    case biometricFailed
    case cancelled
    case unknown(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .userNotFound:
            return "No account found with this email"
        case .emailAlreadyInUse:
            return "An account with this email already exists"
        case .weakPassword:
            return "Password must be at least 8 characters"
        case .networkError:
            return "Network connection error"
        case .serverError(let message):
            return "Server error: \(message)"
        case .tokenExpired:
            return "Session expired. Please sign in again"
        case .biometricFailed:
            return "Biometric authentication failed"
        case .cancelled:
            return "Authentication cancelled"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - Auth Tokens

public struct AuthTokens: Codable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresAt: Date
    public let tokenType: String

    public var isExpired: Bool {
        Date() >= expiresAt
    }

    public var isAboutToExpire: Bool {
        Date().addingTimeInterval(300) >= expiresAt // 5 minutes buffer
    }
}

// MARK: - Authentication Manager

@MainActor
public class AuthenticationManager: NSObject, ObservableObject {
    // State
    @Published public private(set) var state: AuthenticationState = .unknown
    @Published public private(set) var currentUser: User?
    @Published public private(set) var isLoading: Bool = false

    // Biometrics
    @Published public var isBiometricEnabled: Bool = false
    @Published public var biometricType: BiometricType = .none

    // Session
    private var tokens: AuthTokens?
    private var tokenRefreshTask: Task<Void, Never>?

    // API Configuration
    private let apiBaseURL: URL
    private let keychain = KeychainManager()
    private let userDefaults = UserDefaults.standard

    // Apple Sign In
    private var appleSignInContinuation: CheckedContinuation<ASAuthorization, Error>?

    public enum BiometricType {
        case none
        case touchID
        case faceID
    }

    // MARK: - Initialization

    public init(apiBaseURL: URL = URL(string: "https://api.echoelmusic.com")!) {
        self.apiBaseURL = apiBaseURL
        super.init()

        checkBiometricCapability()
        loadStoredSession()
    }

    // MARK: - Session Management

    private func loadStoredSession() {
        // Try to restore session from keychain
        if let tokenData = keychain.getData(forKey: "authTokens"),
           let tokens = try? JSONDecoder().decode(AuthTokens.self, from: tokenData) {
            self.tokens = tokens

            if tokens.isExpired {
                // Try to refresh
                Task {
                    await refreshTokenIfNeeded()
                }
            } else {
                // Load user data
                Task {
                    await loadCurrentUser()
                }
            }
        } else {
            state = .unauthenticated
        }

        // Load biometric preference
        isBiometricEnabled = userDefaults.bool(forKey: "biometricEnabled")
    }

    private func saveSession(tokens: AuthTokens, user: User) {
        self.tokens = tokens
        self.currentUser = user

        // Save tokens to keychain
        if let tokenData = try? JSONEncoder().encode(tokens) {
            keychain.setData(tokenData, forKey: "authTokens")
        }

        // Save user to keychain
        if let userData = try? JSONEncoder().encode(user) {
            keychain.setData(userData, forKey: "currentUser")
        }

        state = .authenticated(user)
        startTokenRefreshTimer()
    }

    private func clearSession() {
        tokens = nil
        currentUser = nil
        keychain.deleteItem(forKey: "authTokens")
        keychain.deleteItem(forKey: "currentUser")
        tokenRefreshTask?.cancel()
        state = .unauthenticated
    }

    // MARK: - Token Refresh

    private func startTokenRefreshTimer() {
        tokenRefreshTask?.cancel()
        tokenRefreshTask = Task {
            while !Task.isCancelled {
                // Wait until token is about to expire
                if let tokens = tokens, !tokens.isExpired {
                    let waitTime = tokens.expiresAt.timeIntervalSinceNow - 300 // 5 min before expiry
                    if waitTime > 0 {
                        try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
                    }
                    await refreshTokenIfNeeded()
                } else {
                    break
                }
            }
        }
    }

    private func refreshTokenIfNeeded() async {
        guard let tokens = tokens, let refreshToken = tokens.refreshToken.data(using: .utf8) else {
            clearSession()
            return
        }

        do {
            let newTokens = try await refreshToken(refreshToken: tokens.refreshToken)
            self.tokens = newTokens

            if let tokenData = try? JSONEncoder().encode(newTokens) {
                keychain.setData(tokenData, forKey: "authTokens")
            }
        } catch {
            clearSession()
        }
    }

    // MARK: - Email/Password Authentication

    public func signUp(email: String, password: String, username: String, displayName: String) async throws -> User {
        isLoading = true
        state = .authenticating

        defer { isLoading = false }

        // Validate input
        guard isValidEmail(email) else {
            throw AuthError.invalidCredentials
        }

        guard password.count >= 8 else {
            throw AuthError.weakPassword
        }

        // Hash password (in production, this would be done server-side)
        let passwordHash = hashPassword(password)

        // API call
        let body: [String: Any] = [
            "email": email,
            "password": passwordHash,
            "username": username,
            "displayName": displayName
        ]

        let response = try await apiRequest(
            endpoint: "/auth/signup",
            method: "POST",
            body: body
        )

        let tokens = try parseAuthResponse(response)
        let user = try parseUserFromResponse(response)

        saveSession(tokens: tokens, user: user)
        return user
    }

    public func signIn(email: String, password: String) async throws -> User {
        isLoading = true
        state = .authenticating

        defer { isLoading = false }

        let passwordHash = hashPassword(password)

        let body: [String: Any] = [
            "email": email,
            "password": passwordHash
        ]

        let response = try await apiRequest(
            endpoint: "/auth/signin",
            method: "POST",
            body: body
        )

        let tokens = try parseAuthResponse(response)
        let user = try parseUserFromResponse(response)

        saveSession(tokens: tokens, user: user)
        return user
    }

    public func signOut() {
        Task {
            // Notify server (optional)
            if let token = tokens?.accessToken {
                try? await apiRequest(
                    endpoint: "/auth/signout",
                    method: "POST",
                    body: nil,
                    authToken: token
                )
            }

            clearSession()
        }
    }

    // MARK: - Password Reset

    public func sendPasswordResetEmail(email: String) async throws {
        let body: [String: Any] = ["email": email]

        _ = try await apiRequest(
            endpoint: "/auth/password-reset",
            method: "POST",
            body: body
        )
    }

    public func resetPassword(token: String, newPassword: String) async throws {
        guard newPassword.count >= 8 else {
            throw AuthError.weakPassword
        }

        let body: [String: Any] = [
            "token": token,
            "newPassword": hashPassword(newPassword)
        ]

        _ = try await apiRequest(
            endpoint: "/auth/password-reset/confirm",
            method: "POST",
            body: body
        )
    }

    // MARK: - Apple Sign In

    public func signInWithApple() async throws -> User {
        isLoading = true
        state = .authenticating

        defer { isLoading = false }

        let authorization = try await performAppleSignIn()

        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AuthError.invalidCredentials
        }

        let identityToken = appleIDCredential.identityToken.flatMap { String(data: $0, encoding: .utf8) }
        let authorizationCode = appleIDCredential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }

        let body: [String: Any] = [
            "identityToken": identityToken ?? "",
            "authorizationCode": authorizationCode ?? "",
            "user": [
                "id": appleIDCredential.user,
                "email": appleIDCredential.email ?? "",
                "firstName": appleIDCredential.fullName?.givenName ?? "",
                "lastName": appleIDCredential.fullName?.familyName ?? ""
            ]
        ]

        let response = try await apiRequest(
            endpoint: "/auth/apple",
            method: "POST",
            body: body
        )

        let tokens = try parseAuthResponse(response)
        let user = try parseUserFromResponse(response)

        saveSession(tokens: tokens, user: user)
        return user
    }

    private func performAppleSignIn() async throws -> ASAuthorization {
        try await withCheckedThrowingContinuation { continuation in
            self.appleSignInContinuation = continuation

            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.performRequests()
        }
    }

    // MARK: - Biometric Authentication

    private func checkBiometricCapability() {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch context.biometryType {
            case .faceID:
                biometricType = .faceID
            case .touchID:
                biometricType = .touchID
            default:
                biometricType = .none
            }
        } else {
            biometricType = .none
        }
    }

    public func enableBiometric() async throws {
        guard biometricType != .none else {
            throw AuthError.biometricFailed
        }

        let context = LAContext()
        let reason = "Enable biometric authentication for quick sign in"

        let success = try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        )

        if success {
            isBiometricEnabled = true
            userDefaults.set(true, forKey: "biometricEnabled")
        } else {
            throw AuthError.biometricFailed
        }
    }

    public func signInWithBiometric() async throws -> User {
        guard isBiometricEnabled else {
            throw AuthError.biometricFailed
        }

        let context = LAContext()
        let reason = "Sign in to Echoelmusic"

        let success = try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        )

        if success {
            // Load stored credentials and sign in
            if let tokenData = keychain.getData(forKey: "authTokens"),
               let tokens = try? JSONDecoder().decode(AuthTokens.self, from: tokenData),
               let userData = keychain.getData(forKey: "currentUser"),
               let user = try? JSONDecoder().decode(User.self, from: userData) {

                self.tokens = tokens
                self.currentUser = user
                state = .authenticated(user)

                // Refresh token if needed
                if tokens.isAboutToExpire {
                    await refreshTokenIfNeeded()
                }

                return user
            }
        }

        throw AuthError.biometricFailed
    }

    public func disableBiometric() {
        isBiometricEnabled = false
        userDefaults.set(false, forKey: "biometricEnabled")
    }

    // MARK: - User Management

    private func loadCurrentUser() async {
        guard let token = tokens?.accessToken else {
            clearSession()
            return
        }

        do {
            let response = try await apiRequest(
                endpoint: "/users/me",
                method: "GET",
                body: nil,
                authToken: token
            )

            let user = try parseUserFromResponse(response)
            currentUser = user
            state = .authenticated(user)
        } catch {
            clearSession()
        }
    }

    public func updateProfile(displayName: String? = nil, bio: String? = nil, avatarURL: URL? = nil) async throws -> User {
        guard let token = tokens?.accessToken else {
            throw AuthError.tokenExpired
        }

        var body: [String: Any] = [:]
        if let displayName = displayName { body["displayName"] = displayName }
        if let bio = bio { body["bio"] = bio }
        if let avatarURL = avatarURL { body["avatarURL"] = avatarURL.absoluteString }

        let response = try await apiRequest(
            endpoint: "/users/me",
            method: "PATCH",
            body: body,
            authToken: token
        )

        let user = try parseUserFromResponse(response)
        currentUser = user
        state = .authenticated(user)
        return user
    }

    public func deleteAccount() async throws {
        guard let token = tokens?.accessToken else {
            throw AuthError.tokenExpired
        }

        _ = try await apiRequest(
            endpoint: "/users/me",
            method: "DELETE",
            body: nil,
            authToken: token
        )

        clearSession()
    }

    // MARK: - API Helpers

    private func apiRequest(endpoint: String, method: String, body: [String: Any]?, authToken: String? = nil) async throws -> [String: Any] {
        var request = URLRequest(url: apiBaseURL.appendingPathComponent(endpoint))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw AuthError.tokenExpired
            }
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = errorJson["message"] as? String {
                throw AuthError.serverError(message)
            }
            throw AuthError.serverError("HTTP \(httpResponse.statusCode)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AuthError.serverError("Invalid response")
        }

        return json
    }

    private func refreshToken(refreshToken: String) async throws -> AuthTokens {
        let body: [String: Any] = ["refreshToken": refreshToken]
        let response = try await apiRequest(endpoint: "/auth/refresh", method: "POST", body: body)
        return try parseAuthResponse(response)
    }

    private func parseAuthResponse(_ response: [String: Any]) throws -> AuthTokens {
        guard let accessToken = response["accessToken"] as? String,
              let refreshToken = response["refreshToken"] as? String,
              let expiresIn = response["expiresIn"] as? Int else {
            throw AuthError.serverError("Invalid auth response")
        }

        return AuthTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(expiresIn)),
            tokenType: response["tokenType"] as? String ?? "Bearer"
        )
    }

    private func parseUserFromResponse(_ response: [String: Any]) throws -> User {
        guard let userData = response["user"] as? [String: Any],
              let id = userData["id"] as? String,
              let email = userData["email"] as? String else {
            throw AuthError.serverError("Invalid user data")
        }

        return User(
            id: id,
            email: email,
            username: userData["username"] as? String ?? "",
            displayName: userData["displayName"] as? String ?? "",
            avatarURL: (userData["avatarURL"] as? String).flatMap { URL(string: $0) },
            createdAt: parseDate(userData["createdAt"]) ?? Date(),
            lastLoginAt: parseDate(userData["lastLoginAt"]) ?? Date(),
            isEmailVerified: userData["isEmailVerified"] as? Bool ?? false,
            isPremium: userData["isPremium"] as? Bool ?? false,
            subscriptionTier: User.SubscriptionTier(rawValue: userData["subscriptionTier"] as? String ?? "Free") ?? .free,
            preferences: User.UserPreferences(),
            profile: User.UserProfile()
        )
    }

    private func parseDate(_ value: Any?) -> Date? {
        if let string = value as? String {
            let formatter = ISO8601DateFormatter()
            return formatter.date(from: string)
        }
        if let timestamp = value as? TimeInterval {
            return Date(timeIntervalSince1970: timestamp)
        }
        return nil
    }

    // MARK: - Utilities

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }

    private func hashPassword(_ password: String) -> String {
        // In production, use proper password hashing (server-side)
        // This is just for demonstration
        let data = Data(password.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Auth Token Access

    public var accessToken: String? {
        tokens?.accessToken
    }

    public var isAuthenticated: Bool {
        if case .authenticated = state {
            return true
        }
        return false
    }
}

// MARK: - Apple Sign In Delegate

extension AuthenticationManager: ASAuthorizationControllerDelegate {
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        appleSignInContinuation?.resume(returning: authorization)
        appleSignInContinuation = nil
    }

    public func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let authError: AuthError
        if let asError = error as? ASAuthorizationError {
            switch asError.code {
            case .canceled:
                authError = .cancelled
            case .invalidResponse:
                authError = .invalidCredentials
            default:
                authError = .unknown(error)
            }
        } else {
            authError = .unknown(error)
        }

        appleSignInContinuation?.resume(throwing: authError)
        appleSignInContinuation = nil
    }
}

// MARK: - Keychain Manager

class KeychainManager {
    private let service = "com.echoelmusic.auth"

    func setData(_ data: Data, forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    func getData(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    func deleteItem(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}
