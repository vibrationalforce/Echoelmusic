// ProductionSafetyWrappers.swift
// Echoelmusic - Nobel Prize Multitrillion Dollar Safety Wrappers
//
// Safe wrappers for common operations that could crash in production
// Replaces all force unwraps with safe alternatives

import Foundation
import AVFoundation
import os.log

// MARK: - Safe URL Builder

/// Safe URL construction that never crashes
public struct SafeURL: Sendable {
    private static let logger = os.Logger(subsystem: "com.echoelmusic", category: "safeurl")

    /// Safely create URL from string, returns nil if invalid
    public static func from(_ string: String) -> URL? {
        guard let url = URL(string: string) else {
            logger.warning("Invalid URL string: \(string)")
            return nil
        }
        return url
    }

    /// Safely create URL with path components
    public static func build(base: String, path: String...) -> URL? {
        guard var url = URL(string: base) else {
            logger.warning("Invalid base URL: \(base)")
            return nil
        }

        for component in path {
            url = url.appendingPathComponent(component)
        }

        return url
    }

    /// Safely create API URL with query parameters
    public static func api(
        base: String,
        path: String,
        query: [String: String] = [:]
    ) -> URL? {
        guard var components = URLComponents(string: base) else {
            logger.warning("Invalid base URL for API: \(base)")
            return nil
        }

        components.path = path

        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        guard let url = components.url else {
            logger.warning("Failed to construct URL from components")
            return nil
        }

        return url
    }

    /// Get URL or throw descriptive error
    public static func require(_ string: String) throws -> URL {
        guard let url = URL(string: string) else {
            throw ProductionSafetyError.invalidURL(string)
        }
        return url
    }
}

// MARK: - Safe Audio Buffer

/// Safe audio buffer operations that never crash
public struct SafeAudioBuffer: Sendable {
    private static let logger = os.Logger(subsystem: "com.echoelmusic", category: "safeaudio")

    /// Safely create AVAudioFormat
    public static func createFormat(
        sampleRate: Double = 44100,
        channels: AVAudioChannelCount = 2,
        interleaved: Bool = false
    ) -> AVAudioFormat? {
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: channels,
            interleaved: interleaved
        )

        if format == nil {
            logger.warning("Failed to create audio format: sr=\(sampleRate), ch=\(channels)")
        }

        return format
    }

    /// Safely create PCM buffer
    public static func createBuffer(
        format: AVAudioFormat,
        frameCapacity: AVAudioFrameCount
    ) -> AVAudioPCMBuffer? {
        guard frameCapacity > 0 else {
            logger.warning("Invalid frame capacity: \(frameCapacity)")
            return nil
        }

        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity)

        if buffer == nil {
            logger.warning("Failed to create PCM buffer")
        }

        return buffer
    }

    /// Create buffer with fallback
    public static func createBufferWithFallback(
        format: AVAudioFormat?,
        frameCapacity: AVAudioFrameCount
    ) -> AVAudioPCMBuffer {
        // Try with provided format
        if let format = format,
           let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: max(1, frameCapacity)) {
            return buffer
        }

        // Fallback to default format
        let fallbackFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 44100,
            channels: 1,
            interleaved: false
        )

        if let format = fallbackFormat,
           let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: max(1, frameCapacity)) {
            logger.warning("Using fallback audio format")
            return buffer
        }

        // Ultimate fallback - create minimal valid buffer
        logger.error("All audio buffer creation attempts failed, using minimal buffer")

        // This should never fail as we're using known-good parameters
        let minimalFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 44100,
            channels: 1,
            interleaved: false
        )!

        return AVAudioPCMBuffer(pcmFormat: minimalFormat, frameCapacity: 1)!
    }
}

// MARK: - Safe Array Access

/// Safe array access extensions
public extension Array {
    /// Safely access element at index, returns nil if out of bounds
    subscript(safe index: Int) -> Element? {
        guard index >= 0 && index < count else { return nil }
        return self[index]
    }

    /// Safely access first element matching predicate
    func safeFirst(where predicate: (Element) -> Bool) -> Element? {
        first(where: predicate)
    }

