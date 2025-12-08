import Foundation
import Combine

#if canImport(AVFoundation)
import AVFoundation
#endif

#if canImport(Accelerate)
import Accelerate
#endif

// ═══════════════════════════════════════════════════════════════════════════════
// CROSS-PLATFORM AUDIO BRIDGE FOR ECHOELMUSIC
// ═══════════════════════════════════════════════════════════════════════════════
//
// Unified audio API that abstracts platform-specific implementations:
// • Apple Platforms: AVFoundation + CoreAudio + Accelerate
// • Android: Oboe (AAudio/OpenSL ES) via JNI
// • Windows: ASIO/WASAPI via native bridge
// • Linux: JACK/PipeWire via native bridge
//
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - Audio Bridge Protocol

/// Protocol for cross-platform audio implementations
public protocol AudioBridgeProtocol {
    /// Initialize the audio engine
    func initialize(config: AudioBridgeConfig) async throws

    /// Start audio processing
    func start() async throws

    /// Stop audio processing
    func stop() async

    /// Process audio buffer
    func process(input: UnsafePointer<Float>, output: UnsafeMutablePointer<Float>, frameCount: Int)

    /// Get current latency
    var currentLatencyMs: Double { get }

    /// Get sample rate
    var sampleRate: Double { get }

    /// Get buffer size
    var bufferSize: Int { get }

    /// Check if running
    var isRunning: Bool { get }
}

// MARK: - Audio Bridge Configuration

public struct AudioBridgeConfig {
    public var sampleRate: Double = 48000
    public var bufferSize: Int = 256
    public var inputChannels: Int = 1
    public var outputChannels: Int = 2
    public var enableInput: Bool = true
    public var enableOutput: Bool = true
    public var preferLowLatency: Bool = true
    public var preferExclusiveMode: Bool = false

    public init() {}

    public init(sampleRate: Double, bufferSize: Int) {
        self.sampleRate = sampleRate
        self.bufferSize = bufferSize
    }
}

// MARK: - Cross-Platform Audio Bridge

@MainActor
public final class CrossPlatformAudioBridge: ObservableObject {

    // MARK: Singleton
    public static let shared = CrossPlatformAudioBridge()

    // MARK: Published State
    @Published public private(set) var isInitialized: Bool = false
    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var currentLatencyMs: Double = 0
    @Published public private(set) var sampleRate: Double = 48000
    @Published public private(set) var bufferSize: Int = 256
    @Published public private(set) var cpuLoad: Double = 0
    @Published public private(set) var audioLevel: Float = 0

    // MARK: Private
    private var implementation: (any AudioBridgeProtocol)?
    private var processCallback: ((UnsafePointer<Float>, UnsafeMutablePointer<Float>, Int) -> Void)?
    private var cancellables = Set<AnyCancellable>()

    #if os(iOS) || os(macOS) || os(tvOS) || os(watchOS) || os(visionOS)
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var outputNode: AVAudioOutputNode?
    #endif

    // MARK: Initialization
    private init() {
        print("=== CrossPlatformAudioBridge Initialized ===")
    }

    // MARK: - Public API

    /// Initialize audio with configuration
    public func initialize(config: AudioBridgeConfig = AudioBridgeConfig()) async throws {
        print("Initializing Audio Bridge...")
        print("  Sample Rate: \(config.sampleRate) Hz")
        print("  Buffer Size: \(config.bufferSize) samples")

        #if os(iOS) || os(macOS) || os(tvOS) || os(watchOS) || os(visionOS)
        try await initializeApplePlatform(config: config)
        #else
        // For Android/Windows/Linux, use native bridge
        try await initializeNativeBridge(config: config)
        #endif

        sampleRate = config.sampleRate
        bufferSize = config.bufferSize
        currentLatencyMs = Double(config.bufferSize) / config.sampleRate * 1000

        isInitialized = true
        print("Audio Bridge initialized successfully")
    }

    /// Start audio processing
    public func start() async throws {
        guard isInitialized else {
            throw AudioBridgeError.notInitialized
        }

        #if os(iOS) || os(macOS) || os(tvOS) || os(watchOS) || os(visionOS)
        try startApplePlatform()
        #else
        try await startNativeBridge()
        #endif

        isRunning = true
        print("Audio Bridge started")
    }

