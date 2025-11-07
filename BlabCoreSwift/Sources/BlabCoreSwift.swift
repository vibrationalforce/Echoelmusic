import Foundation

/// Swift wrapper for BLAB Rust Core
///
/// Usage:
/// ```swift
/// let engine = BlabAudioEngine()
/// try engine.start()
/// engine.updateBio(params: BioParameters(...))
/// ```

/// Bio-reactive parameters
public struct BioParameters {
    public var hrvCoherence: Float
    public var heartRate: Float
    public var breathingRate: Float
    public var audioLevel: Float
    public var voicePitch: Float

    public init(
        hrvCoherence: Float = 0.5,
        heartRate: Float = 70.0,
        breathingRate: Float = 12.0,
        audioLevel: Float = 0.5,
        voicePitch: Float = 0.0
    ) {
        self.hrvCoherence = hrvCoherence
        self.heartRate = heartRate
        self.breathingRate = breathingRate
        self.audioLevel = audioLevel
        self.voicePitch = voicePitch
    }
}

/// Swift wrapper for Rust AudioEngine
public class BlabAudioEngine {
    private var handle: OpaquePointer?

    public init() throws {
        handle = blab_audio_engine_new()
        guard handle != nil else {
            throw BlabError.initializationFailed
        }
    }

    deinit {
        if let handle = handle {
            blab_audio_engine_free(handle)
        }
    }

    /// Start audio processing
    public func start() throws {
        guard let handle = handle else {
            throw BlabError.invalidState
        }

        let success = blab_audio_engine_start(handle)
        guard success else {
            throw BlabError.startFailed
        }
    }

    /// Stop audio processing
    public func stop() {
        guard let handle = handle else { return }
        blab_audio_engine_stop(handle)
    }

    /// Update bio-reactive parameters
    public func updateBio(params: BioParameters) {
        guard let handle = handle else { return }

        var cParams = BlabBioParameters(
            hrv_coherence: params.hrvCoherence,
            heart_rate: params.heartRate,
            breathing_rate: params.breathingRate,
            audio_level: params.audioLevel,
            voice_pitch: params.voicePitch
        )

        blab_audio_engine_update_bio(handle, cParams)
    }

    /// Get audio latency in milliseconds
    public var latencyMs: Float {
        guard let handle = handle else { return 0.0 }
        return blab_audio_engine_get_latency_ms(handle)
    }

    /// Get BLAB core version
    public static var version: String {
        guard let cString = blab_version() else {
            return "Unknown"
        }
        return String(cString: cString)
    }
}

/// BLAB errors
public enum BlabError: Error {
    case initializationFailed
    case invalidState
    case startFailed
}

// MARK: - C FFI Declarations

@_silgen_name("blab_audio_engine_new")
func blab_audio_engine_new() -> OpaquePointer?

@_silgen_name("blab_audio_engine_free")
func blab_audio_engine_free(_ engine: OpaquePointer)

@_silgen_name("blab_audio_engine_start")
func blab_audio_engine_start(_ engine: OpaquePointer) -> Bool

@_silgen_name("blab_audio_engine_stop")
func blab_audio_engine_stop(_ engine: OpaquePointer)

@_silgen_name("blab_audio_engine_update_bio")
func blab_audio_engine_update_bio(_ engine: OpaquePointer, _ params: BlabBioParameters)

@_silgen_name("blab_audio_engine_get_latency_ms")
func blab_audio_engine_get_latency_ms(_ engine: OpaquePointer) -> Float

@_silgen_name("blab_version")
func blab_version() -> UnsafePointer<CChar>?

// C struct (must match Rust FFI)
struct BlabBioParameters {
    var hrv_coherence: Float
    var heart_rate: Float
    var breathing_rate: Float
    var audio_level: Float
    var voice_pitch: Float
}
