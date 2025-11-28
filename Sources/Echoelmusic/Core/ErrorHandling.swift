//
//  ErrorHandling.swift
//  Echoelmusic
//
//  Created: 2025-11-28
//  Comprehensive Error Handling & Recovery System
//
//  Features:
//  - Typed errors for all domains
//  - Result type extensions
//  - Automatic recovery strategies
//  - Error logging and telemetry
//  - User-friendly error presentation
//  - Retry policies with exponential backoff
//

import Foundation
import Combine

// MARK: - Domain Errors

/// Audio-related errors
public enum AudioError: LocalizedError, Equatable {
    case engineNotRunning
    case deviceNotFound(String)
    case deviceUnavailable(String)
    case sampleRateMismatch(expected: Double, actual: Double)
    case bufferUnderrun
    case bufferOverrun
    case formatNotSupported(String)
    case permissionDenied
    case fileNotFound(URL)
    case codecError(String)
    case midiConnectionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .engineNotRunning:
            return "Audio engine is not running"
        case .deviceNotFound(let name):
            return "Audio device '\(name)' not found"
        case .deviceUnavailable(let name):
            return "Audio device '\(name)' is unavailable"
        case .sampleRateMismatch(let expected, let actual):
            return "Sample rate mismatch: expected \(Int(expected))Hz, got \(Int(actual))Hz"
        case .bufferUnderrun:
            return "Audio buffer underrun - increase buffer size"
        case .bufferOverrun:
            return "Audio buffer overrun - reduce load"
        case .formatNotSupported(let format):
            return "Audio format '\(format)' is not supported"
        case .permissionDenied:
            return "Microphone access denied"
        case .fileNotFound(let url):
            return "Audio file not found: \(url.lastPathComponent)"
        case .codecError(let codec):
            return "Codec error: \(codec)"
        case .midiConnectionFailed(let device):
            return "MIDI connection failed: \(device)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .engineNotRunning:
            return "Try restarting the audio engine"
        case .deviceNotFound, .deviceUnavailable:
            return "Check your audio device connections"
        case .sampleRateMismatch:
            return "Check project sample rate settings"
        case .bufferUnderrun:
            return "Try increasing the buffer size in Settings > Audio"
        case .bufferOverrun:
            return "Reduce the number of active plugins or tracks"
        case .formatNotSupported:
            return "Convert the file to a supported format (WAV, AIFF, MP3, AAC)"
        case .permissionDenied:
            return "Enable microphone access in System Settings > Privacy"
        case .fileNotFound:
            return "Locate the missing file or remove it from the project"
        case .codecError:
            return "Try re-encoding the file"
        case .midiConnectionFailed:
            return "Check MIDI device connections and restart"
        }
    }

    public var isRecoverable: Bool {
        switch self {
        case .bufferUnderrun, .bufferOverrun, .engineNotRunning:
            return true
        case .permissionDenied, .formatNotSupported, .fileNotFound:
            return false
        default:
            return true
        }
    }
}

/// Video-related errors
public enum VideoError: LocalizedError, Equatable {
    case codecNotSupported(String)
    case resolutionNotSupported(Int, Int)
    case frameRateMismatch
    case exportFailed(String)
    case renderingFailed(String)
    case fileCorrupted(URL)
    case diskSpaceInsufficient(required: Int64, available: Int64)
    case gpuMemoryExhausted
    case proxyGenerationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .codecNotSupported(let codec):
            return "Video codec '\(codec)' is not supported"
        case .resolutionNotSupported(let w, let h):
            return "Resolution \(w)x\(h) is not supported"
        case .frameRateMismatch:
            return "Frame rate mismatch in project"
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        case .renderingFailed(let reason):
            return "Rendering failed: \(reason)"
        case .fileCorrupted(let url):
            return "Video file is corrupted: \(url.lastPathComponent)"
        case .diskSpaceInsufficient(let required, let available):
            return "Insufficient disk space: need \(formatBytes(required)), have \(formatBytes(available))"
        case .gpuMemoryExhausted:
            return "GPU memory exhausted"
        case .proxyGenerationFailed(let reason):
            return "Proxy generation failed: \(reason)"
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

/// Network-related errors
public enum NetworkError: LocalizedError, Equatable {
    case noConnection
    case timeout(TimeInterval)
    case serverError(Int)
    case unauthorized
    case rateLimited(retryAfter: TimeInterval)
    case invalidResponse
    case sslError(String)
    case dnsLookupFailed(String)

