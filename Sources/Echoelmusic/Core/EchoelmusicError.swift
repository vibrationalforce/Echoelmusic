import Foundation
import os.log

// MARK: - Unified Error System

/// Zentrales Error-Handling-System für Echoelmusic
/// Ersetzt alle inkonsistenten NSError und verstreuten Error-Typen
/// WISE MODE: Unified Error Architecture

private let errorLogger = Logger(subsystem: "com.echoelmusic", category: "Error")

// MARK: - Base Error Protocol

/// Protocol für alle Echoelmusic-Fehler
public protocol EchoelmusicErrorProtocol: LocalizedError, CustomStringConvertible {
    var errorCode: Int { get }
    var category: EchoelmusicErrorCategory { get }
    var severity: EchoelmusicErrorSeverity { get }
    var recoveryOptions: [RecoveryOption] { get }
}

// MARK: - Error Categories

/// Kategorien für Fehler-Klassifizierung
public enum EchoelmusicErrorCategory: String, CaseIterable {
    case audio = "Audio"
    case midi = "MIDI"
    case healthKit = "HealthKit"
    case recording = "Recording"
    case export = "Export"
    case network = "Network"
    case file = "File"
    case permission = "Permission"
    case hardware = "Hardware"
    case ai = "AI"
    case visual = "Visual"
    case spatial = "Spatial"
    case privacy = "Privacy"
    case general = "General"
}

// MARK: - Error Severity

/// Schweregrad des Fehlers
public enum EchoelmusicErrorSeverity: Int, CaseIterable {
    case info = 0      // Informativ, kein Handlungsbedarf
    case warning = 1   // Warnung, kann fortgesetzt werden
    case error = 2     // Fehler, Aktion fehlgeschlagen
    case critical = 3  // Kritisch, App-Stabilität betroffen
    case fatal = 4     // Fatal, App muss beendet werden

    var icon: String {
        switch self {
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🔴"
        case .fatal: return "💀"
        }
    }
}

// MARK: - Recovery Options

/// Optionen zur Fehlerbehebung
public struct RecoveryOption: Identifiable {
    public let id = UUID()
    public let title: String
    public let description: String
    public let action: () async throws -> Void

    public init(title: String, description: String, action: @escaping () async throws -> Void) {
        self.title = title
        self.description = description
        self.action = action
    }
}

// MARK: - Main Error Enum

/// Hauptfehler-Enum mit allen Fehlerkategorien
public enum EchoelmusicError: EchoelmusicErrorProtocol {

    // MARK: - Audio Errors (100-199)
    case audioEngineNotInitialized
    case audioSessionConfigurationFailed(underlying: Error?)
    case audioBufferAllocationFailed(size: Int)
    case audioBufferEmpty
    case audioFormatMismatch(expected: String, actual: String)
    case audioDeviceNotAvailable(deviceName: String)
    case audioProcessingFailed(reason: String)
    case sampleRateNotSupported(rate: Double)

    // MARK: - MIDI Errors (200-299)
    case midiClientCreationFailed(status: Int32)
    case midiPortCreationFailed(status: Int32)
    case midiDeviceNotFound(name: String)
    case midiConnectionFailed(reason: String)
    case mpeConfigurationFailed(reason: String)
    case midi2NotSupported

    // MARK: - HealthKit Errors (300-399)
    case healthKitNotAvailable
    case healthKitAuthorizationDenied
    case healthKitDataNotAvailable(type: String)
    case healthKitQueryFailed(underlying: Error?)
    case biometricSensorUnavailable(sensor: String)

    // MARK: - Recording Errors (400-499)
    case noActiveSession
    case alreadyRecording
    case recordingFailed(reason: String)
    case trackNotFound(id: UUID)
    case sessionSaveFailed(underlying: Error?)
    case sessionLoadFailed(underlying: Error?)

    // MARK: - Export Errors (500-599)
    case exportFormatNotSupported(format: String)
    case exportFailed(reason: String)
    case exportCancelled
    case insufficientDiskSpace(required: Int64, available: Int64)

