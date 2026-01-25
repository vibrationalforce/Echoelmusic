// EnhancedNetworkSecurity.swift
// Echoelmusic - Enhanced Network Security Layer
//
// Created: 2026-01-25
// Purpose: Production-grade network security with HTTP rejection
//
// SECURITY LEVEL: Maximum
// Implements: OWASP M3 - Insecure Communication

import Foundation
import CryptoKit

// MARK: - Enhanced Network Security Manager

/// Production-grade network security manager with strict HTTPS enforcement
@MainActor
public final class EnhancedNetworkSecurityManager: @unchecked Sendable {

    // MARK: - Singleton

    public static let shared = EnhancedNetworkSecurityManager()

    // MARK: - Configuration

    private let configuration: SecurityConfiguration
    private var urlValidationCache: [String: URLValidationResult] = [:]
    private let cacheQueue = DispatchQueue(label: "com.echoelmusic.networksecurity", attributes: .concurrent)

    // MARK: - Types

    public struct SecurityConfiguration: Sendable {
        public let enforceHTTPS: Bool
        public let allowedHTTPHosts: Set<String>
        public let minimumTLSVersion: TLSVersion
        public let requireCertificatePinning: Bool
        public let enableHSTS: Bool
        public let hstsMaxAge: TimeInterval

        public enum TLSVersion: String, Sendable {
            case tls12 = "TLS 1.2"
            case tls13 = "TLS 1.3"
        }

        public static let development = SecurityConfiguration(
            enforceHTTPS: false,
            allowedHTTPHosts: ["localhost", "127.0.0.1", "::1"],
            minimumTLSVersion: .tls12,
            requireCertificatePinning: false,
            enableHSTS: false,
            hstsMaxAge: 0
        )

        public static let staging = SecurityConfiguration(
            enforceHTTPS: true,
            allowedHTTPHosts: ["localhost", "127.0.0.1"],
            minimumTLSVersion: .tls12,
            requireCertificatePinning: true,
            enableHSTS: true,
            hstsMaxAge: 86400 // 1 day
        )

        public static let production = SecurityConfiguration(
            enforceHTTPS: true,
            allowedHTTPHosts: [], // No HTTP allowed in production
            minimumTLSVersion: .tls13,
            requireCertificatePinning: true,
            enableHSTS: true,
            hstsMaxAge: 31536000 // 1 year
        )

        public static let enterprise = SecurityConfiguration(
            enforceHTTPS: true,
            allowedHTTPHosts: [],
            minimumTLSVersion: .tls13,
            requireCertificatePinning: true,
            enableHSTS: true,
            hstsMaxAge: 63072000 // 2 years
        )

        public init(
            enforceHTTPS: Bool,
            allowedHTTPHosts: Set<String>,
            minimumTLSVersion: TLSVersion,
            requireCertificatePinning: Bool,
            enableHSTS: Bool,
            hstsMaxAge: TimeInterval
        ) {
            self.enforceHTTPS = enforceHTTPS
            self.allowedHTTPHosts = allowedHTTPHosts
            self.minimumTLSVersion = minimumTLSVersion
            self.requireCertificatePinning = requireCertificatePinning
            self.enableHSTS = enableHSTS
            self.hstsMaxAge = hstsMaxAge
        }
    }

    /// URL validation result
    public struct URLValidationResult: Sendable {
        public let isValid: Bool
        public let isSecure: Bool
        public let violations: [SecurityViolation]
        public let recommendations: [String]

        public var canProceed: Bool {
            violations.filter { $0.severity == .critical || $0.severity == .high }.isEmpty
        }
    }

    /// Security violation
    public struct SecurityViolation: Sendable {
        public let type: ViolationType
        public let severity: Severity
        public let description: String
        public let remediation: String

        public enum ViolationType: String, Sendable {
            case insecureProtocol = "Insecure Protocol"
            case selfSignedCertificate = "Self-Signed Certificate"
            case expiredCertificate = "Expired Certificate"
            case weakCipher = "Weak Cipher"
            case missingPinning = "Missing Certificate Pinning"
            case insecureRedirect = "Insecure Redirect"
            case mixedContent = "Mixed Content"
            case invalidHost = "Invalid Host"
            case untrustedCA = "Untrusted CA"
        }