    /// Stop audio processing
    public func stop() async {
        #if os(iOS) || os(macOS) || os(tvOS) || os(watchOS) || os(visionOS)
        stopApplePlatform()
        #else
        await stopNativeBridge()
        #endif

        isRunning = false
        print("Audio Bridge stopped")
    }

    /// Set the audio process callback
    public func setProcessCallback(_ callback: @escaping (UnsafePointer<Float>, UnsafeMutablePointer<Float>, Int) -> Void) {
        processCallback = callback
    }

    // MARK: - Apple Platform Implementation

    #if os(iOS) || os(macOS) || os(tvOS) || os(watchOS) || os(visionOS)
    private func initializeApplePlatform(config: AudioBridgeConfig) async throws {
        audioEngine = AVAudioEngine()

        #if os(iOS)
        // Configure audio session for iOS
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [
            .allowBluetooth,
            .allowBluetoothA2DP,
            .defaultToSpeaker,
            .mixWithOthers
        ])

        // Set preferred settings
        let bufferDuration = Double(config.bufferSize) / config.sampleRate
        try session.setPreferredIOBufferDuration(bufferDuration)
        try session.setPreferredSampleRate(config.sampleRate)
        try session.setActive(true)
        #endif

        guard let engine = audioEngine else { return }

        inputNode = engine.inputNode
        outputNode = engine.outputNode

        // Get native format
        let inputFormat = inputNode?.inputFormat(forBus: 0)
        let outputFormat = outputNode?.outputFormat(forBus: 0)

        print("  Input Format: \(inputFormat?.sampleRate ?? 0) Hz, \(inputFormat?.channelCount ?? 0) ch")
        print("  Output Format: \(outputFormat?.sampleRate ?? 0) Hz, \(outputFormat?.channelCount ?? 0) ch")

        // Install tap for audio processing
        if config.enableInput, let inputNode = inputNode {
            let format = inputNode.inputFormat(forBus: 0)

            inputNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(config.bufferSize), format: format) { [weak self] buffer, time in
                self?.processAudioBuffer(buffer)
            }
        }
    }

    private func startApplePlatform() throws {
        guard let engine = audioEngine else {
            throw AudioBridgeError.engineNotCreated
        }

        try engine.start()
    }

    private func stopApplePlatform() {
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let floatData = buffer.floatChannelData else { return }

        let frameCount = Int(buffer.frameLength)
        let inputPtr = floatData[0]

        // Calculate audio level
        var rms: Float = 0
        vDSP_rmsqv(inputPtr, 1, &rms, vDSP_Length(frameCount))
        audioLevel = rms

        // Call user callback if set
        if let callback = processCallback {
            // Allocate output buffer
            var outputBuffer = [Float](repeating: 0, count: frameCount)
            outputBuffer.withUnsafeMutableBufferPointer { outPtr in
                callback(inputPtr, outPtr.baseAddress!, frameCount)
            }
        }
    }
    #endif

    // MARK: - Native Bridge Implementation (Android/Windows/Linux)

    private func initializeNativeBridge(config: AudioBridgeConfig) async throws {
        // This would call into native code via JNI (Android) or C++ (Windows/Linux)
        print("Initializing native audio bridge...")

        #if os(Android)
        // Initialize Oboe
        print("  Using Oboe (Android)")
        #elseif os(Windows)
        // Initialize ASIO/WASAPI
        print("  Using ASIO/WASAPI (Windows)")
        #elseif os(Linux)
        // Initialize JACK/PipeWire
        print("  Using JACK/PipeWire (Linux)")
        #endif
    }

    private func startNativeBridge() async throws {
        // Start native audio
    }

    private func stopNativeBridge() async {
        // Stop native audio
    }

    // MARK: - Utility Methods

    /// Get optimal configuration for current platform
    @MainActor
    public static func getOptimalConfig() -> AudioBridgeConfig {
        var config = AudioBridgeConfig()

        let platformManager = UnifiedPlatformManager.shared
        let tier = platformManager.performanceTier

        config.bufferSize = tier.audioBufferSize
        config.sampleRate = Double(platformManager.capabilities.audio.maxSampleRate)
        config.preferLowLatency = tier != .low

        return config
    }

    /// Calculate latency for given configuration
    public static func calculateLatency(sampleRate: Double, bufferSize: Int, bufferCount: Int = 2) -> Double {
        return Double(bufferSize * bufferCount) / sampleRate * 1000.0  // ms
    }
}

