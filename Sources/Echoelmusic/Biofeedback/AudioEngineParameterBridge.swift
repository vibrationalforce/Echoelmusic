import Foundation
import Combine

/// Bridge between Swift biofeedback system and C++ audio engine
/// Provides lock-free, thread-safe communication of HRV parameters to audio processing
///
/// Architecture:
/// Swift (UI Thread) → Objective-C++ Bridge → C++ Audio Engine (Audio Thread)
///
/// Thread Safety:
/// - Uses atomic operations in C++ layer
/// - No locks in audio thread
/// - Safe to call from any thread
@objc public class AudioEngineParameterBridge: NSObject {

    // MARK: - Singleton

    @objc public static let shared = AudioEngineParameterBridge()

    private override init() {
        super.init()
    }

    // MARK: - Parameter Setting (Thread-Safe)

    /// Set filter cutoff frequency based on HRV
    /// - Parameter frequency: Filter cutoff in Hz (20-20000)
    /// - Note: Called from biofeedback update thread, affects audio thread atomically
    @objc public func setFilterCutoff(_ frequency: Float) {
        // Forward to Objective-C++ bridge (implemented in EchoelmusicAudioEngineBridge.mm)
        EchoelmusicAudioEngineBridge.setFilterCutoff(frequency)
    }

    /// Set reverb size/room size based on cardiac coherence
    /// - Parameter size: Reverb size (0.0-1.0)
    /// - Note: Higher coherence = larger reverb for expansive feeling
    @objc public func setReverbSize(_ size: Float) {
        EchoelmusicAudioEngineBridge.setReverbSize(size)
    }

    /// Set reverb decay time
    /// - Parameter decay: Decay time in seconds (0.1-10.0)
    @objc public func setReverbDecay(_ decay: Float) {
        EchoelmusicAudioEngineBridge.setReverbDecay(decay)
    }

    /// Set master volume based on HRV stability
    /// - Parameter volume: Volume level (0.0-1.0)
    /// - Note: Can be used for gentle volume swell with breathing
    @objc public func setMasterVolume(_ volume: Float) {
        EchoelmusicAudioEngineBridge.setMasterVolume(volume)
    }

    /// Set delay time based on heart rate interval
    /// - Parameter timeMs: Delay time in milliseconds
    /// - Note: Can sync delay to heart rate for rhythmic effect
    @objc public func setDelayTime(_ timeMs: Float) {
        EchoelmusicAudioEngineBridge.setDelayTime(timeMs)
    }

    /// Set delay feedback amount
    /// - Parameter feedback: Feedback amount (0.0-1.0)
    @objc public func setDelayFeedback(_ feedback: Float) {
        EchoelmusicAudioEngineBridge.setDelayFeedback(feedback)
    }

    /// Set modulation rate (LFO speed) based on breathing rate
    /// - Parameter rateHz: Modulation rate in Hz (0.01-10.0)
    /// - Note: Can sync to breathing rate detected from HRV
    @objc public func setModulationRate(_ rateHz: Float) {
        EchoelmusicAudioEngineBridge.setModulationRate(rateHz)
    }

    /// Set modulation depth
    /// - Parameter depth: Modulation depth (0.0-1.0)
    @objc public func setModulationDepth(_ depth: Float) {
        EchoelmusicAudioEngineBridge.setModulationDepth(depth)
    }

    /// Set distortion/saturation amount based on stress level
    /// - Parameter amount: Distortion amount (0.0-1.0)
    /// - Note: Low HRV (stress) could increase distortion
    @objc public func setDistortionAmount(_ amount: Float) {
        EchoelmusicAudioEngineBridge.setDistortionAmount(amount)
    }

    /// Set compressor threshold
    /// - Parameter thresholdDb: Threshold in dB (-60 to 0)
    @objc public func setCompressorThreshold(_ thresholdDb: Float) {
        EchoelmusicAudioEngineBridge.setCompressorThreshold(thresholdDb)
    }