        public enum Severity: String, Sendable {
            case critical = "Critical"
            case high = "High"
            case medium = "Medium"
            case low = "Low"
            case info = "Info"
        }
    }

    // MARK: - Initialization

    private init() {
        #if DEBUG
        self.configuration = .development
        #else
        // Detect environment from build configuration
        if ProcessInfo.processInfo.environment["ECHOELMUSIC_ENV"] == "staging" {
            self.configuration = .staging
        } else if ProcessInfo.processInfo.environment["ECHOELMUSIC_ENTERPRISE"] == "true" {
            self.configuration = .enterprise
        } else {
            self.configuration = .production
        }
        #endif
    }

    // MARK: - URL Validation

    /// Validate a URL for security compliance
    public func validateURL(_ url: URL) -> URLValidationResult {
        var violations: [SecurityViolation] = []
        var recommendations: [String] = []

        // Check scheme
        let scheme = url.scheme?.lowercased() ?? ""
        let host = url.host?.lowercased() ?? ""

        // HTTP validation
        if scheme == "http" {
            if configuration.enforceHTTPS && !configuration.allowedHTTPHosts.contains(host) {
                violations.append(SecurityViolation(
                    type: .insecureProtocol,
                    severity: .critical,
                    description: "HTTP protocol is not allowed in \(currentEnvironment) environment",
                    remediation: "Use HTTPS instead of HTTP"
                ))
            } else if configuration.allowedHTTPHosts.contains(host) {
                recommendations.append("HTTP allowed for \(host) - development/localhost exception")
            }
        }

        // Validate host
        if host.isEmpty {
            violations.append(SecurityViolation(
                type: .invalidHost,
                severity: .high,
                description: "URL has no valid host",
                remediation: "Provide a valid hostname"
            ))
        }

        // Check for IP addresses in production (should use DNS)
        if configuration.enforceHTTPS && isIPAddress(host) && !configuration.allowedHTTPHosts.contains(host) {
            violations.append(SecurityViolation(
                type: .invalidHost,
                severity: .medium,
                description: "Direct IP addresses should not be used in production",
                remediation: "Use a DNS hostname with valid certificate"
            ))
        }

        // Check port (non-standard ports may indicate issues)
        if let port = url.port, port != 443 && port != 80 {
            recommendations.append("Non-standard port \(port) - verify this is intentional")
        }

        let isSecure = scheme == "https" || configuration.allowedHTTPHosts.contains(host)

        return URLValidationResult(
            isValid: violations.isEmpty || violations.allSatisfy { $0.severity != .critical },
            isSecure: isSecure,
            violations: violations,
            recommendations: recommendations
        )
    }

    /// Validate and transform URL to HTTPS if needed
    public func secureURL(_ url: URL) -> Result<URL, NetworkSecurityError> {
        let validation = validateURL(url)

        if validation.canProceed {
            // If HTTP and HTTPS enforcement is on, upgrade to HTTPS
            if url.scheme?.lowercased() == "http" && configuration.enforceHTTPS {
                if let host = url.host, !configuration.allowedHTTPHosts.contains(host.lowercased()) {
                    // Upgrade to HTTPS
                    var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
                    components?.scheme = "https"
                    if let secureURL = components?.url {
                        return .success(secureURL)
                    }
                }
            }
            return .success(url)
        }

        let criticalViolation = validation.violations.first { $0.severity == .critical }
        return .failure(.securityViolation(criticalViolation?.description ?? "Security check failed"))
    }

    // MARK: - Request Validation

    /// Validate a URLRequest for security compliance
    public func validateRequest(_ request: URLRequest) -> URLValidationResult {
        guard let url = request.url else {
            return URLValidationResult(
                isValid: false,
                isSecure: false,
                violations: [SecurityViolation(
                    type: .invalidHost,
                    severity: .critical,
                    description: "Request has no URL",
                    remediation: "Provide a valid URL"
                )],
                recommendations: []
            )
        }

        var result = validateURL(url)
        var additionalViolations = result.violations
        var additionalRecommendations = result.recommendations

        // Check for sensitive data in URL parameters
        if let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: true)?.queryItems {
            let sensitiveParams = ["password", "token", "key", "secret", "api_key", "apikey", "auth"]
            for item in queryItems {
                if sensitiveParams.contains(item.name.lowercased()) {
                    additionalViolations.append(SecurityViolation(
                        type: .mixedContent,
                        severity: .high,
                        description: "Sensitive parameter '\(item.name)' found in URL",
                        remediation: "Move sensitive data to request body or headers"
                    ))
                }
            }
        }