// MARK: - Audio Bridge Errors

public enum AudioBridgeError: Error, LocalizedError {
    case notInitialized
    case engineNotCreated
    case invalidConfiguration
    case permissionDenied
    case deviceNotAvailable
    case startFailed(String)
    case nativeBridgeError(String)

    public var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Audio bridge not initialized"
        case .engineNotCreated:
            return "Audio engine not created"
        case .invalidConfiguration:
            return "Invalid audio configuration"
        case .permissionDenied:
            return "Microphone permission denied"
        case .deviceNotAvailable:
            return "Audio device not available"
        case .startFailed(let message):
            return "Failed to start audio: \(message)"
        case .nativeBridgeError(let message):
            return "Native bridge error: \(message)"
        }
    }
}

// MARK: - Audio Format Utilities

public enum AudioFormatUtils {

    /// Convert sample rate to human-readable string
    public static func formatSampleRate(_ rate: Double) -> String {
        if rate >= 1000 {
            return "\(Int(rate / 1000))kHz"
        }
        return "\(Int(rate))Hz"
    }

    /// Convert latency to human-readable string
    public static func formatLatency(_ ms: Double) -> String {
        if ms < 1 {
            return String(format: "%.1fμs", ms * 1000)
        }
        return String(format: "%.1fms", ms)
    }

    /// Get recommended buffer size for target latency
    public static func bufferSizeForLatency(targetMs: Double, sampleRate: Double) -> Int {
        let samples = Int(targetMs / 1000.0 * sampleRate)
        // Round to power of 2
        return 1 << Int(log2(Double(samples)).rounded())
    }

    /// Calculate round-trip latency
    public static func roundTripLatency(bufferSize: Int, sampleRate: Double, systemLatencyMs: Double = 5.0) -> Double {
        let bufferLatency = Double(bufferSize) / sampleRate * 1000.0 * 2  // Input + Output
        return bufferLatency + systemLatencyMs
    }
}

// MARK: - Audio Level Meter

/// Cross-platform audio level metering
public final class AudioLevelMeter {

    private var peakHold: Float = 0
    private var peakHoldDecay: Float = 0.9995
    private var smoothing: Float = 0.3

    private var currentRMS: Float = 0
    private var currentPeak: Float = 0

    public init() {}

    /// Process audio buffer and update levels
    public func process(_ buffer: UnsafePointer<Float>, count: Int) {
        #if canImport(Accelerate)
        // Calculate RMS using Accelerate
        var rms: Float = 0
        vDSP_rmsqv(buffer, 1, &rms, vDSP_Length(count))

        // Calculate peak using Accelerate
        var peak: Float = 0
        vDSP_maxmgv(buffer, 1, &peak, vDSP_Length(count))
        #else
        // Fallback implementation
        var sumSquares: Float = 0
        var peak: Float = 0

        for i in 0..<count {
            let sample = buffer[i]
            sumSquares += sample * sample
            let absSample = abs(sample)
            if absSample > peak {
                peak = absSample
            }
        }

        let rms = sqrt(sumSquares / Float(count))
        #endif

        // Apply smoothing
        currentRMS = currentRMS * smoothing + rms * (1 - smoothing)
        currentPeak = max(currentPeak * peakHoldDecay, peak)

        // Update peak hold
        if peak > peakHold {
            peakHold = peak
        } else {
            peakHold *= peakHoldDecay
        }
    }

    /// Get current RMS level (0-1)
    public var rmsLevel: Float { currentRMS }

    /// Get current peak level (0-1)
    public var peakLevel: Float { currentPeak }

    /// Get peak hold level (0-1)
    public var peakHoldLevel: Float { peakHold }

    /// Get RMS level in dB
    public var rmsLevelDB: Float {
        20 * log10(max(currentRMS, 1e-10))
    }

    /// Get peak level in dB
    public var peakLevelDB: Float {
        20 * log10(max(currentPeak, 1e-10))
    }

    /// Reset all levels
    public func reset() {
        currentRMS = 0
        currentPeak = 0
        peakHold = 0
    }
}

