// EnhancedInputValidation.swift
// Echoelmusic - Comprehensive Input Validation System
//
// Created: 2026-01-25
// Purpose: Production-grade input validation and sanitization
//
// SECURITY LEVEL: Maximum
// Prevents: Injection attacks, XSS, path traversal, buffer overflows

import Foundation

// MARK: - Input Validation Manager

/// Comprehensive input validation and sanitization manager
public final class InputValidationManager: Sendable {

    // MARK: - Singleton

    public static let shared = InputValidationManager()

    private init() {}

    // MARK: - Validation Result

    public struct ValidationResult: Sendable {
        public let isValid: Bool
        public let sanitizedValue: String
        public let violations: [ValidationViolation]
        public let suggestions: [String]

        public static let valid = ValidationResult(isValid: true, sanitizedValue: "", violations: [], suggestions: [])

        public init(isValid: Bool, sanitizedValue: String, violations: [ValidationViolation], suggestions: [String]) {
            self.isValid = isValid
            self.sanitizedValue = sanitizedValue
            self.violations = violations
            self.suggestions = suggestions
        }
    }

    public struct ValidationViolation: Sendable {
        public let type: ViolationType
        public let description: String
        public let position: Int?

        public enum ViolationType: String, Sendable {
            case invalidCharacters = "Invalid Characters"
            case lengthViolation = "Length Violation"
            case formatViolation = "Format Violation"
            case injectionAttempt = "Injection Attempt"
            case pathTraversal = "Path Traversal"
            case nullByte = "Null Byte"
            case encodingIssue = "Encoding Issue"
            case reservedWord = "Reserved Word"
            case unsafePattern = "Unsafe Pattern"
        }
    }

    // MARK: - String Validation

    /// Validate and sanitize a general string input
    public func validateString(
        _ input: String,
        minLength: Int = 0,
        maxLength: Int = 10000,
        allowedCharacters: CharacterSet? = nil,
        disallowedPatterns: [String] = []
    ) -> ValidationResult {
        var violations: [ValidationViolation] = []
        var suggestions: [String] = []
        var sanitized = input

        // Check for null bytes
        if input.contains("\0") {
            violations.append(ValidationViolation(
                type: .nullByte,
                description: "Null bytes detected in input",
                position: input.firstIndex(of: "\0")?.utf16Offset(in: input)
            ))
            sanitized = sanitized.replacingOccurrences(of: "\0", with: "")
        }

        // Check length
        if input.count < minLength {
            violations.append(ValidationViolation(
                type: .lengthViolation,
                description: "Input too short (minimum \(minLength) characters)",
                position: nil
            ))
        }

        if input.count > maxLength {
            violations.append(ValidationViolation(
                type: .lengthViolation,
                description: "Input too long (maximum \(maxLength) characters)",
                position: maxLength
            ))
            sanitized = String(sanitized.prefix(maxLength))
            suggestions.append("Input was truncated to \(maxLength) characters")
        }

        // Check allowed characters
        if let allowedChars = allowedCharacters {
            let invalidChars = input.unicodeScalars.filter { !allowedChars.contains($0) }
            if !invalidChars.isEmpty {
                violations.append(ValidationViolation(
                    type: .invalidCharacters,
                    description: "Invalid characters found: \(String(invalidChars.map { Character($0) }))",
                    position: nil
                ))
                sanitized = String(sanitized.unicodeScalars.filter { allowedChars.contains($0) })
            }
        }

        // Check disallowed patterns
        for pattern in disallowedPatterns {
            if input.lowercased().contains(pattern.lowercased()) {
                violations.append(ValidationViolation(
                    type: .unsafePattern,
                    description: "Disallowed pattern detected: \(pattern)",
                    position: input.lowercased().range(of: pattern.lowercased())?.lowerBound.utf16Offset(in: input)
                ))
            }
        }

        // Check for common injection patterns
        let injectionPatterns = [
            "<script", "</script", "javascript:", "onerror=", "onload=",
            "'; DROP", "1=1", "' OR '", "\" OR \"", "UNION SELECT",
            "../", "..\\", "%2e%2e", "%252e"
        ]

        for pattern in injectionPatterns {
            if input.lowercased().contains(pattern.lowercased()) {
                violations.append(ValidationViolation(
                    type: .injectionAttempt,
                    description: "Potential injection pattern detected",
                    position: nil
                ))
                break
            }
        }

        return ValidationResult(
            isValid: violations.isEmpty,
            sanitizedValue: sanitized,
            violations: violations,
            suggestions: suggestions
        )
    }