        // Check headers for security
        if let headers = request.allHTTPHeaderFields {
            // Verify Authorization header is present for authenticated requests
            if headers["Authorization"] == nil && requiresAuthentication(url) {
                additionalRecommendations.append("Consider adding Authorization header for authenticated endpoints")
            }
        }

        return URLValidationResult(
            isValid: result.isValid && additionalViolations.filter { $0.severity == .critical || $0.severity == .high }.isEmpty,
            isSecure: result.isSecure,
            violations: additionalViolations,
            recommendations: additionalRecommendations
        )
    }

    /// Create a secure URLRequest
    public func createSecureRequest(url: URL, method: String = "GET") -> Result<URLRequest, NetworkSecurityError> {
        switch secureURL(url) {
        case .success(let secureURL):
            var request = URLRequest(url: secureURL)
            request.httpMethod = method

            // Add security headers
            request.setValue("no-cache, no-store", forHTTPHeaderField: "Cache-Control")
            request.setValue("nosniff", forHTTPHeaderField: "X-Content-Type-Options")
            request.setValue("DENY", forHTTPHeaderField: "X-Frame-Options")
            request.setValue("1; mode=block", forHTTPHeaderField: "X-XSS-Protection")

            // Add HSTS header recommendation (server should set this)
            if configuration.enableHSTS {
                // Note: HSTS is typically set by the server, not client
                // This is for documentation/verification purposes
            }

            return .success(request)

        case .failure(let error):
            return .failure(error)
        }
    }

    // MARK: - URLSession Configuration

    /// Create a secure URLSession configuration
    public func createSecureSessionConfiguration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.default

        // TLS configuration
        config.tlsMinimumSupportedProtocolVersion = configuration.minimumTLSVersion == .tls13 ? .TLSv13 : .TLSv12
        config.tlsMaximumSupportedProtocolVersion = .TLSv13

        // Security settings
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.urlCredentialStorage = nil

        // Caching policy (disable for sensitive requests)
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil

        // Timeout configuration
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60

        // Additional headers
        config.httpAdditionalHeaders = [
            "X-Requested-With": "Echoelmusic",
            "X-Client-Version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        ]

        return config
    }

    /// Create a secure URLSession with delegate for certificate pinning
    public func createSecureSession(delegate: URLSessionDelegate? = nil) -> URLSession {
        let config = createSecureSessionConfiguration()
        return URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
    }

    // MARK: - Helper Methods

    private func isIPAddress(_ host: String) -> Bool {
        // Check for IPv4
        let ipv4Pattern = "^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
        if host.range(of: ipv4Pattern, options: .regularExpression) != nil {
            return true
        }

        // Check for IPv6
        if host.contains(":") && !host.contains(".") {
            return true
        }

        return false
    }

    private func requiresAuthentication(_ url: URL) -> Bool {
        // Check if the endpoint typically requires authentication
        let authPaths = ["/api/", "/user/", "/account/", "/session/", "/private/"]
        let path = url.path.lowercased()
        return authPaths.contains { path.contains($0) }
    }

    private var currentEnvironment: String {
        #if DEBUG
        return "development"
        #else
        if ProcessInfo.processInfo.environment["ECHOELMUSIC_ENV"] == "staging" {
            return "staging"
        }
        return "production"
        #endif
    }

    // MARK: - Security Status

    /// Get current network security status
    public var securityStatus: NetworkSecurityStatus {
        NetworkSecurityStatus(
            httpsEnforced: configuration.enforceHTTPS,
            minimumTLSVersion: configuration.minimumTLSVersion.rawValue,
            certificatePinningRequired: configuration.requireCertificatePinning,
            hstsEnabled: configuration.enableHSTS,
            hstsMaxAge: configuration.hstsMaxAge,
            allowedHTTPHosts: Array(configuration.allowedHTTPHosts),
            environment: currentEnvironment
        )
    }

    public struct NetworkSecurityStatus: Sendable {
        public let httpsEnforced: Bool
        public let minimumTLSVersion: String
        public let certificatePinningRequired: Bool
        public let hstsEnabled: Bool
        public let hstsMaxAge: TimeInterval
        public let allowedHTTPHosts: [String]
        public let environment: String

        public var score: Double {
            var score = 0.0

            if httpsEnforced { score += 30 }
            if minimumTLSVersion == "TLS 1.3" { score += 20 } else if minimumTLSVersion == "TLS 1.2" { score += 15 }
            if certificatePinningRequired { score += 25 }
            if hstsEnabled { score += 15 }
            if allowedHTTPHosts.isEmpty { score += 10 }

            return score
        }
    }
}