    public var errorDescription: String? {
        switch self {
        case .noConnection:
            return "No internet connection"
        case .timeout(let duration):
            return "Request timed out after \(Int(duration)) seconds"
        case .serverError(let code):
            return "Server error (HTTP \(code))"
        case .unauthorized:
            return "Authentication required"
        case .rateLimited(let retryAfter):
            return "Rate limited - try again in \(Int(retryAfter)) seconds"
        case .invalidResponse:
            return "Invalid server response"
        case .sslError(let reason):
            return "SSL/TLS error: \(reason)"
        case .dnsLookupFailed(let host):
            return "DNS lookup failed for \(host)"
        }
    }

    public var isRetryable: Bool {
        switch self {
        case .noConnection, .timeout, .serverError, .rateLimited:
            return true
        case .unauthorized, .invalidResponse, .sslError, .dnsLookupFailed:
            return false
        }
    }
}

/// File-related errors
public enum FileError: LocalizedError, Equatable {
    case notFound(URL)
    case accessDenied(URL)
    case alreadyExists(URL)
    case invalidFormat(String)
    case tooLarge(maxSize: Int64, actualSize: Int64)
    case writeError(String)
    case readError(String)
    case checksumMismatch

    public var errorDescription: String? {
        switch self {
        case .notFound(let url):
            return "File not found: \(url.lastPathComponent)"
        case .accessDenied(let url):
            return "Access denied: \(url.lastPathComponent)"
        case .alreadyExists(let url):
            return "File already exists: \(url.lastPathComponent)"
        case .invalidFormat(let format):
            return "Invalid file format: \(format)"
        case .tooLarge(let max, let actual):
            return "File too large: \(formatBytes(actual)) (max \(formatBytes(max)))"
        case .writeError(let reason):
            return "Write error: \(reason)"
        case .readError(let reason):
            return "Read error: \(reason)"
        case .checksumMismatch:
            return "File checksum mismatch - file may be corrupted"
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

/// Lighting/DMX errors
public enum LightingError: LocalizedError, Equatable {
    case connectionFailed(protocol: String, reason: String)
    case universeNotFound(Int)
    case deviceOffline(String)
    case invalidDMXData
    case artNetDiscoveryFailed
    case sacnMulticastFailed

    public var errorDescription: String? {
        switch self {
        case .connectionFailed(let proto, let reason):
            return "\(proto) connection failed: \(reason)"
        case .universeNotFound(let universe):
            return "DMX universe \(universe) not found"
        case .deviceOffline(let device):
            return "Lighting device offline: \(device)"
        case .invalidDMXData:
            return "Invalid DMX data"
        case .artNetDiscoveryFailed:
            return "Art-Net device discovery failed"
        case .sacnMulticastFailed:
            return "sACN multicast setup failed"
        }
    }
}

/// Biofeedback/Health errors
public enum BiofeedbackError: LocalizedError, Equatable {
    case healthKitNotAvailable
    case authorizationDenied
    case sensorNotConnected
    case dataTooOld(age: TimeInterval)
    case invalidReading
    case sessionInterrupted

    public var errorDescription: String? {
        switch self {
        case .healthKitNotAvailable:
            return "HealthKit is not available on this device"
        case .authorizationDenied:
            return "Health data access denied"
        case .sensorNotConnected:
            return "Biofeedback sensor not connected"
        case .dataTooOld(let age):
            return "Biofeedback data is \(Int(age)) seconds old"
        case .invalidReading:
            return "Invalid biofeedback reading"
        case .sessionInterrupted:
            return "Biofeedback session was interrupted"
        }
    }
}

// MARK: - App Error

/// Unified error type that wraps all domain errors
public enum AppError: LocalizedError {
    case audio(AudioError)
    case video(VideoError)
    case network(NetworkError)
    case file(FileError)
    case lighting(LightingError)
    case biofeedback(BiofeedbackError)
    case unknown(Error)
    case validation(String)
    case internal(String)

    public var errorDescription: String? {
        switch self {
        case .audio(let error): return error.errorDescription
        case .video(let error): return error.errorDescription
        case .network(let error): return error.errorDescription
        case .file(let error): return error.errorDescription
        case .lighting(let error): return error.errorDescription
        case .biofeedback(let error): return error.errorDescription
        case .unknown(let error): return error.localizedDescription
        case .validation(let message): return "Validation error: \(message)"
        case .internal(let message): return "Internal error: \(message)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .audio(let error): return error.recoverySuggestion
        default: return nil
        }
    }

    public var isRecoverable: Bool {
        switch self {
        case .audio(let error): return error.isRecoverable
        case .network(let error): return error.isRetryable
        default: return false
        }
    }

    public var domain: String {
        switch self {
        case .audio: return "Audio"
        case .video: return "Video"
        case .network: return "Network"
        case .file: return "File"
        case .lighting: return "Lighting"
        case .biofeedback: return "Biofeedback"
        case .unknown: return "Unknown"
        case .validation: return "Validation"
        case .internal: return "Internal"
        }
    }
}

// MARK: - Result Extensions

public extension Result where Failure == AppError {
    /// Map success value while preserving error type
    func mapValue<NewSuccess>(_ transform: (Success) -> NewSuccess) -> Result<NewSuccess, AppError> {
        switch self {
        case .success(let value):
            return .success(transform(value))
        case .failure(let error):
            return .failure(error)
        }
    }

    /// Flat map with async transform
    func flatMapAsync<NewSuccess>(_ transform: (Success) async throws -> NewSuccess) async -> Result<NewSuccess, AppError> {
        switch self {
        case .success(let value):
            do {
                let newValue = try await transform(value)
                return .success(newValue)
            } catch let error as AppError {
                return .failure(error)
            } catch {
                return .failure(.unknown(error))
            }
        case .failure(let error):
            return .failure(error)
        }
    }

    /// Recover from error with default value
    func recover(_ defaultValue: Success) -> Success {
        switch self {
        case .success(let value): return value
        case .failure: return defaultValue
        }
    }

    /// Recover from error with transform
    func recover(_ transform: (AppError) -> Success) -> Success {
        switch self {
        case .success(let value): return value
        case .failure(let error): return transform(error)
        }
    }

    /// Log error if present
    func logError(context: String = "") -> Result<Success, AppError> {
        if case .failure(let error) = self {
            ErrorLogger.shared.log(error, context: context)
        }
        return self
    }
}

// MARK: - Retry Policy

/// Configuration for retry behavior
public struct RetryPolicy {
    public let maxAttempts: Int
    public let initialDelay: TimeInterval
    public let maxDelay: TimeInterval
    public let multiplier: Double
    public let jitter: Bool

    public static let `default` = RetryPolicy(
        maxAttempts: 3,
        initialDelay: 1.0,
        maxDelay: 30.0,
        multiplier: 2.0,
        jitter: true
    )

    public static let aggressive = RetryPolicy(
        maxAttempts: 5,
        initialDelay: 0.5,
        maxDelay: 60.0,
        multiplier: 2.0,
        jitter: true
    )

    public static let conservative = RetryPolicy(
        maxAttempts: 2,
        initialDelay: 2.0,
        maxDelay: 10.0,
        multiplier: 1.5,
        jitter: false
    )

    public init(maxAttempts: Int, initialDelay: TimeInterval, maxDelay: TimeInterval, multiplier: Double, jitter: Bool) {
        self.maxAttempts = maxAttempts
        self.initialDelay = initialDelay
        self.maxDelay = maxDelay
        self.multiplier = multiplier
        self.jitter = jitter
    }

    public func delay(forAttempt attempt: Int) -> TimeInterval {
        var delay = initialDelay * pow(multiplier, Double(attempt - 1))
        delay = min(delay, maxDelay)

        if jitter {
            delay *= Double.random(in: 0.8...1.2)
        }

        return delay
    }
}

// MARK: - Retry Helper

/// Retry an async operation with exponential backoff
public func withRetry<T>(
    policy: RetryPolicy = .default,
    shouldRetry: @escaping (Error) -> Bool = { _ in true },
    operation: @escaping () async throws -> T
) async throws -> T {
    var lastError: Error?
    var attempt = 0

    while attempt < policy.maxAttempts {
        attempt += 1

        do {
            return try await operation()
        } catch {
            lastError = error

            guard shouldRetry(error), attempt < policy.maxAttempts else {
                throw error
            }

            let delay = policy.delay(forAttempt: attempt)
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
    }

    throw lastError ?? AppError.internal("Retry exhausted without error")
}

// MARK: - Error Logger

/// Central error logging service
@MainActor
public final class ErrorLogger: ObservableObject {
    public static let shared = ErrorLogger()

    @Published public private(set) var recentErrors: [LoggedError] = []
    private let maxErrors = 100

    public struct LoggedError: Identifiable {
        public let id: UUID
        public let error: AppError
        public let context: String
        public let timestamp: Date
        public let stackTrace: [String]
    }

    private init() {}

    public func log(_ error: AppError, context: String = "", file: String = #file, function: String = #function, line: Int = #line) {
        let stackTrace = Thread.callStackSymbols

        let logged = LoggedError(
            id: UUID(),
            error: error,
            context: context.isEmpty ? "\(file):\(line) \(function)" : context,
            timestamp: Date(),
            stackTrace: stackTrace
        )

        recentErrors.insert(logged, at: 0)

        if recentErrors.count > maxErrors {
            recentErrors.removeLast()
        }

        // Print to console in debug mode
        #if DEBUG
        print("[\(error.domain)] \(error.errorDescription ?? "Unknown error") - \(context)")
        #endif
    }

    public func log(_ error: Error, context: String = "") {
        if let appError = error as? AppError {
            log(appError, context: context)
        } else {
            log(.unknown(error), context: context)
        }
    }

    public func clearLogs() {
        recentErrors.removeAll()
    }

    /// Export logs for support
    public func exportLogs() -> String {
        recentErrors.map { error in
            """
            [\(error.timestamp)] [\(error.error.domain)]
            Error: \(error.error.errorDescription ?? "Unknown")
            Context: \(error.context)
            """
        }.joined(separator: "\n\n")
    }
}

// MARK: - Error Recovery Actions

/// Standard recovery actions for common errors
public struct ErrorRecoveryAction: Identifiable {
    public let id: UUID
    public let title: String
    public let action: () async throws -> Void
    public let isDestructive: Bool

    public init(title: String, isDestructive: Bool = false, action: @escaping () async throws -> Void) {
        self.id = UUID()
        self.title = title
        self.isDestructive = isDestructive
        self.action = action
    }
}

/// Generate recovery actions for an error
public func recoveryActions(for error: AppError) -> [ErrorRecoveryAction] {
    var actions: [ErrorRecoveryAction] = []

    switch error {
    case .audio(.engineNotRunning):
        actions.append(ErrorRecoveryAction(title: "Restart Audio Engine") {
            // Restart audio engine
        })

    case .audio(.bufferUnderrun), .audio(.bufferOverrun):
        actions.append(ErrorRecoveryAction(title: "Increase Buffer Size") {
            // Adjust buffer size
        })

    case .network(.noConnection):
        actions.append(ErrorRecoveryAction(title: "Check Connection") {
            // Open network settings
        })

    case .network(.rateLimited(let retryAfter)):
        actions.append(ErrorRecoveryAction(title: "Retry in \(Int(retryAfter))s") {
            try await Task.sleep(nanoseconds: UInt64(retryAfter * 1_000_000_000))
        })

    case .file(.accessDenied):
        actions.append(ErrorRecoveryAction(title: "Grant Access") {
            // Request file access
        })

    default:
        break
    }

    // Always add dismiss option
    actions.append(ErrorRecoveryAction(title: "Dismiss", isDestructive: false) {})

    return actions
}

// MARK: - Throwing Helpers

/// Convert optional to result with error
public extension Optional {
    func toResult(orError error: AppError) -> Result<Wrapped, AppError> {
        switch self {
        case .some(let value):
            return .success(value)
        case .none:
            return .failure(error)
        }
    }

    func orThrow(_ error: AppError) throws -> Wrapped {
        guard let value = self else {
            throw error
        }
        return value
    }
}

// MARK: - Task Error Handling

public extension Task where Success == Never, Failure == Never {
    /// Run an async operation with error handling
    static func run(
        priority: TaskPriority? = nil,
        operation: @escaping () async throws -> Void,
        onError: @escaping (AppError) -> Void
    ) {
        Task(priority: priority) {
            do {
                try await operation()
            } catch let error as AppError {
                await MainActor.run { onError(error) }
            } catch {
                await MainActor.run { onError(.unknown(error)) }
            }
        }
    }
}
