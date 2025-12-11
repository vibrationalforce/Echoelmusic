// EchoelErrors.swift
// Echoelmusic - Structured Error Types
// Wise Mode Implementation

import Foundation
import AVFoundation

// MARK: - Audio Engine Errors

/// Errors related to audio engine operations
public enum AudioEngineError: LocalizedError, Equatable {
    case deviceNotAvailable(reason: String)
    case bufferAllocationFailed(size: Int)
    case formatMismatch(expected: String, got: String)
    case nodeConnectionFailed(from: String, to: String)
    case engineStartFailed(underlying: String)
    case sessionConfigurationFailed(category: String)
    case inputNotAvailable
    case outputNotAvailable
    case processingFailed(operation: String)
    case resourceExhausted(resource: String)

    public var errorDescription: String? {
        switch self {
        case .deviceNotAvailable(let reason):
            return "Audio device unavailable: \(reason)"
        case .bufferAllocationFailed(let size):
            return "Failed to allocate \(size) byte audio buffer"
        case .formatMismatch(let expected, let got):
            return "Audio format mismatch: expected \(expected), got \(got)"
        case .nodeConnectionFailed(let from, let to):
            return "Failed to connect '\(from)' to '\(to)'"
        case .engineStartFailed(let underlying):
            return "Audio engine failed to start: \(underlying)"
        case .sessionConfigurationFailed(let category):
            return "Failed to configure audio session for \(category)"
        case .inputNotAvailable:
            return "Audio input device not available"
        case .outputNotAvailable:
            return "Audio output device not available"
        case .processingFailed(let operation):
            return "Audio processing failed during \(operation)"
        case .resourceExhausted(let resource):
            return "Audio resource exhausted: \(resource)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .deviceNotAvailable:
            return "Check audio device connections and system permissions"
        case .bufferAllocationFailed:
            return "Try reducing buffer size or freeing system memory"
        case .formatMismatch:
            return "Ensure audio components use matching sample rates and channel counts"
        case .nodeConnectionFailed:
            return "Verify node compatibility and connection order"
        case .engineStartFailed:
            return "Restart the application and check audio permissions"
        case .sessionConfigurationFailed:
            return "Close other audio applications and retry"
        case .inputNotAvailable:
            return "Grant microphone permission in Settings"
        case .outputNotAvailable:
            return "Check speaker/headphone connections"
        case .processingFailed:
            return "Reduce processing load or buffer size"
        case .resourceExhausted:
            return "Close unused audio tracks or effects"
        }
    }

    public static func == (lhs: AudioEngineError, rhs: AudioEngineError) -> Bool {
        lhs.errorDescription == rhs.errorDescription
    }
}

// MARK: - MIDI Errors

/// Errors related to MIDI operations
public enum MIDIError: LocalizedError {
    case deviceNotFound(name: String)
    case connectionFailed(device: String, reason: String)
    case invalidMessage(bytes: [UInt8])
    case portCreationFailed(type: String)
    case clientCreationFailed
    case permissionDenied
    case virtualSourceFailed(name: String)
    case umpParsingFailed(data: [UInt8])
    case mpeZoneConfigurationFailed(zone: Int)

    public var errorDescription: String? {
        switch self {
        case .deviceNotFound(let name):
            return "MIDI device '\(name)' not found"
        case .connectionFailed(let device, let reason):
            return "Failed to connect to '\(device)': \(reason)"
        case .invalidMessage(let bytes):
            return "Invalid MIDI message: \(bytes.map { String(format: "%02X", $0) }.joined(separator: " "))"
        case .portCreationFailed(let type):
            return "Failed to create MIDI \(type) port"
        case .clientCreationFailed:
            return "Failed to create MIDI client"
        case .permissionDenied:
            return "MIDI access denied by system"
        case .virtualSourceFailed(let name):
            return "Failed to create virtual MIDI source '\(name)'"
        case .umpParsingFailed:
            return "Failed to parse Universal MIDI Packet"
        case .mpeZoneConfigurationFailed(let zone):
            return "Failed to configure MPE zone \(zone)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .deviceNotFound:
            return "Ensure MIDI device is connected and powered on"
        case .connectionFailed:
            return "Reconnect the MIDI device and restart the app"
        case .invalidMessage:
            return "Check MIDI source for proper message formatting"
        case .portCreationFailed:
            return "Restart the app to reset MIDI subsystem"
        case .clientCreationFailed:
            return "Restart the device to reset CoreMIDI"
        case .permissionDenied:
            return "Enable Bluetooth in Settings for wireless MIDI"
        case .virtualSourceFailed:
            return "Another app may be using this virtual port"
        case .umpParsingFailed:
            return "Ensure device supports MIDI 2.0"
        case .mpeZoneConfigurationFailed:
            return "Reset MPE zone configuration"
        }
    }
}

// MARK: - Spatial Audio Errors