    // MARK: - File Errors (600-699)
    case fileNotFound(path: String)
    case fileReadFailed(path: String, underlying: Error?)
    case fileWriteFailed(path: String, underlying: Error?)
    case directoryCreationFailed(path: String)
    case fileTooLarge(size: Int64, maxSize: Int64)
    case invalidFileFormat(expected: String, actual: String)

    // MARK: - Permission Errors (700-799)
    case microphonePermissionDenied
    case cameraPermissionDenied
    case motionPermissionDenied
    case networkPermissionDenied
    case photoLibraryPermissionDenied

    // MARK: - Hardware Errors (800-899)
    case metalNotSupported
    case metalDeviceCreationFailed
    case gpuFamilyNotSupported(required: String)
    case insufficientMemory(required: Int64)
    case thermalThrottling
    case batteryTooLow(level: Float)

    // MARK: - AI/ML Errors (900-999)
    case modelLoadFailed(modelName: String)
    case inferencesFailed(reason: String)
    case stemSeparationFailed(reason: String)
    case compositionGenerationFailed(reason: String)

    // MARK: - Visual Errors (1000-1099)
    case shaderCompilationFailed(shaderName: String)
    case renderPipelineCreationFailed
    case textureCreationFailed(size: String)
    case visualizationFailed(reason: String)

    // MARK: - Spatial Audio Errors (1100-1199)
    case spatialAudioNotSupported
    case headTrackingNotAvailable
    case hrtfNotAvailable
    case ambisonicsNotSupported

    // MARK: - Network/Streaming Errors (1200-1299)
    case networkConnectionFailed(reason: String)
    case streamingFailed(reason: String)
    case oscConnectionFailed(host: String, port: Int)
    case artNetConnectionFailed(address: String)

    // MARK: - General Errors (1300+)
    case invalidConfiguration(reason: String)
    case operationCancelled
    case timeout(operation: String, seconds: TimeInterval)
    case unknown(underlying: Error?)

    // MARK: - EchoelmusicErrorProtocol Conformance

    public var errorCode: Int {
        switch self {
        // Audio Errors (100-199)
        case .audioEngineNotInitialized: return 100
        case .audioSessionConfigurationFailed: return 101
        case .audioBufferAllocationFailed: return 102
        case .audioBufferEmpty: return 103
        case .audioFormatMismatch: return 104
        case .audioDeviceNotAvailable: return 105
        case .audioProcessingFailed: return 106
        case .sampleRateNotSupported: return 107

        // MIDI Errors (200-299)
        case .midiClientCreationFailed: return 200
        case .midiPortCreationFailed: return 201
        case .midiDeviceNotFound: return 202
        case .midiConnectionFailed: return 203
        case .mpeConfigurationFailed: return 204
        case .midi2NotSupported: return 205

        // HealthKit Errors (300-399)
        case .healthKitNotAvailable: return 300
        case .healthKitAuthorizationDenied: return 301
        case .healthKitDataNotAvailable: return 302
        case .healthKitQueryFailed: return 303
        case .biometricSensorUnavailable: return 304

        // Recording Errors (400-499)
        case .noActiveSession: return 400
        case .alreadyRecording: return 401
        case .recordingFailed: return 402
        case .trackNotFound: return 403
        case .sessionSaveFailed: return 404
        case .sessionLoadFailed: return 405

        // Export Errors (500-599)
        case .exportFormatNotSupported: return 500
        case .exportFailed: return 501
        case .exportCancelled: return 502
        case .insufficientDiskSpace: return 503

        // File Errors (600-699)
        case .fileNotFound: return 600
        case .fileReadFailed: return 601
        case .fileWriteFailed: return 602
        case .directoryCreationFailed: return 603
        case .fileTooLarge: return 604
        case .invalidFileFormat: return 605

        // Permission Errors (700-799)
        case .microphonePermissionDenied: return 700
        case .cameraPermissionDenied: return 701
        case .motionPermissionDenied: return 702
        case .networkPermissionDenied: return 703
        case .photoLibraryPermissionDenied: return 704

        // Hardware Errors (800-899)
        case .metalNotSupported: return 800
        case .metalDeviceCreationFailed: return 801
        case .gpuFamilyNotSupported: return 802
        case .insufficientMemory: return 803
        case .thermalThrottling: return 804
        case .batteryTooLow: return 805

        // AI/ML Errors (900-999)
        case .modelLoadFailed: return 900
        case .inferencesFailed: return 901
        case .stemSeparationFailed: return 902
        case .compositionGenerationFailed: return 903

        // Visual Errors (1000-1099)
        case .shaderCompilationFailed: return 1000
        case .renderPipelineCreationFailed: return 1001
        case .textureCreationFailed: return 1002
        case .visualizationFailed: return 1003

        // Spatial Audio Errors (1100-1199)
        case .spatialAudioNotSupported: return 1100
        case .headTrackingNotAvailable: return 1101
        case .hrtfNotAvailable: return 1102
        case .ambisonicsNotSupported: return 1103

        // Network Errors (1200-1299)
        case .networkConnectionFailed: return 1200
        case .streamingFailed: return 1201
        case .oscConnectionFailed: return 1202
        case .artNetConnectionFailed: return 1203

        // General Errors (1300+)
        case .invalidConfiguration: return 1300
        case .operationCancelled: return 1301
        case .timeout: return 1302
        case .unknown: return 1399
        }
    }