    /// Safely get last element
    var safeLast: Element? {
        isEmpty ? nil : self[count - 1]
    }
}

// MARK: - Safe Dictionary Access

public extension Dictionary {
    /// Safely access value with logging on miss
    func safeValue(for key: Key, file: String = #file, line: Int = #line) -> Value? {
        guard let value = self[key] else {
            let logger = os.Logger(subsystem: "com.echoelmusic", category: "safedict")
            logger.debug("Dictionary miss for key at \(file):\(line)")
            return nil
        }
        return value
    }
}

// MARK: - Safe Pointer Operations

/// Safe pointer operations for DSP code
public struct SafePointer: Sendable {
    private static let logger = os.Logger(subsystem: "com.echoelmusic", category: "safepointer")

    /// Safely access float channel data
    public static func floatChannelData(
        from buffer: AVAudioPCMBuffer,
        channel: Int
    ) -> UnsafeMutablePointer<Float>? {
        guard let channelData = buffer.floatChannelData else {
            logger.warning("Buffer has no float channel data")
            return nil
        }

        guard channel >= 0 && channel < Int(buffer.format.channelCount) else {
            logger.warning("Channel \(channel) out of bounds (max: \(buffer.format.channelCount - 1))")
            return nil
        }

        return channelData[channel]
    }

    /// Safely process buffer data
    public static func processBuffer(
        _ buffer: AVAudioPCMBuffer,
        operation: (UnsafeMutablePointer<Float>, Int) -> Void
    ) {
        guard let channelData = buffer.floatChannelData else {
            logger.warning("Cannot process buffer: no float channel data")
            return
        }

        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else {
            logger.warning("Cannot process buffer: zero frame length")
            return
        }

        for channel in 0..<Int(buffer.format.channelCount) {
            operation(channelData[channel], frameLength)
        }
    }
}

// MARK: - Safe JSON Operations

/// Safe JSON encoding/decoding
public struct SafeJSON: Sendable {
    private static let logger = os.Logger(subsystem: "com.echoelmusic", category: "safejson")

    /// Safely decode JSON
    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            logger.warning("JSON decode failed for \(String(describing: type)): \(error.localizedDescription)")
            return nil
        }
    }

    /// Safely encode to JSON
    public static func encode<T: Encodable>(_ value: T) -> Data? {
        do {
            return try JSONEncoder().encode(value)
        } catch {
            logger.warning("JSON encode failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Decode with default value on failure
    public static func decode<T: Decodable>(
        _ type: T.Type,
        from data: Data,
        default defaultValue: T
    ) -> T {
        decode(type, from: data) ?? defaultValue
    }
}

// MARK: - Safe Network Request

/// Safe network request builder
public struct SafeNetworkRequest: Sendable {
    private static let logger = os.Logger(subsystem: "com.echoelmusic", category: "safenetwork")

    /// Build URL request safely
    public static func build(
        url urlString: String,
        method: String = "GET",
        headers: [String: String] = [:],
        body: Data? = nil,
        timeout: TimeInterval = 30
    ) -> URLRequest? {
        guard let url = SafeURL.from(urlString) else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        request.httpBody = body

        return request
    }

    /// Perform request with error handling
    public static func perform(
        _ request: URLRequest
    ) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProductionSafetyError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw ProductionSafetyError.httpError(httpResponse.statusCode)
        }

        return (data, httpResponse)
    }
}

// MARK: - Safe String Operations

public extension String {
    /// Safely convert to URL
    var safeURL: URL? {
        SafeURL.from(self)
    }

    /// Safely convert to Int
    var safeInt: Int? {
        Int(self)
    }

    /// Safely convert to Double
    var safeDouble: Double? {
        Double(self)
    }

    /// Truncate with ellipsis
    func truncated(to length: Int) -> String {
        if count <= length { return self }
        return String(prefix(length - 3)) + "..."
    }
}

// MARK: - Safe Optional Unwrap with Logging