/// Errors related to spatial audio operations
public enum SpatialAudioError: LocalizedError {
    case headTrackingUnavailable
    case ambisoncEncodingFailed(order: Int)
    case listenerPositionInvalid
    case sourcePositionOutOfBounds(position: String)
    case renderingFailed(mode: String)
    case hrtfLoadFailed(profile: String)

    public var errorDescription: String? {
        switch self {
        case .headTrackingUnavailable:
            return "Head tracking hardware not available"
        case .ambisoncEncodingFailed(let order):
            return "Ambisonics encoding failed for order \(order)"
        case .listenerPositionInvalid:
            return "Invalid listener position"
        case .sourcePositionOutOfBounds(let position):
            return "Audio source position out of bounds: \(position)"
        case .renderingFailed(let mode):
            return "Spatial rendering failed in \(mode) mode"
        case .hrtfLoadFailed(let profile):
            return "Failed to load HRTF profile: \(profile)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .headTrackingUnavailable:
            return "Use AirPods Pro or compatible headphones for head tracking"
        case .ambisoncEncodingFailed:
            return "Try lower ambisonics order"
        case .listenerPositionInvalid:
            return "Reset listener position to default"
        case .sourcePositionOutOfBounds:
            return "Move audio source within valid range"
        case .renderingFailed:
            return "Switch to a simpler spatial mode"
        case .hrtfLoadFailed:
            return "Use default HRTF profile"
        }
    }
}

// MARK: - Biofeedback Errors

/// Errors related to biofeedback and HealthKit operations
public enum BiofeedbackError: LocalizedError {
    case healthKitUnavailable
    case authorizationDenied(dataType: String)
    case sensorNotAvailable(sensor: String)
    case dataReadFailed(type: String)
    case coherenceCalculationFailed
    case hrvDataInsufficient(samples: Int, required: Int)
    case bluetoothUnavailable

    public var errorDescription: String? {
        switch self {
        case .healthKitUnavailable:
            return "HealthKit is not available on this device"
        case .authorizationDenied(let dataType):
            return "Access denied for \(dataType) data"
        case .sensorNotAvailable(let sensor):
            return "\(sensor) sensor not available"
        case .dataReadFailed(let type):
            return "Failed to read \(type) data"
        case .coherenceCalculationFailed:
            return "Failed to calculate coherence score"
        case .hrvDataInsufficient(let samples, let required):
            return "Insufficient HRV data: \(samples)/\(required) samples"
        case .bluetoothUnavailable:
            return "Bluetooth is not available for heart rate monitor"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .healthKitUnavailable:
            return "HealthKit requires iOS device with Health app"
        case .authorizationDenied:
            return "Enable access in Settings > Health > Data Access"
        case .sensorNotAvailable:
            return "Connect a compatible sensor device"
        case .dataReadFailed:
            return "Ensure device has recent health data"
        case .coherenceCalculationFailed:
            return "Wait for more heart rate samples"
        case .hrvDataInsufficient:
            return "Continue wearing sensor to collect more data"
        case .bluetoothUnavailable:
            return "Enable Bluetooth in Settings"
        }
    }
}

// MARK: - Visual/LED Errors

/// Errors related to visualization and LED control
public enum VisualError: LocalizedError {
    case metalUnavailable
    case shaderCompilationFailed(shader: String, error: String)
    case textureCreationFailed(size: String)
    case renderPipelineFailed(name: String)
    case dmxConnectionFailed(host: String, port: Int)
    case ledStripNotResponding(address: Int)
    case push3NotConnected

    public var errorDescription: String? {
        switch self {
        case .metalUnavailable:
            return "Metal GPU framework not available"
        case .shaderCompilationFailed(let shader, let error):
            return "Shader '\(shader)' failed to compile: \(error)"
        case .textureCreationFailed(let size):
            return "Failed to create texture of size \(size)"
        case .renderPipelineFailed(let name):
            return "Render pipeline '\(name)' creation failed"
        case .dmxConnectionFailed(let host, let port):
            return "DMX connection failed to \(host):\(port)"
        case .ledStripNotResponding(let address):
            return "LED strip at address \(address) not responding"
        case .push3NotConnected:
            return "Ableton Push 3 not connected"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .metalUnavailable:
            return "Metal requires A7 chip or later"
        case .shaderCompilationFailed:
            return "Check shader source for syntax errors"
        case .textureCreationFailed:
            return "Reduce texture size or free GPU memory"
        case .renderPipelineFailed:
            return "Restart app to reset GPU state"
        case .dmxConnectionFailed:
            return "Check network connection and Art-Net device"
        case .ledStripNotResponding:
            return "Check LED strip wiring and power"
        case .push3NotConnected:
            return "Connect Push 3 via USB and ensure drivers are installed"
        }
    }
}

// MARK: - Recording Errors

/// Errors related to recording and session management
public enum RecordingError: LocalizedError {
    case sessionNotFound(id: String)
    case trackLimitReached(max: Int)
    case diskSpaceInsufficient(required: Int64, available: Int64)
    case encodingFailed(format: String)
    case exportFailed(destination: String, reason: String)
    case fileWriteFailed(path: String)
    case audioFileTooLarge(size: Int64, maxSize: Int64)
    case unsupportedFormat(format: String)