    // MARK: - Email Validation

    /// Validate email address
    public func validateEmail(_ email: String) -> ValidationResult {
        var violations: [ValidationViolation] = []
        var suggestions: [String] = []

        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)

        // Basic format check
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)

        if !emailPredicate.evaluate(with: trimmed) {
            violations.append(ValidationViolation(
                type: .formatViolation,
                description: "Invalid email format",
                position: nil
            ))
            suggestions.append("Email should be in format: user@domain.com")
        }

        // Check length
        if trimmed.count > 254 {
            violations.append(ValidationViolation(
                type: .lengthViolation,
                description: "Email too long (maximum 254 characters)",
                position: 254
            ))
        }

        // Check for suspicious patterns
        let suspiciousPatterns = ["<", ">", "'", "\"", ";", "\\"]
        for pattern in suspiciousPatterns {
            if trimmed.contains(pattern) {
                violations.append(ValidationViolation(
                    type: .invalidCharacters,
                    description: "Suspicious character in email: \(pattern)",
                    position: nil
                ))
            }
        }

        return ValidationResult(
            isValid: violations.isEmpty,
            sanitizedValue: trimmed.lowercased(),
            violations: violations,
            suggestions: suggestions
        )
    }

    // MARK: - URL Validation

    /// Validate URL
    public func validateURL(_ urlString: String, allowedSchemes: [String] = ["https", "http"]) -> ValidationResult {
        var violations: [ValidationViolation] = []
        var suggestions: [String] = []

        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try to create URL
        guard let url = URL(string: trimmed) else {
            violations.append(ValidationViolation(
                type: .formatViolation,
                description: "Invalid URL format",
                position: nil
            ))
            return ValidationResult(isValid: false, sanitizedValue: trimmed, violations: violations, suggestions: ["Provide a valid URL"])
        }

        // Check scheme
        let scheme = url.scheme?.lowercased() ?? ""
        if !allowedSchemes.contains(scheme) {
            violations.append(ValidationViolation(
                type: .formatViolation,
                description: "URL scheme '\(scheme)' not allowed",
                position: nil
            ))
            suggestions.append("Allowed schemes: \(allowedSchemes.joined(separator: ", "))")
        }

        // Check for javascript: scheme (XSS)
        if scheme == "javascript" {
            violations.append(ValidationViolation(
                type: .injectionAttempt,
                description: "JavaScript URLs are not allowed",
                position: nil
            ))
        }

        // Check for data: scheme
        if scheme == "data" {
            violations.append(ValidationViolation(
                type: .injectionAttempt,
                description: "Data URLs are not allowed",
                position: nil
            ))
        }

        // Check host exists
        if url.host == nil || url.host?.isEmpty == true {
            violations.append(ValidationViolation(
                type: .formatViolation,
                description: "URL must have a valid host",
                position: nil
            ))
        }

        // Check for path traversal in URL
        if url.path.contains("..") {
            violations.append(ValidationViolation(
                type: .pathTraversal,
                description: "Path traversal detected in URL",
                position: nil
            ))
        }

        return ValidationResult(
            isValid: violations.isEmpty,
            sanitizedValue: trimmed,
            violations: violations,
            suggestions: suggestions
        )
    }

    // MARK: - File Path Validation

    /// Validate file path (prevents path traversal)
    public func validateFilePath(_ path: String, allowedDirectories: [String] = []) -> ValidationResult {
        var violations: [ValidationViolation] = []
        var suggestions: [String] = []

        let sanitized = path
            .replacingOccurrences(of: "..", with: "")
            .replacingOccurrences(of: "//", with: "/")

        // Check for path traversal
        if path.contains("..") {
            violations.append(ValidationViolation(
                type: .pathTraversal,
                description: "Path traversal sequences detected",
                position: path.range(of: "..")?.lowerBound.utf16Offset(in: path)
            ))
        }

        // Check for null bytes
        if path.contains("\0") {
            violations.append(ValidationViolation(
                type: .nullByte,
                description: "Null bytes in path",
                position: nil
            ))
        }

        // Check for absolute path if not allowed
        if path.hasPrefix("/") && !allowedDirectories.isEmpty {
            let isAllowed = allowedDirectories.contains { path.hasPrefix($0) }
            if !isAllowed {
                violations.append(ValidationViolation(
                    type: .pathTraversal,
                    description: "Path outside allowed directories",
                    position: nil
                ))
                suggestions.append("Path must be within: \(allowedDirectories.joined(separator: ", "))")
            }
        }

        // Check for dangerous characters
        let dangerousChars = ["|", ";", "&", "$", "`", "(", ")", "{", "}", "[", "]", "!", "<", ">"]
        for char in dangerousChars {
            if path.contains(char) {
                violations.append(ValidationViolation(
                    type: .invalidCharacters,
                    description: "Dangerous character in path: \(char)",
                    position: nil
                ))
            }
        }

        return ValidationResult(
            isValid: violations.isEmpty,
            sanitizedValue: sanitized,
            violations: violations,
            suggestions: suggestions
        )
    }

    // MARK: - Username Validation

    /// Validate username
    public func validateUsername(
        _ username: String,
        minLength: Int = 3,
        maxLength: Int = 30
    ) -> ValidationResult {
        var violations: [ValidationViolation] = []
        var suggestions: [String] = []

        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)

        // Length check
        if trimmed.count < minLength {
            violations.append(ValidationViolation(
                type: .lengthViolation,
                description: "Username too short (minimum \(minLength) characters)",
                position: nil
            ))
        }

        if trimmed.count > maxLength {
            violations.append(ValidationViolation(
                type: .lengthViolation,
                description: "Username too long (maximum \(maxLength) characters)",
                position: nil
            ))
        }

        // Format check (alphanumeric, underscore, hyphen)
        let usernameRegex = "^[a-zA-Z0-9_-]+$"
        let usernamePredicate = NSPredicate(format: "SELF MATCHES %@", usernameRegex)

        if !usernamePredicate.evaluate(with: trimmed) {
            violations.append(ValidationViolation(
                type: .formatViolation,
                description: "Username can only contain letters, numbers, underscores, and hyphens",
                position: nil
            ))
        }

        // Reserved usernames
        let reservedUsernames = [
            "admin", "administrator", "root", "system", "support",
            "help", "api", "www", "mail", "ftp", "localhost",
            "echoelmusic", "official", "verified"
        ]

        if reservedUsernames.contains(trimmed.lowercased()) {
            violations.append(ValidationViolation(
                type: .reservedWord,
                description: "This username is reserved",
                position: nil
            ))
        }

        return ValidationResult(
            isValid: violations.isEmpty,
            sanitizedValue: trimmed,
            violations: violations,
            suggestions: suggestions
        )
    }

    // MARK: - Password Validation

    /// Validate password strength
    public func validatePassword(
        _ password: String,
        minLength: Int = 8,
        requireUppercase: Bool = true,
        requireLowercase: Bool = true,
        requireNumber: Bool = true,
        requireSpecial: Bool = true
    ) -> ValidationResult {
        var violations: [ValidationViolation] = []
        var suggestions: [String] = []

        // Length check
        if password.count < minLength {
            violations.append(ValidationViolation(
                type: .lengthViolation,
                description: "Password too short (minimum \(minLength) characters)",
                position: nil
            ))
            suggestions.append("Use at least \(minLength) characters")
        }

        // Uppercase check
        if requireUppercase && !password.contains(where: { $0.isUppercase }) {
            violations.append(ValidationViolation(
                type: .formatViolation,
                description: "Password must contain uppercase letter",
                position: nil
            ))
            suggestions.append("Add at least one uppercase letter (A-Z)")
        }

        // Lowercase check
        if requireLowercase && !password.contains(where: { $0.isLowercase }) {
            violations.append(ValidationViolation(
                type: .formatViolation,
                description: "Password must contain lowercase letter",
                position: nil
            ))
            suggestions.append("Add at least one lowercase letter (a-z)")
        }

        // Number check
        if requireNumber && !password.contains(where: { $0.isNumber }) {
            violations.append(ValidationViolation(
                type: .formatViolation,
                description: "Password must contain number",
                position: nil
            ))
            suggestions.append("Add at least one number (0-9)")
        }

        // Special character check
        let specialChars = CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;':\",./<>?")
        if requireSpecial && !password.unicodeScalars.contains(where: { specialChars.contains($0) }) {
            violations.append(ValidationViolation(
                type: .formatViolation,
                description: "Password must contain special character",
                position: nil
            ))
            suggestions.append("Add at least one special character (!@#$%^&*)")
        }

        // Common password check
        let commonPasswords = [
            "password", "123456", "12345678", "qwerty", "abc123",
            "monkey", "1234567", "letmein", "trustno1", "dragon"
        ]

        if commonPasswords.contains(password.lowercased()) {
            violations.append(ValidationViolation(
                type: .unsafePattern,
                description: "This is a commonly used password",
                position: nil
            ))
            suggestions.append("Choose a unique password")
        }

        // Note: Never return the actual password in sanitizedValue
        return ValidationResult(
            isValid: violations.isEmpty,
            sanitizedValue: "",
            violations: violations,
            suggestions: suggestions
        )
    }

    // MARK: - Phone Number Validation

    /// Validate phone number
    public func validatePhoneNumber(_ phone: String) -> ValidationResult {
        var violations: [ValidationViolation] = []
        var suggestions: [String] = []

        // Remove common formatting characters
        let sanitized = phone.components(separatedBy: CharacterSet(charactersIn: "0123456789+").inverted).joined()

        // Check if it contains only digits (and optional +)
        let phoneRegex = "^\\+?[0-9]{7,15}$"
        let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)

        if !phonePredicate.evaluate(with: sanitized) {
            violations.append(ValidationViolation(
                type: .formatViolation,
                description: "Invalid phone number format",
                position: nil
            ))
            suggestions.append("Phone number should contain 7-15 digits")
        }

        return ValidationResult(
            isValid: violations.isEmpty,
            sanitizedValue: sanitized,
            violations: violations,
            suggestions: suggestions
        )
    }

    // MARK: - JSON Validation

    /// Validate JSON input
    public func validateJSON(_ jsonString: String, maxDepth: Int = 20) -> ValidationResult {
        var violations: [ValidationViolation] = []
        var suggestions: [String] = []

        // Check for null bytes
        if jsonString.contains("\0") {
            violations.append(ValidationViolation(
                type: .nullByte,
                description: "Null bytes in JSON",
                position: nil
            ))
        }

        // Try to parse
        guard let data = jsonString.data(using: .utf8) else {
            violations.append(ValidationViolation(
                type: .encodingIssue,
                description: "Invalid UTF-8 encoding",
                position: nil
            ))
            return ValidationResult(isValid: false, sanitizedValue: "", violations: violations, suggestions: suggestions)
        }

        do {
            let _ = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            violations.append(ValidationViolation(
                type: .formatViolation,
                description: "Invalid JSON: \(error.localizedDescription)",
                position: nil
            ))
        }

        // Check depth (prevent deeply nested JSON attacks)
        var depth = 0
        var maxDetectedDepth = 0
        for char in jsonString {
            if char == "{" || char == "[" {
                depth += 1
                maxDetectedDepth = max(maxDetectedDepth, depth)
            } else if char == "}" || char == "]" {
                depth -= 1
            }
        }

        if maxDetectedDepth > maxDepth {
            violations.append(ValidationViolation(
                type: .unsafePattern,
                description: "JSON nesting too deep (max \(maxDepth) levels)",
                position: nil
            ))
        }

        return ValidationResult(
            isValid: violations.isEmpty,
            sanitizedValue: jsonString,
            violations: violations,
            suggestions: suggestions
        )
    }

    // MARK: - Numeric Validation

    /// Validate numeric input
    public func validateNumeric<T: Numeric & Comparable>(
        _ value: T,
        min: T? = nil,
        max: T? = nil
    ) -> ValidationResult {
        var violations: [ValidationViolation] = []

        if let minValue = min, value < minValue {
            violations.append(ValidationViolation(
                type: .formatViolation,
                description: "Value below minimum (\(minValue))",
                position: nil
            ))
        }

        if let maxValue = max, value > maxValue {
            violations.append(ValidationViolation(
                type: .formatViolation,
                description: "Value above maximum (\(maxValue))",
                position: nil
            ))
        }

        return ValidationResult(
            isValid: violations.isEmpty,
            sanitizedValue: "\(value)",
            violations: violations,
            suggestions: []
        )
    }

    // MARK: - HTML Sanitization

    /// Sanitize HTML input (remove dangerous tags)
    public func sanitizeHTML(_ html: String) -> String {
        var sanitized = html

        // Remove script tags and content
        let scriptPattern = "<script[^>]*>[\\s\\S]*?</script>"
        sanitized = sanitized.replacingOccurrences(of: scriptPattern, with: "", options: .regularExpression)

        // Remove on* attributes (event handlers)
        let eventPattern = "\\s+on\\w+\\s*=\\s*[\"'][^\"']*[\"']"
        sanitized = sanitized.replacingOccurrences(of: eventPattern, with: "", options: .regularExpression)

        // Remove javascript: URLs
        sanitized = sanitized.replacingOccurrences(of: "javascript:", with: "", options: .caseInsensitive)

        // Remove data: URLs
        sanitized = sanitized.replacingOccurrences(of: "data:", with: "", options: .caseInsensitive)

        // Remove style tags
        let stylePattern = "<style[^>]*>[\\s\\S]*?</style>"
        sanitized = sanitized.replacingOccurrences(of: stylePattern, with: "", options: .regularExpression)

        // Remove iframe tags
        let iframePattern = "<iframe[^>]*>[\\s\\S]*?</iframe>"
        sanitized = sanitized.replacingOccurrences(of: iframePattern, with: "", options: .regularExpression)

        // Remove object/embed tags
        let objectPattern = "<(object|embed)[^>]*>[\\s\\S]*?</(object|embed)>"
        sanitized = sanitized.replacingOccurrences(of: objectPattern, with: "", options: .regularExpression)

        return sanitized
    }

    // MARK: - SQL Sanitization

    /// Escape SQL special characters (for parameterized queries, not string concatenation!)
    public func escapeSQLSpecialChars(_ input: String) -> String {
        var escaped = input
        escaped = escaped.replacingOccurrences(of: "'", with: "''")
        escaped = escaped.replacingOccurrences(of: "\\", with: "\\\\")
        escaped = escaped.replacingOccurrences(of: "\0", with: "")
        return escaped
    }
}