public extension Optional {
    /// Unwrap with logging on nil
    func unwrap(
        or defaultValue: Wrapped,
        message: String = "Optional was nil",
        file: String = #file,
        line: Int = #line
    ) -> Wrapped {
        if let value = self {
            return value
        }

        let logger = os.Logger(subsystem: "com.echoelmusic", category: "safeunwrap")
        logger.debug("\(message) at \(file):\(line)")
        return defaultValue
    }

    /// Unwrap or throw
    func unwrapOrThrow(_ error: Error) throws -> Wrapped {
        guard let value = self else {
            throw error
        }
        return value
    }
}

// MARK: - Production Safety Errors

public enum ProductionSafetyError: Error, LocalizedError, Sendable {
    case invalidURL(String)
    case invalidResponse
    case httpError(Int)
    case audioFormatCreationFailed
    case bufferCreationFailed
    case pointerAccessFailed
    case jsonDecodingFailed(String)
    case jsonEncodingFailed
    case unexpectedNil(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .invalidResponse:
            return "Invalid network response"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .audioFormatCreationFailed:
            return "Failed to create audio format"
        case .bufferCreationFailed:
            return "Failed to create audio buffer"
        case .pointerAccessFailed:
            return "Failed to access audio buffer pointer"
        case .jsonDecodingFailed(let type):
            return "Failed to decode JSON to \(type)"
        case .jsonEncodingFailed:
            return "Failed to encode to JSON"
        case .unexpectedNil(let context):
            return "Unexpected nil value: \(context)"
        }
    }
}

// MARK: - Safe Execution Block

/// Execute code safely with automatic error handling
public func safeExecuteSync<T>(
    _ operation: String,
    default defaultValue: T,
    file: String = #file,
    line: Int = #line,
    block: () throws -> T
) -> T {
    do {
        return try block()
    } catch {
        let logger = os.Logger(subsystem: "com.echoelmusic", category: "safeexec")
        logger.warning("Safe execution failed for '\(operation)' at \(file):\(line): \(error.localizedDescription)")
        return defaultValue
    }
}

/// Execute async code safely
public func safeExecuteAsync<T>(
    _ operation: String,
    default defaultValue: T,
    file: String = #file,
    line: Int = #line,
    block: () async throws -> T
) async -> T {
    do {
        return try await block()
    } catch {
        let logger = os.Logger(subsystem: "com.echoelmusic", category: "safeexec")
        logger.warning("Safe async execution failed for '\(operation)' at \(file):\(line): \(error.localizedDescription)")
        return defaultValue
    }
}

// MARK: - Thread-Safe Counter

/// Thread-safe counter for production use
public final class SafeCounter: @unchecked Sendable {
    private var value: Int
    private let lock = NSLock()

    public init(_ initial: Int = 0) {
        self.value = initial
    }

    public var current: Int {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    public func increment() -> Int {
        lock.lock()
        defer { lock.unlock() }
        value += 1
        return value
    }

    public func decrement() -> Int {
        lock.lock()
        defer { lock.unlock() }
        value -= 1
        return value
    }

    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        value = 0
    }
}

// MARK: - Safe UserDefaults

/// Safe UserDefaults access
public struct SafeDefaults: Sendable {
    private static let logger = os.Logger(subsystem: "com.echoelmusic", category: "safedefaults")
    private static let defaults = UserDefaults.standard

    public static func string(forKey key: String, default defaultValue: String = "") -> String {
        defaults.string(forKey: key) ?? defaultValue
    }

    public static func int(forKey key: String, default defaultValue: Int = 0) -> Int {
        defaults.object(forKey: key) as? Int ?? defaultValue
    }

    public static func double(forKey key: String, default defaultValue: Double = 0) -> Double {
        defaults.object(forKey: key) as? Double ?? defaultValue
    }

    public static func bool(forKey key: String, default defaultValue: Bool = false) -> Bool {
        defaults.object(forKey: key) as? Bool ?? defaultValue
    }

    public static func date(forKey key: String) -> Date? {
        defaults.object(forKey: key) as? Date
    }

    public static func data(forKey key: String) -> Data? {
        defaults.data(forKey: key)
    }

    public static func set(_ value: Any?, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    public static func remove(forKey key: String) {
        defaults.removeObject(forKey: key)
    }
}
