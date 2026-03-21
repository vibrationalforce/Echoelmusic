#if canImport(Foundation)
//
//  OuraRingClient.swift
//  Echoelmusic — Oura Ring Cloud API v2 Client
//
//  REST client for Oura Cloud API v2:
//  - OAuth2 PKCE authentication flow
//  - Daily sleep, readiness, activity scores
//  - Heart rate and HRV during sleep
//  - Keychain-backed token storage (Security framework)
//  - Automatic token refresh with 429 rate-limit handling
//
//  Oura API docs: https://cloud.ouraring.com/v2/docs
//
//  IMPORTANT: Not a medical device. Data for self-observation only.
//

import Foundation
#if canImport(Security)
import Security
#endif
#if canImport(Observation)
import Observation
#endif
#if canImport(CryptoKit)
import CryptoKit
#endif

// MARK: - Oura Data Types

/// Snapshot of Oura Ring daily data
public struct OuraSnapshot: Sendable {
    /// Sleep score [0-100]
    public var sleepScore: Int = 0
    /// Readiness score [0-100]
    public var readinessScore: Int = 0
    /// Activity score [0-100]
    public var activityScore: Int = 0
    /// Resting heart rate in BPM
    public var restingHR: Int = 0
    /// Average HRV (RMSSD) during sleep in ms
    public var hrvSleep: Double = 0.0
    /// Total sleep duration in seconds
    public var totalSleepSeconds: Int = 0
    /// Deep sleep duration in seconds
    public var deepSleepSeconds: Int = 0
    /// REM sleep duration in seconds
    public var remSleepSeconds: Int = 0
    /// Date of the data
    public var date: String = ""
    /// Last successful sync timestamp
    public var lastSync: Date?
}

/// Oura API authentication state
public enum OuraAuthState: String, Sendable {
    case unauthenticated = "Not Connected"
    case authenticating = "Authenticating"
    case authenticated = "Connected"
    case refreshing = "Refreshing Token"
    case error = "Error"
}

/// OAuth2 token pair
private struct OuraTokens: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let tokenType: String

    var isExpired: Bool {
        Date() >= expiresAt.addingTimeInterval(-60) // Refresh 60s before expiry
    }
}

// MARK: - Keychain Helper

private enum OuraKeychain {
    static let service = "com.echoelmusic.oura"
    static let tokenAccount = "oauth_tokens"

    #if canImport(Security)
    static func save(_ data: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    static func load() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount
        ]
        SecItemDelete(query as CFDictionary)
    }
    #else
    static func save(_ data: Data) -> Bool { false }
    static func load() -> Data? { nil }
    static func delete() {}
    #endif
}

// MARK: - OuraRingClient

/// Oura Cloud API v2 REST client with OAuth2 PKCE authentication
@preconcurrency @MainActor
@Observable
public final class OuraRingClient {

    // MARK: - Singleton

    @MainActor public static let shared = OuraRingClient()

    // MARK: - Configuration

    /// Oura API base URL
    private let baseURL = "https://api.ouraring.com/v2"
    /// OAuth2 authorization endpoint
    private let authURL = "https://cloud.ouraring.com/oauth/authorize"
    /// OAuth2 token endpoint
    private let tokenURL = "https://api.ouraring.com/oauth/token"
    /// Redirect URI registered with Oura developer portal
    private let redirectURI = "echoelmusic://oura/callback"

    /// Client ID — set via configure() before authentication
    private var clientID: String = ""

    // MARK: - Observable State

    public var authState: OuraAuthState = .unauthenticated
    public var snapshot: OuraSnapshot = OuraSnapshot()
    public var lastError: String?
    public var isSyncing: Bool = false

    // MARK: - Private State

    private var tokens: OuraTokens?
    private var codeVerifier: String?
    private let session: URLSession
    private let decoder = JSONDecoder()

    /// Rate limit tracking
    private var rateLimitResetDate: Date?
    private var consecutiveRetries: Int = 0
    private let maxRetries: Int = 3