// MARK: - Binaural Audio Processor

/// Cross-platform binaural beat generator
public final class BinauralProcessor {

    private var leftPhase: Float = 0
    private var rightPhase: Float = 0
    private var carrierFrequency: Float = 200  // Hz
    private var beatFrequency: Float = 10  // Hz

    private var sampleRate: Float = 48000

    public init(sampleRate: Float = 48000) {
        self.sampleRate = sampleRate
    }

    /// Set carrier frequency (base tone)
    public func setCarrierFrequency(_ freq: Float) {
        carrierFrequency = freq
    }

    /// Set beat frequency (difference between ears)
    public func setBeatFrequency(_ freq: Float) {
        beatFrequency = freq
    }

    /// Process and generate binaural audio
    public func process(output: UnsafeMutablePointer<Float>, frameCount: Int, amplitude: Float = 0.5) {
        let leftFreq = carrierFrequency - beatFrequency / 2
        let rightFreq = carrierFrequency + beatFrequency / 2

        let leftPhaseInc = leftFreq / sampleRate * 2 * Float.pi
        let rightPhaseInc = rightFreq / sampleRate * 2 * Float.pi

        for i in 0..<frameCount {
            // Interleaved stereo output
            output[i * 2] = sin(leftPhase) * amplitude      // Left
            output[i * 2 + 1] = sin(rightPhase) * amplitude // Right

            leftPhase += leftPhaseInc
            rightPhase += rightPhaseInc

            // Wrap phase to avoid floating point precision issues
            if leftPhase > 2 * Float.pi { leftPhase -= 2 * Float.pi }
            if rightPhase > 2 * Float.pi { rightPhase -= 2 * Float.pi }
        }
    }

    /// Brainwave state presets
    public enum BrainwaveState: String, CaseIterable {
        case delta = "Delta (0.5-4 Hz)"      // Deep sleep
        case theta = "Theta (4-8 Hz)"        // Meditation
        case alpha = "Alpha (8-13 Hz)"       // Relaxation
        case beta = "Beta (13-30 Hz)"        // Focus
        case gamma = "Gamma (30-100 Hz)"     // Peak performance

        public var frequencyRange: ClosedRange<Float> {
            switch self {
            case .delta: return 0.5...4
            case .theta: return 4...8
            case .alpha: return 8...13
            case .beta: return 13...30
            case .gamma: return 30...100
            }
        }

        public var recommendedFrequency: Float {
            switch self {
            case .delta: return 2
            case .theta: return 6
            case .alpha: return 10
            case .beta: return 20
            case .gamma: return 40
            }
        }
    }

    /// Set target brainwave state
    public func setTargetState(_ state: BrainwaveState) {
        beatFrequency = state.recommendedFrequency
    }
}

// MARK: - Audio Buffer Pool

/// Cross-platform audio buffer management
public final class AudioBufferManager {

    private let bufferSize: Int
    private let maxBuffers: Int
    private var buffers: [[Float]]
    private var availableIndices: [Int]
    private let lock = NSLock()

    public init(bufferSize: Int, maxBuffers: Int = 16) {
        self.bufferSize = bufferSize
        self.maxBuffers = maxBuffers

        // Pre-allocate buffers
        self.buffers = (0..<maxBuffers).map { _ in
            [Float](repeating: 0, count: bufferSize)
        }
        self.availableIndices = Array(0..<maxBuffers)
    }

    /// Acquire a buffer from the pool
    public func acquire() -> (buffer: UnsafeMutablePointer<Float>, index: Int)? {
        lock.lock()
        defer { lock.unlock() }

        guard let index = availableIndices.popLast() else {
            return nil
        }

        return (buffers[index].withUnsafeMutableBufferPointer { $0.baseAddress! }, index)
    }

    /// Release a buffer back to the pool
    public func release(index: Int) {
        lock.lock()
        defer { lock.unlock() }

        // Clear buffer
        #if canImport(Accelerate)
        vDSP_vclr(&buffers[index], 1, vDSP_Length(bufferSize))
        #else
        buffers[index] = [Float](repeating: 0, count: bufferSize)
        #endif

        availableIndices.append(index)
    }

    /// Get number of available buffers
    public var availableCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return availableIndices.count
    }
}