// MARK: - Validation Convenience Extensions

public extension String {

    /// Validate as email
    var isValidEmail: Bool {
        InputValidationManager.shared.validateEmail(self).isValid
    }

    /// Validate as URL
    var isValidURL: Bool {
        InputValidationManager.shared.validateURL(self).isValid
    }

    /// Validate as username
    var isValidUsername: Bool {
        InputValidationManager.shared.validateUsername(self).isValid
    }

    /// Sanitize as HTML
    var htmlSanitized: String {
        InputValidationManager.shared.sanitizeHTML(self)
    }

    /// Validate and sanitize general string
    func validated(maxLength: Int = 10000) -> InputValidationManager.ValidationResult {
        InputValidationManager.shared.validateString(self, maxLength: maxLength)
    }
}

// MARK: - Property Wrapper for Validated Input

/// Property wrapper that automatically validates input
@propertyWrapper
public struct ValidatedInput: Sendable {
    private var value: String
    private let validator: @Sendable (String) -> InputValidationManager.ValidationResult

    public var wrappedValue: String {
        get { value }
        set {
            let result = validator(newValue)
            value = result.sanitizedValue
        }
    }

    public var projectedValue: InputValidationManager.ValidationResult {
        validator(value)
    }

    public init(wrappedValue: String, validator: @escaping @Sendable (String) -> InputValidationManager.ValidationResult) {
        self.validator = validator
        let result = validator(wrappedValue)
        self.value = result.sanitizedValue
    }

    public init(wrappedValue: String, maxLength: Int = 10000) {
        self.init(wrappedValue: wrappedValue) { input in
            InputValidationManager.shared.validateString(input, maxLength: maxLength)
        }
    }
}

/// Property wrapper for validated email
@propertyWrapper
public struct ValidatedEmail: Sendable {
    private var value: String

    public var wrappedValue: String {
        get { value }
        set {
            let result = InputValidationManager.shared.validateEmail(newValue)
            value = result.isValid ? result.sanitizedValue : value
        }
    }

    public var projectedValue: InputValidationManager.ValidationResult {
        InputValidationManager.shared.validateEmail(value)
    }

    public init(wrappedValue: String) {
        let result = InputValidationManager.shared.validateEmail(wrappedValue)
        self.value = result.sanitizedValue
    }
}