    public var category: EchoelmusicErrorCategory {
        switch self {
        case .audioEngineNotInitialized, .audioSessionConfigurationFailed,
             .audioBufferAllocationFailed, .audioBufferEmpty, .audioFormatMismatch,
             .audioDeviceNotAvailable, .audioProcessingFailed,
             .sampleRateNotSupported:
            return .audio

        case .midiClientCreationFailed, .midiPortCreationFailed,
             .midiDeviceNotFound, .midiConnectionFailed,
             .mpeConfigurationFailed, .midi2NotSupported:
            return .midi

        case .healthKitNotAvailable, .healthKitAuthorizationDenied,
             .healthKitDataNotAvailable, .healthKitQueryFailed,
             .biometricSensorUnavailable:
            return .healthKit

        case .noActiveSession, .alreadyRecording, .recordingFailed,
             .trackNotFound, .sessionSaveFailed, .sessionLoadFailed:
            return .recording

        case .exportFormatNotSupported, .exportFailed, .exportCancelled,
             .insufficientDiskSpace:
            return .export

        case .fileNotFound, .fileReadFailed, .fileWriteFailed,
             .directoryCreationFailed, .fileTooLarge, .invalidFileFormat:
            return .file

        case .microphonePermissionDenied, .cameraPermissionDenied,
             .motionPermissionDenied, .networkPermissionDenied,
             .photoLibraryPermissionDenied:
            return .permission

        case .metalNotSupported, .metalDeviceCreationFailed,
             .gpuFamilyNotSupported, .insufficientMemory,
             .thermalThrottling, .batteryTooLow:
            return .hardware

        case .modelLoadFailed, .inferencesFailed, .stemSeparationFailed,
             .compositionGenerationFailed:
            return .ai

        case .shaderCompilationFailed, .renderPipelineCreationFailed,
             .textureCreationFailed, .visualizationFailed:
            return .visual

        case .spatialAudioNotSupported, .headTrackingNotAvailable,
             .hrtfNotAvailable, .ambisonicsNotSupported:
            return .spatial

        case .networkConnectionFailed, .streamingFailed, .oscConnectionFailed,
             .artNetConnectionFailed:
            return .network

        case .invalidConfiguration, .operationCancelled, .timeout, .unknown:
            return .general
        }
    }