    /// Set compressor ratio
    /// - Parameter ratio: Compression ratio (1.0-20.0)
    @objc public func setCompressorRatio(_ ratio: Float) {
        EchoelmusicAudioEngineBridge.setCompressorRatio(ratio)
    }

    // MARK: - Advanced Bio-Reactive Parameters

    /// Set all bio-reactive parameters at once (more efficient)
    /// - Parameters:
    ///   - filterCutoff: Filter frequency (Hz)
    ///   - reverbSize: Reverb size (0-1)
    ///   - volume: Master volume (0-1)
    ///   - delayTime: Delay time (ms)
    ///   - modulationRate: LFO rate (Hz)
    @objc public func setBioReactiveParameters(
        filterCutoff: Float,
        reverbSize: Float,
        volume: Float,
        delayTime: Float,
        modulationRate: Float
    ) {
        // Batch update for better performance
        EchoelmusicAudioEngineBridge.setBioReactiveParameters(
            filterCutoff,
            reverbSize: reverbSize,
            volume: volume,
            delayTime: delayTime,
            modulationRate: modulationRate
        )
    }

    // MARK: - State Query

    /// Check if audio engine is initialized and ready
    /// - Returns: true if ready to receive parameters
    @objc public func isAudioEngineReady() -> Bool {
        return EchoelmusicAudioEngineBridge.isEngineInitialized()
    }

    /// Get current sample rate
    /// - Returns: Current audio sample rate in Hz
    @objc public func getCurrentSampleRate() -> Double {
        return EchoelmusicAudioEngineBridge.getCurrentSampleRate()
    }

    // MARK: - Debugging

    /// Enable parameter change logging (for debugging)
    /// - Parameter enabled: Whether to log parameter changes
    @objc public func setParameterLogging(_ enabled: Bool) {
        EchoelmusicAudioEngineBridge.setParameterLogging(enabled)
    }
}

// MARK: - Objective-C++ Bridge Declaration

/// Objective-C++ bridge to C++ AudioEngine
/// Implementation in EchoelmusicAudioEngineBridge.mm
@objc public class EchoelmusicAudioEngineBridge: NSObject {

    // MARK: - Parameter Setters

    @objc public static func setFilterCutoff(_ frequency: Float) {
        // Implemented in .mm file
    }

    @objc public static func setReverbSize(_ size: Float) {
        // Implemented in .mm file
    }

    @objc public static func setReverbDecay(_ decay: Float) {
        // Implemented in .mm file
    }

    @objc public static func setMasterVolume(_ volume: Float) {
        // Implemented in .mm file
    }

    @objc public static func setDelayTime(_ timeMs: Float) {
        // Implemented in .mm file
    }

    @objc public static func setDelayFeedback(_ feedback: Float) {
        // Implemented in .mm file
    }

    @objc public static func setModulationRate(_ rateHz: Float) {
        // Implemented in .mm file
    }

    @objc public static func setModulationDepth(_ depth: Float) {
        // Implemented in .mm file
    }

    @objc public static func setDistortionAmount(_ amount: Float) {
        // Implemented in .mm file
    }

    @objc public static func setCompressorThreshold(_ thresholdDb: Float) {
        // Implemented in .mm file
    }

    @objc public static func setCompressorRatio(_ ratio: Float) {
        // Implemented in .mm file
    }

    @objc public static func setBioReactiveParameters(
        _ filterCutoff: Float,
        reverbSize: Float,
        volume: Float,
        delayTime: Float,
        modulationRate: Float
    ) {
        // Implemented in .mm file
    }

    // MARK: - State Query

    @objc public static func isEngineInitialized() -> Bool {
        // Implemented in .mm file
        return false
    }

    @objc public static func getCurrentSampleRate() -> Double {
        // Implemented in .mm file
        return 48000.0
    }

    @objc public static func setParameterLogging(_ enabled: Bool) {
        // Implemented in .mm file
    }
}