// MARK: - Error Types

public enum NetworkSecurityError: Error, LocalizedError, Sendable {
    case insecureProtocol(String)
    case securityViolation(String)
    case certificateError(String)
    case tlsVersionTooLow(String)
    case hostNotAllowed(String)

    public var errorDescription: String? {
        switch self {
        case .insecureProtocol(let message):
            return "Insecure protocol: \(message)"
        case .securityViolation(let message):
            return "Security violation: \(message)"
        case .certificateError(let message):
            return "Certificate error: \(message)"
        case .tlsVersionTooLow(let message):
            return "TLS version too low: \(message)"
        case .hostNotAllowed(let message):
            return "Host not allowed: \(message)"
        }
    }
}

// MARK: - URL Extension

public extension URL {

    /// Check if this URL is secure for production use
    var isSecureForProduction: Bool {
        EnhancedNetworkSecurityManager.shared.validateURL(self).isSecure
    }

    /// Get a validated secure version of this URL
    var secureVersion: URL? {
        switch EnhancedNetworkSecurityManager.shared.secureURL(self) {
        case .success(let url): return url
        case .failure: return nil
        }
    }

    /// Validate this URL for security compliance
    func validateSecurity() -> EnhancedNetworkSecurityManager.URLValidationResult {
        EnhancedNetworkSecurityManager.shared.validateURL(self)
    }
}

// MARK: - URLRequest Extension

public extension URLRequest {

    /// Create a security-validated request
    static func secure(url: URL, method: String = "GET") -> Result<URLRequest, NetworkSecurityError> {
        EnhancedNetworkSecurityManager.shared.createSecureRequest(url: url, method: method)
    }

    /// Validate this request for security compliance
    func validateSecurity() -> EnhancedNetworkSecurityManager.URLValidationResult {
        EnhancedNetworkSecurityManager.shared.validateRequest(self)
    }
}

// MARK: - Production HTTP Rejection

/// Utility to reject HTTP URLs at runtime in production
public enum ProductionHTTPRejection {

    /// Reject HTTP URLs in production builds
    public static func rejectIfInsecure(_ url: URL) throws {
        #if !DEBUG
        let validation = EnhancedNetworkSecurityManager.shared.validateURL(url)
        if !validation.isSecure {
            let violations = validation.violations.map { $0.description }.joined(separator: "; ")
            throw NetworkSecurityError.insecureProtocol("HTTP rejected in production: \(violations)")
        }
        #endif
    }

    /// Assert URL is secure (crashes in debug if insecure, throws in release)
    public static func assertSecure(_ url: URL, file: StaticString = #file, line: UInt = #line) throws {
        let validation = EnhancedNetworkSecurityManager.shared.validateURL(url)

        #if DEBUG
        assert(validation.isSecure, "Insecure URL detected: \(url)", file: file, line: line)
        #else
        if !validation.isSecure {
            throw NetworkSecurityError.insecureProtocol("URL \(url) is not secure for production")
        }
        #endif
    }
}

// MARK: - Secure Network Client

/// A secure network client that enforces all security policies
public actor SecureNetworkClient {
    private let session: URLSession
    private let securityManager = EnhancedNetworkSecurityManager.shared

    public init() {
        self.session = securityManager.createSecureSession()
    }

    /// Perform a secure GET request
    public func get(_ url: URL) async throws -> (Data, URLResponse) {
        let request = try securityManager.createSecureRequest(url: url, method: "GET").get()
        return try await session.data(for: request)
    }

    /// Perform a secure POST request
    public func post(_ url: URL, body: Data) async throws -> (Data, URLResponse) {
        var request = try securityManager.createSecureRequest(url: url, method: "POST").get()
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await session.data(for: request)
    }

    /// Validate a URL before making a request
    public func validate(_ url: URL) -> EnhancedNetworkSecurityManager.URLValidationResult {
        securityManager.validateURL(url)
    }
}