    public var severity: EchoelmusicErrorSeverity {
        switch self {
        // Critical - App stability affected
        case .audioEngineNotInitialized, .metalNotSupported,
             .metalDeviceCreationFailed, .insufficientMemory:
            return .critical

        // Error - Action failed
        case .audioSessionConfigurationFailed, .audioBufferAllocationFailed,
             .audioBufferEmpty, .midiClientCreationFailed, .midiPortCreationFailed,
             .healthKitAuthorizationDenied, .recordingFailed,
             .exportFailed, .fileWriteFailed, .modelLoadFailed:
            return .error

        // Warning - Can continue
        case .audioDeviceNotAvailable, .midiDeviceNotFound,
             .healthKitDataNotAvailable, .headTrackingNotAvailable,
             .thermalThrottling, .batteryTooLow, .timeout:
            return .warning

        // Info - No action needed
        case .operationCancelled, .exportCancelled:
            return .info

        // Default to error
        default:
            return .error
        }
    }

    public var recoveryOptions: [RecoveryOption] {
        switch self {
        case .microphonePermissionDenied, .cameraPermissionDenied:
            return [
                RecoveryOption(
                    title: "Einstellungen öffnen",
                    description: "Berechtigung in den Systemeinstellungen aktivieren"
                ) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        await UIApplication.shared.open(url)
                    }
                }
            ]

        case .healthKitAuthorizationDenied:
            return [
                RecoveryOption(
                    title: "Health-App öffnen",
                    description: "Berechtigung in der Health-App aktivieren"
                ) {
                    // Open Health app
                }
            ]

        case .insufficientDiskSpace(let required, _):
            return [
                RecoveryOption(
                    title: "Speicher freigeben",
                    description: "Mindestens \(ByteCountFormatter.string(fromByteCount: required, countStyle: .file)) freigeben"
                ) {
                    // Guide user to free space
                }
            ]