    // MARK: - Init

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        session = URLSession(configuration: config)

        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        // Attempt to restore tokens from Keychain
        restoreTokens()
    }

    // MARK: - Configuration

    /// Configure with Oura developer credentials
    public func configure(clientID: String) {
        self.clientID = clientID
        log.log(.info, category: .biofeedback, "Oura: Configured with client ID")
    }

    // MARK: - OAuth2 PKCE Flow

    /// Generate the OAuth2 authorization URL with PKCE challenge
    public func authorizationURL() -> URL? {
        guard !clientID.isEmpty else {
            log.log(.error, category: .biofeedback, "Oura: Client ID not configured")
            return nil
        }

        // Generate PKCE code verifier (43-128 chars, unreserved URI characters)
        let verifier = generateCodeVerifier()
        codeVerifier = verifier

        // Generate code challenge (SHA256 of verifier, base64url encoded)
        let challenge = generateCodeChallenge(from: verifier)

        var components = URLComponents(string: authURL)
        components?.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: "daily heartrate personal"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: UUID().uuidString)
        ]

        authState = .authenticating
        return components?.url
    }

    /// Handle the OAuth2 callback with authorization code
    public func handleCallback(url: URL) async -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              let verifier = codeVerifier else {
            log.log(.error, category: .biofeedback, "Oura: Invalid callback URL")
            authState = .error
            lastError = "Invalid callback URL"
            return false
        }

        return await exchangeCodeForTokens(code: code, verifier: verifier)
    }

    /// Exchange authorization code for tokens
    private func exchangeCodeForTokens(code: String, verifier: String) async -> Bool {
        guard let url = URL(string: tokenURL) else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "grant_type=authorization_code",
            "code=\(code)",
            "redirect_uri=\(redirectURI)",
            "client_id=\(clientID)",
            "code_verifier=\(verifier)"
        ].joined(separator: "&")
        request.httpBody = body.data(using: .utf8)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                authState = .error
                lastError = "Invalid response"
                return false
            }

            guard httpResponse.statusCode == 200 else {
                log.log(.error, category: .biofeedback, "Oura: Token exchange failed — HTTP \(httpResponse.statusCode)")
                authState = .error
                lastError = "Token exchange failed (HTTP \(httpResponse.statusCode))"
                return false
            }

            let tokenResponse = try decoder.decode(OuraTokenResponse.self, from: data)
            let tokens = OuraTokens(
                accessToken: tokenResponse.accessToken,
                refreshToken: tokenResponse.refreshToken,
                expiresAt: Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn)),
                tokenType: tokenResponse.tokenType
            )

            self.tokens = tokens
            saveTokens(tokens)
            authState = .authenticated
            codeVerifier = nil

            log.log(.info, category: .biofeedback, "Oura: Authentication successful")
            return true
        } catch {
            log.log(.error, category: .biofeedback, "Oura: Token exchange error — \(error.localizedDescription)")
            authState = .error
            lastError = error.localizedDescription
            return false
        }
    }

    // MARK: - Token Refresh

    /// Refresh the access token using the refresh token
    private func refreshAccessToken() async -> Bool {
        guard let currentTokens = tokens, let url = URL(string: tokenURL) else {
            authState = .unauthenticated
            return false
        }

        authState = .refreshing

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "grant_type=refresh_token",
            "refresh_token=\(currentTokens.refreshToken)",
            "client_id=\(clientID)"
        ].joined(separator: "&")
        request.httpBody = body.data(using: .utf8)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                log.log(.error, category: .biofeedback, "Oura: Token refresh failed")
                authState = .error
                return false
            }

            let tokenResponse = try decoder.decode(OuraTokenResponse.self, from: data)
            let newTokens = OuraTokens(
                accessToken: tokenResponse.accessToken,
                refreshToken: tokenResponse.refreshToken,
                expiresAt: Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn)),
                tokenType: tokenResponse.tokenType
            )

            self.tokens = newTokens
            saveTokens(newTokens)
            authState = .authenticated

            log.log(.info, category: .biofeedback, "Oura: Token refreshed successfully")
            return true
        } catch {
            log.log(.error, category: .biofeedback, "Oura: Token refresh error — \(error.localizedDescription)")
            authState = .error
            return false
        }
    }

    // MARK: - API Requests

    /// Fetch all daily data and update snapshot
    public func syncDailyData() async {
        guard authState == .authenticated || authState == .refreshing else {
            log.log(.warning, category: .biofeedback, "Oura: Cannot sync — not authenticated")
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        let today = dateString(for: Date())

        async let sleepResult = fetchDailySleep(date: today)
        async let readinessResult = fetchDailyReadiness(date: today)
        async let activityResult = fetchDailyActivity(date: today)
        async let heartRateResult = fetchHeartRate(date: today)

        let sleep = await sleepResult
        let readiness = await readinessResult
        let activity = await activityResult
        let heartRate = await heartRateResult

        if let sleep = sleep {
            snapshot.sleepScore = sleep.score
            snapshot.totalSleepSeconds = sleep.totalSleepDuration
            snapshot.deepSleepSeconds = sleep.deepSleepDuration
            snapshot.remSleepSeconds = sleep.remSleepDuration
        }

        if let readiness = readiness {
            snapshot.readinessScore = readiness.score
            snapshot.restingHR = readiness.restingHeartRate
        }

        if let activity = activity {
            snapshot.activityScore = activity.score
        }

        if let heartRate = heartRate {
            snapshot.hrvSleep = heartRate.averageHRV
        }

        snapshot.date = today
        snapshot.lastSync = Date()
        consecutiveRetries = 0

        log.log(.info, category: .biofeedback, "Oura: Daily sync complete — Sleep: \(snapshot.sleepScore), Readiness: \(snapshot.readinessScore)")
    }

    /// Sign out and clear tokens
    public func signOut() {
        tokens = nil
        OuraKeychain.delete()
        authState = .unauthenticated
        snapshot = OuraSnapshot()
        lastError = nil
        log.log(.info, category: .biofeedback, "Oura: Signed out")
    }

    // MARK: - API Endpoints

    private func fetchDailySleep(date: String) async -> OuraSleepResponse? {
        return await apiGet("/usercollection/daily_sleep?start_date=\(date)&end_date=\(date)")
    }

    private func fetchDailyReadiness(date: String) async -> OuraReadinessResponse? {
        return await apiGet("/usercollection/daily_readiness?start_date=\(date)&end_date=\(date)")
    }

    private func fetchDailyActivity(date: String) async -> OuraActivityResponse? {
        return await apiGet("/usercollection/daily_activity?start_date=\(date)&end_date=\(date)")
    }

    private func fetchHeartRate(date: String) async -> OuraHeartRateResponse? {
        return await apiGet("/usercollection/heartrate?start_datetime=\(date)T00:00:00&end_datetime=\(date)T23:59:59")
    }

    // MARK: - Generic API Request with Rate Limiting

    private func apiGet<T: Decodable>(_ path: String) async -> T? {
        // Respect rate limit window
        if let resetDate = rateLimitResetDate, Date() < resetDate {
            let waitSeconds = resetDate.timeIntervalSince(Date())
            log.log(.warning, category: .biofeedback, "Oura: Rate limited — waiting \(Int(waitSeconds))s")
            try? await Task.sleep(nanoseconds: UInt64(waitSeconds * 1_000_000_000))
        }

        // Ensure valid token
        if let currentTokens = tokens, currentTokens.isExpired {
            let refreshed = await refreshAccessToken()
            guard refreshed else { return nil }
        }

        guard let currentTokens = tokens else {
            authState = .unauthenticated
            return nil
        }

        guard let url = URL(string: baseURL + path) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(currentTokens.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else { return nil }

            switch httpResponse.statusCode {
            case 200:
                consecutiveRetries = 0
                return try decoder.decode(T.self, from: data)

            case 401:
                // Token expired or revoked — try refresh
                log.log(.warning, category: .biofeedback, "Oura: 401 — attempting token refresh")
                let refreshed = await refreshAccessToken()
                if refreshed, consecutiveRetries < maxRetries {
                    consecutiveRetries += 1
                    return await apiGet(path)
                }
                return nil

            case 429:
                // Rate limited — parse Retry-After header
                let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                    .flatMap(Double.init) ?? 60.0
                rateLimitResetDate = Date().addingTimeInterval(retryAfter)
                log.log(.warning, category: .biofeedback, "Oura: Rate limited — retry after \(Int(retryAfter))s")

                if consecutiveRetries < maxRetries {
                    consecutiveRetries += 1
                    try? await Task.sleep(nanoseconds: UInt64(retryAfter * 1_000_000_000))
                    return await apiGet(path)
                }
                return nil

            default:
                log.log(.error, category: .biofeedback, "Oura: API error — HTTP \(httpResponse.statusCode)")
                return nil
            }
        } catch {
            log.log(.error, category: .biofeedback, "Oura: Request failed — \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Token Persistence

    private func saveTokens(_ tokens: OuraTokens) {
        guard let data = try? JSONEncoder().encode(tokens) else { return }
        let saved = OuraKeychain.save(data)
        if !saved {
            log.log(.warning, category: .biofeedback, "Oura: Failed to save tokens to Keychain")
        }
    }

    private func restoreTokens() {
        guard let data = OuraKeychain.load(),
              let restored = try? JSONDecoder().decode(OuraTokens.self, from: data) else {
            return
        }

        tokens = restored
        if restored.isExpired {
            authState = .unauthenticated
            log.log(.info, category: .biofeedback, "Oura: Restored expired tokens — refresh needed")
        } else {
            authState = .authenticated
            log.log(.info, category: .biofeedback, "Oura: Restored valid tokens from Keychain")
        }
    }

    // MARK: - PKCE Helpers

    private func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        #if canImport(CryptoKit)
        guard let data = verifier.data(using: .utf8) else { return verifier }
        let hash = SHA256.hash(data: data)
        return Data(hash)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        #else
        return verifier
        #endif
    }

    // MARK: - Utility

    private func dateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
}

// MARK: - API Response Types

private struct OuraTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

private struct OuraSleepResponse: Decodable {
    let score: Int
    let totalSleepDuration: Int
    let deepSleepDuration: Int
    let remSleepDuration: Int

    enum CodingKeys: String, CodingKey {
        case data
    }

    enum DataCodingKeys: String, CodingKey {
        case score
        case contributors
        case totalSleepDuration = "total_sleep_duration"
        case deepSleepDuration = "deep_sleep_duration"
        case remSleepDuration = "rem_sleep_duration"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var dataArray = try container.nestedUnkeyedContainer(forKey: .data)
        if let item = try? dataArray.nestedContainer(keyedBy: DataCodingKeys.self) {
            score = (try? item.decode(Int.self, forKey: .score)) ?? 0
            totalSleepDuration = (try? item.decode(Int.self, forKey: .totalSleepDuration)) ?? 0
            deepSleepDuration = (try? item.decode(Int.self, forKey: .deepSleepDuration)) ?? 0
            remSleepDuration = (try? item.decode(Int.self, forKey: .remSleepDuration)) ?? 0
        } else {
            score = 0
            totalSleepDuration = 0
            deepSleepDuration = 0
            remSleepDuration = 0
        }
    }
}

private struct OuraReadinessResponse: Decodable {
    let score: Int
    let restingHeartRate: Int

    enum CodingKeys: String, CodingKey {
        case data
    }

    enum DataCodingKeys: String, CodingKey {
        case score
        case restingHeartRate = "resting_heart_rate"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var dataArray = try container.nestedUnkeyedContainer(forKey: .data)
        if let item = try? dataArray.nestedContainer(keyedBy: DataCodingKeys.self) {
            score = (try? item.decode(Int.self, forKey: .score)) ?? 0
            restingHeartRate = (try? item.decode(Int.self, forKey: .restingHeartRate)) ?? 0
        } else {
            score = 0
            restingHeartRate = 0
        }
    }
}

private struct OuraActivityResponse: Decodable {
    let score: Int

    enum CodingKeys: String, CodingKey {
        case data
    }

    enum DataCodingKeys: String, CodingKey {
        case score
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var dataArray = try container.nestedUnkeyedContainer(forKey: .data)
        if let item = try? dataArray.nestedContainer(keyedBy: DataCodingKeys.self) {
            score = (try? item.decode(Int.self, forKey: .score)) ?? 0
        } else {
            score = 0
        }
    }
}

private struct OuraHeartRateResponse: Decodable {
    let averageHRV: Double

    enum CodingKeys: String, CodingKey {
        case data
    }

    enum DataCodingKeys: String, CodingKey {
        case bpm
        case source
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var dataArray = try container.nestedUnkeyedContainer(forKey: .data)

        var totalBPM: Double = 0
        var count: Int = 0
        while !dataArray.isAtEnd {
            if let item = try? dataArray.nestedContainer(keyedBy: DataCodingKeys.self),
               let bpm = try? item.decode(Double.self, forKey: .bpm) {
                totalBPM += bpm
                count += 1
            }
        }

        averageHRV = count > 0 ? totalBPM / Double(count) : 0
    }
}

#endif // canImport(Foundation)