    public var errorDescription: String? {
        switch self {
        case .sessionNotFound(let id):
            return "Recording session '\(id)' not found"
        case .trackLimitReached(let max):
            return "Maximum track limit (\(max)) reached"
        case .diskSpaceInsufficient(let required, let available):
            let formatter = ByteCountFormatter()
            return "Insufficient disk space: need \(formatter.string(fromByteCount: required)), have \(formatter.string(fromByteCount: available))"
        case .encodingFailed(let format):
            return "Audio encoding failed for \(format) format"
        case .exportFailed(let destination, let reason):
            return "Export to '\(destination)' failed: \(reason)"
        case .fileWriteFailed(let path):
            return "Failed to write file to \(path)"
        case .audioFileTooLarge(let size, let maxSize):
            let formatter = ByteCountFormatter()
            return "Audio file too large: \(formatter.string(fromByteCount: size)) exceeds \(formatter.string(fromByteCount: maxSize))"
        case .unsupportedFormat(let format):
            return "Unsupported audio format: \(format)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .sessionNotFound:
            return "Create a new session or select existing one"
        case .trackLimitReached:
            return "Delete unused tracks to add new ones"
        case .diskSpaceInsufficient:
            return "Free up device storage"
        case .encodingFailed:
            return "Try a different export format"
        case .exportFailed:
            return "Check destination permissions and available space"
        case .fileWriteFailed:
            return "Ensure app has write permission"
        case .audioFileTooLarge:
            return "Split recording into smaller segments"
        case .unsupportedFormat:
            return "Convert to WAV, AIFF, or M4A format"
        }
    }
}

// MARK: - Network Errors

/// Errors related to network operations
public enum NetworkError: LocalizedError {
    case connectionFailed(host: String, reason: String)
    case timeout(operation: String, seconds: Int)
    case invalidResponse(expected: String)
    case sslCertificateInvalid
    case noInternetConnection
    case serverError(code: Int, message: String)
    case rateLimited(retryAfter: TimeInterval)

    public var errorDescription: String? {
        switch self {
        case .connectionFailed(let host, let reason):
            return "Connection to \(host) failed: \(reason)"
        case .timeout(let operation, let seconds):
            return "\(operation) timed out after \(seconds) seconds"
        case .invalidResponse(let expected):
            return "Invalid response: expected \(expected)"
        case .sslCertificateInvalid:
            return "SSL certificate validation failed"
        case .noInternetConnection:
            return "No internet connection available"
        case .serverError(let code, let message):
            return "Server error \(code): \(message)"
        case .rateLimited(let retryAfter):
            return "Rate limited, retry after \(Int(retryAfter)) seconds"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .connectionFailed:
            return "Check network settings and try again"
        case .timeout:
            return "Check your internet connection speed"
        case .invalidResponse:
            return "Server may be experiencing issues"
        case .sslCertificateInvalid:
            return "Ensure device date/time is correct"
        case .noInternetConnection:
            return "Connect to WiFi or enable cellular data"
        case .serverError:
            return "Try again later"
        case .rateLimited:
            return "Wait before making another request"
        }
    }
}

// MARK: - Generic App Errors

/// General application errors
public enum AppError: LocalizedError {
    case initializationFailed(component: String)
    case invalidState(expected: String, actual: String)
    case resourceNotFound(name: String, type: String)
    case permissionRequired(permission: String)
    case featureNotAvailable(feature: String, reason: String)
    case configurationError(setting: String)
    case internalError(description: String)

    public var errorDescription: String? {
        switch self {
        case .initializationFailed(let component):
            return "Failed to initialize \(component)"
        case .invalidState(let expected, let actual):
            return "Invalid state: expected \(expected), was \(actual)"
        case .resourceNotFound(let name, let type):
            return "\(type) '\(name)' not found"
        case .permissionRequired(let permission):
            return "\(permission) permission required"
        case .featureNotAvailable(let feature, let reason):
            return "\(feature) not available: \(reason)"
        case .configurationError(let setting):
            return "Configuration error for \(setting)"
        case .internalError(let description):
            return "Internal error: \(description)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .initializationFailed:
            return "Restart the application"
        case .invalidState:
            return "Reset the affected component"
        case .resourceNotFound:
            return "Reinstall the application"
        case .permissionRequired:
            return "Grant permission in Settings"
        case .featureNotAvailable:
            return "Check device compatibility"
        case .configurationError:
            return "Reset settings to defaults"
        case .internalError:
            return "Contact support if this persists"
        }
    }
}

// MARK: - Error Result Builder

/// Utility for handling multiple errors
public struct ErrorCollection: LocalizedError {
    public let errors: [Error]

    public init(_ errors: [Error]) {
        self.errors = errors
    }

    public var errorDescription: String? {
        errors.map { $0.localizedDescription }.joined(separator: "; ")
    }

    public var isEmpty: Bool { errors.isEmpty }
    public var count: Int { errors.count }
}