        default:
            return []
        }
    }

    // MARK: - LocalizedError

    public var errorDescription: String? {
        switch self {
        // Audio
        case .audioEngineNotInitialized:
            return "Audio-Engine nicht initialisiert"
        case .audioSessionConfigurationFailed(let underlying):
            return "Audio-Session-Konfiguration fehlgeschlagen: \(underlying?.localizedDescription ?? "Unbekannt")"
        case .audioBufferAllocationFailed(let size):
            return "Audio-Buffer-Allokation fehlgeschlagen (\(size) Bytes)"
        case .audioBufferEmpty:
            return "Audio-Buffer ist leer"
        case .audioFormatMismatch(let expected, let actual):
            return "Audio-Format-Mismatch: Erwartet \(expected), erhalten \(actual)"
        case .audioDeviceNotAvailable(let deviceName):
            return "Audio-Gerät nicht verfügbar: \(deviceName)"
        case .audioProcessingFailed(let reason):
            return "Audio-Verarbeitung fehlgeschlagen: \(reason)"
        case .sampleRateNotSupported(let rate):
            return "Sample-Rate nicht unterstützt: \(Int(rate)) Hz"

        // MIDI
        case .midiClientCreationFailed(let status):
            return "MIDI-Client-Erstellung fehlgeschlagen (Status: \(status))"
        case .midiPortCreationFailed(let status):
            return "MIDI-Port-Erstellung fehlgeschlagen (Status: \(status))"
        case .midiDeviceNotFound(let name):
            return "MIDI-Gerät nicht gefunden: \(name)"
        case .midiConnectionFailed(let reason):
            return "MIDI-Verbindung fehlgeschlagen: \(reason)"
        case .mpeConfigurationFailed(let reason):
            return "MPE-Konfiguration fehlgeschlagen: \(reason)"
        case .midi2NotSupported:
            return "MIDI 2.0 wird auf diesem Gerät nicht unterstützt"

        // HealthKit
        case .healthKitNotAvailable:
            return "HealthKit ist auf diesem Gerät nicht verfügbar"
        case .healthKitAuthorizationDenied:
            return "HealthKit-Zugriff verweigert"
        case .healthKitDataNotAvailable(let type):
            return "HealthKit-Daten nicht verfügbar: \(type)"
        case .healthKitQueryFailed(let underlying):
            return "HealthKit-Abfrage fehlgeschlagen: \(underlying?.localizedDescription ?? "Unbekannt")"
        case .biometricSensorUnavailable(let sensor):
            return "Biometrischer Sensor nicht verfügbar: \(sensor)"

        // Recording
        case .noActiveSession:
            return "Keine aktive Session"
        case .alreadyRecording:
            return "Aufnahme läuft bereits"
        case .recordingFailed(let reason):
            return "Aufnahme fehlgeschlagen: \(reason)"
        case .trackNotFound(let id):
            return "Track nicht gefunden: \(id.uuidString.prefix(8))"
        case .sessionSaveFailed(let underlying):
            return "Session-Speicherung fehlgeschlagen: \(underlying?.localizedDescription ?? "Unbekannt")"
        case .sessionLoadFailed(let underlying):
            return "Session-Laden fehlgeschlagen: \(underlying?.localizedDescription ?? "Unbekannt")"

        // Export
        case .exportFormatNotSupported(let format):
            return "Export-Format nicht unterstützt: \(format)"
        case .exportFailed(let reason):
            return "Export fehlgeschlagen: \(reason)"
        case .exportCancelled:
            return "Export abgebrochen"
        case .insufficientDiskSpace(let required, let available):
            let requiredStr = ByteCountFormatter.string(fromByteCount: required, countStyle: .file)
            let availableStr = ByteCountFormatter.string(fromByteCount: available, countStyle: .file)
            return "Nicht genügend Speicherplatz: Benötigt \(requiredStr), verfügbar \(availableStr)"

        // File
        case .fileNotFound(let path):
            return "Datei nicht gefunden: \(path)"
        case .fileReadFailed(let path, _):
            return "Datei-Lesefehler: \(path)"
        case .fileWriteFailed(let path, _):
            return "Datei-Schreibfehler: \(path)"
        case .directoryCreationFailed(let path):
            return "Verzeichnis-Erstellung fehlgeschlagen: \(path)"
        case .fileTooLarge(let size, let maxSize):
            let sizeStr = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            let maxStr = ByteCountFormatter.string(fromByteCount: maxSize, countStyle: .file)
            return "Datei zu groß: \(sizeStr) (Max: \(maxStr))"
        case .invalidFileFormat(let expected, let actual):
            return "Ungültiges Dateiformat: Erwartet \(expected), erhalten \(actual)"

        // Permissions
        case .microphonePermissionDenied:
            return "Mikrofon-Berechtigung verweigert"
        case .cameraPermissionDenied:
            return "Kamera-Berechtigung verweigert"
        case .motionPermissionDenied:
            return "Bewegungssensor-Berechtigung verweigert"
        case .networkPermissionDenied:
            return "Netzwerk-Berechtigung verweigert"
        case .photoLibraryPermissionDenied:
            return "Fotomediathek-Berechtigung verweigert"

        // Hardware
        case .metalNotSupported:
            return "Metal wird auf diesem Gerät nicht unterstützt"
        case .metalDeviceCreationFailed:
            return "Metal-Gerät konnte nicht erstellt werden"
        case .gpuFamilyNotSupported(let required):
            return "GPU-Familie nicht unterstützt: \(required) erforderlich"
        case .insufficientMemory(let required):
            let requiredStr = ByteCountFormatter.string(fromByteCount: required, countStyle: .memory)
            return "Nicht genügend Arbeitsspeicher: \(requiredStr) erforderlich"
        case .thermalThrottling:
            return "Thermisches Throttling aktiv - Leistung reduziert"
        case .batteryTooLow(let level):
            return "Akku zu niedrig: \(Int(level * 100))%"

        // AI/ML
        case .modelLoadFailed(let modelName):
            return "ML-Modell konnte nicht geladen werden: \(modelName)"
        case .inferencesFailed(let reason):
            return "ML-Inferenz fehlgeschlagen: \(reason)"
        case .stemSeparationFailed(let reason):
            return "Stem-Separation fehlgeschlagen: \(reason)"
        case .compositionGenerationFailed(let reason):
            return "Kompositionsgenerierung fehlgeschlagen: \(reason)"

        // Visual
        case .shaderCompilationFailed(let shaderName):
            return "Shader-Kompilierung fehlgeschlagen: \(shaderName)"
        case .renderPipelineCreationFailed:
            return "Render-Pipeline konnte nicht erstellt werden"
        case .textureCreationFailed(let size):
            return "Textur-Erstellung fehlgeschlagen: \(size)"
        case .visualizationFailed(let reason):
            return "Visualisierung fehlgeschlagen: \(reason)"

        // Spatial
        case .spatialAudioNotSupported:
            return "Spatial Audio wird nicht unterstützt"
        case .headTrackingNotAvailable:
            return "Head Tracking nicht verfügbar"
        case .hrtfNotAvailable:
            return "HRTF nicht verfügbar"
        case .ambisonicsNotSupported:
            return "Ambisonics wird nicht unterstützt"

        // Network
        case .networkConnectionFailed(let reason):
            return "Netzwerkverbindung fehlgeschlagen: \(reason)"
        case .streamingFailed(let reason):
            return "Streaming fehlgeschlagen: \(reason)"
        case .oscConnectionFailed(let host, let port):
            return "OSC-Verbindung fehlgeschlagen: \(host):\(port)"
        case .artNetConnectionFailed(let address):
            return "Art-Net-Verbindung fehlgeschlagen: \(address)"

        // General
        case .invalidConfiguration(let reason):
            return "Ungültige Konfiguration: \(reason)"
        case .operationCancelled:
            return "Operation abgebrochen"
        case .timeout(let operation, let seconds):
            return "Timeout bei \(operation) nach \(Int(seconds))s"
        case .unknown(let underlying):
            return "Unbekannter Fehler: \(underlying?.localizedDescription ?? "Keine Details")"
        }
    }

    public var failureReason: String? {
        return errorDescription
    }

    public var recoverySuggestion: String? {
        if !recoveryOptions.isEmpty {
            return recoveryOptions.first?.description
        }
        return nil
    }

    // MARK: - CustomStringConvertible

    public var description: String {
        return "[\(category.rawValue)] (\(errorCode)) \(errorDescription ?? "Unbekannter Fehler")"
    }
}

// MARK: - Error Logging Extension

extension EchoelmusicError {
    /// Loggt den Fehler mit dem passenden Log-Level
    public func log(file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let context = "\(fileName):\(line) \(function)"

        switch severity {
        case .info:
            errorLogger.info("\(self.severity.icon) \(self.description, privacy: .public) [\(context, privacy: .public)]")
        case .warning:
            errorLogger.warning("\(self.severity.icon) \(self.description, privacy: .public) [\(context, privacy: .public)]")
        case .error:
            errorLogger.error("\(self.severity.icon) \(self.description, privacy: .public) [\(context, privacy: .public)]")
        case .critical, .fatal:
            errorLogger.critical("\(self.severity.icon) \(self.description, privacy: .public) [\(context, privacy: .public)]")
        }
    }
}

// MARK: - Result Extension

extension Result where Failure == EchoelmusicError {
    /// Loggt Fehler automatisch bei Failure
    @discardableResult
    public func logOnFailure(file: String = #file, function: String = #function, line: Int = #line) -> Self {
        if case .failure(let error) = self {
            error.log(file: file, function: function, line: line)
        }
        return self
    }
}

// MARK: - Error Wrapper for NSError Migration

extension EchoelmusicError {
    /// Konvertiert NSError zu EchoelmusicError
    public static func from(_ nsError: NSError) -> EchoelmusicError {
        switch nsError.domain {
        case "com.echoelmusic.healthkit":
            switch nsError.code {
            case 1: return .healthKitNotAvailable
            case 2: return .healthKitAuthorizationDenied
            default: return .unknown(underlying: nsError)
            }
        case "com.echoelmusic.midi":
            return .midiConnectionFailed(reason: nsError.localizedDescription)
        case "com.echoelmusic.audio":
            return .audioProcessingFailed(reason: nsError.localizedDescription)
        default:
            return .unknown(underlying: nsError)
        }
    }
}
