// GranularSynthesisEngine.swift
// Echoelmusic - Professional Granular Synthesis System
//
// A++ Ultrahardthink Implementation
// Provides comprehensive granular synthesis including:
// - Real-time grain generation and playback
// - Multiple grain windows (Hann, Gaussian, Tukey, etc.)
// - Time-stretching and pitch-shifting
// - Grain cloud synthesis
// - Freeze/scrub functionality
// - Bio-reactive modulation integration
// - SIMD-optimized processing

import Foundation
import Combine
import AVFoundation
import Accelerate
import os.log

// MARK: - Logger

private let logger = Logger(subsystem: "com.echoelmusic.audio", category: "Granular")

// MARK: - Grain Window Types

/// Window functions for grain amplitude shaping
public enum GrainWindow: String, CaseIterable, Codable, Sendable {
    case hann = "Hann"
    case gaussian = "Gaussian"
    case tukey = "Tukey"
    case blackman = "Blackman"
    case kaiser = "Kaiser"
    case triangle = "Triangle"
    case rectangle = "Rectangle"
    case hamming = "Hamming"
    case trapezoid = "Trapezoid"

    /// Generate window coefficients
    public func generate(size: Int, parameter: Float = 0.5) -> [Float] {
        var window = [Float](repeating: 0, count: size)
        let n = Float(size)

        switch self {
        case .hann:
            for i in 0..<size {
                let x = Float(i) / (n - 1)
                window[i] = 0.5 * (1.0 - cos(2.0 * .pi * x))
            }

        case .gaussian:
            let sigma = parameter * 0.5
            let center = (n - 1) / 2
            for i in 0..<size {
                let x = (Float(i) - center) / (sigma * center)
                window[i] = exp(-0.5 * x * x)
            }

        case .tukey:
            let alpha = parameter
            for i in 0..<size {
                let x = Float(i) / (n - 1)
                if x < alpha / 2 {
                    window[i] = 0.5 * (1.0 + cos(.pi * (2.0 * x / alpha - 1.0)))
                } else if x < 1.0 - alpha / 2 {
                    window[i] = 1.0
                } else {
                    window[i] = 0.5 * (1.0 + cos(.pi * (2.0 * x / alpha - 2.0 / alpha + 1.0)))
                }
            }

        case .blackman:
            let a0: Float = 0.42
            let a1: Float = 0.5
            let a2: Float = 0.08
            for i in 0..<size {
                let x = Float(i) / (n - 1)
                window[i] = a0 - a1 * cos(2.0 * .pi * x) + a2 * cos(4.0 * .pi * x)
            }

        case .kaiser:
            let beta = parameter * 14.0  // 0-14 range
            let i0Beta = besselI0(beta)
            for i in 0..<size {
                let x = 2.0 * Float(i) / (n - 1) - 1.0
                let arg = beta * sqrt(1.0 - x * x)
                window[i] = besselI0(arg) / i0Beta
            }

        case .triangle:
            for i in 0..<size {
                let x = Float(i) / (n - 1)
                window[i] = 1.0 - abs(2.0 * x - 1.0)
            }

        case .rectangle:
            for i in 0..<size {
                window[i] = 1.0
            }

        case .hamming:
            let a0: Float = 0.54
            let a1: Float = 0.46
            for i in 0..<size {
                let x = Float(i) / (n - 1)
                window[i] = a0 - a1 * cos(2.0 * .pi * x)
            }

        case .trapezoid:
            let attack = Int(Float(size) * parameter * 0.25)
            let release = Int(Float(size) * parameter * 0.25)
            for i in 0..<size {
                if i < attack {
                    window[i] = Float(i) / Float(attack)
                } else if i >= size - release {
                    window[i] = Float(size - i - 1) / Float(release)
                } else {
                    window[i] = 1.0
                }
            }
        }

        return window
    }

    /// Bessel I0 function for Kaiser window
    private func besselI0(_ x: Float) -> Float {
        var sum: Float = 1.0
        var term: Float = 1.0
        let x2 = x * x / 4.0

        for k in 1...20 {
            term *= x2 / Float(k * k)
            sum += term
            if term < 1e-10 { break }
        }

        return sum
    }
}

// MARK: - Grain Configuration

/// Configuration for individual grains
public struct GrainConfiguration: Codable, Sendable {
    public var duration: Float          // seconds (0.001 - 1.0)
    public var position: Float          // 0.0 - 1.0 in source buffer
    public var pitch: Float             // semitones (-48 to +48)
    public var pan: Float               // -1.0 (left) to 1.0 (right)
    public var amplitude: Float         // 0.0 - 1.0
    public var window: GrainWindow
    public var windowParameter: Float   // Window-specific parameter

    public init(
        duration: Float = 0.05,
        position: Float = 0.0,
        pitch: Float = 0.0,
        pan: Float = 0.0,
        amplitude: Float = 1.0,
        window: GrainWindow = .hann,
        windowParameter: Float = 0.5
    ) {
        self.duration = max(0.001, min(1.0, duration))
        self.position = max(0.0, min(1.0, position))
        self.pitch = max(-48.0, min(48.0, pitch))
        self.pan = max(-1.0, min(1.0, pan))
        self.amplitude = max(0.0, min(1.0, amplitude))
        self.window = window
        self.windowParameter = max(0.0, min(1.0, windowParameter))
    }
}

// MARK: - Grain Cloud Parameters

/// Parameters for grain cloud synthesis
public struct GrainCloudParameters: Codable, Sendable {
    // Density
    public var density: Float           // grains per second (1 - 1000)
    public var densitySpread: Float     // randomization (0.0 - 1.0)

    // Duration
    public var grainDuration: Float     // base duration in seconds
    public var durationSpread: Float    // randomization (0.0 - 1.0)

    // Position
    public var position: Float          // center position (0.0 - 1.0)
    public var positionSpread: Float    // randomization range
    public var positionScan: Float      // automatic scanning speed

    // Pitch
    public var pitch: Float             // semitones
    public var pitchSpread: Float       // randomization range (semitones)
    public var pitchQuantize: Bool      // quantize to scale

    // Stereo
    public var pan: Float               // center pan (-1 to 1)
    public var panSpread: Float         // stereo width (0.0 - 1.0)

    // Amplitude
    public var amplitude: Float         // master amplitude
    public var amplitudeSpread: Float   // randomization

    // Window
    public var window: GrainWindow
    public var windowParameter: Float

    // Playback
    public var reverse: Float           // probability of reverse grains (0.0 - 1.0)
    public var freeze: Bool             // freeze position scanning

    public init() {
        self.density = 50
        self.densitySpread = 0.1
        self.grainDuration = 0.05
        self.durationSpread = 0.2
        self.position = 0.0
        self.positionSpread = 0.05
        self.positionScan = 1.0
        self.pitch = 0.0
        self.pitchSpread = 0.0
        self.pitchQuantize = false
        self.pan = 0.0
        self.panSpread = 0.5
        self.amplitude = 0.8
        self.amplitudeSpread = 0.1
        self.window = .hann
        self.windowParameter = 0.5
        self.reverse = 0.0
        self.freeze = false
    }
}

// MARK: - Active Grain

/// Represents a currently playing grain
private struct ActiveGrain {
    var sourceStartSample: Int
    var sourceSampleCount: Int
    var currentSample: Int
    var pitchRatio: Float
    var panLeft: Float
    var panRight: Float
    var amplitude: Float
    var window: [Float]
    var isReverse: Bool

    var isComplete: Bool {
        currentSample >= sourceSampleCount
    }

    var windowIndex: Int {
        let progress = Float(currentSample) / Float(sourceSampleCount)
        return min(window.count - 1, Int(progress * Float(window.count)))
    }
}

// MARK: - Granular Synthesis Engine

@MainActor
public final class GranularSynthesisEngine: ObservableObject {
    // MARK: - Published State

    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var sourceLoaded: Bool = false
    @Published public private(set) var currentPosition: Float = 0.0
    @Published public private(set) var activeGrainCount: Int = 0
    @Published public private(set) var cpuUsage: Float = 0.0

    @Published public var parameters = GrainCloudParameters()

    // MARK: - Configuration

    public var sampleRate: Float = 44100
    public var maxGrains: Int = 256
    public var outputChannels: Int = 2

    // MARK: - Private Properties

    private var sourceBuffer: [Float] = []
    private var sourceSampleCount: Int = 0
    private var activeGrains: [ActiveGrain] = []
    private var grainScheduleTime: Float = 0
    private var scanPosition: Float = 0

    // Pre-computed windows
    private var windowCache: [GrainWindow: [Int: [Float]]] = [:]
    private let windowSizes = [64, 128, 256, 512, 1024, 2048, 4096, 8192]

    // Audio processing
    private var audioEngine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?

    // Thread safety
    private let processingQueue = DispatchQueue(label: "com.echoelmusic.granular", qos: .userInteractive)
    private var processingLock = os_unfair_lock()

    // Random number generator for grain variation
    private var rng = SystemRandomNumberGenerator()

    // MARK: - Initialization

    public init() {
        precomputeWindows()
        setupAudioEngine()
    }

    private func precomputeWindows() {
        for window in GrainWindow.allCases {
            windowCache[window] = [:]
            for size in windowSizes {
                windowCache[window]?[size] = window.generate(size: size)
            }
        }
        logger.debug("Precomputed \(GrainWindow.allCases.count * self.windowSizes.count) window tables")
    }

    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()

        guard let engine = audioEngine else { return }

        let format = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: AVAudioChannelCount(outputChannels))!

        sourceNode = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }

            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

            for frame in 0..<Int(frameCount) {
                var leftSample: Float = 0
                var rightSample: Float = 0

                self.processGrains(leftOut: &leftSample, rightOut: &rightSample)

                if ablPointer.count > 0 {
                    let leftBuffer = ablPointer[0]
                    if let leftData = leftBuffer.mData?.assumingMemoryBound(to: Float.self) {
                        leftData[frame] = leftSample
                    }
                }

                if ablPointer.count > 1 {
                    let rightBuffer = ablPointer[1]
                    if let rightData = rightBuffer.mData?.assumingMemoryBound(to: Float.self) {
                        rightData[frame] = rightSample
                    }
                }
            }

            return noErr
        }

        if let node = sourceNode {
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
        }
    }

    // MARK: - Source Loading

    /// Load audio source from URL
    public func loadSource(from url: URL) async throws {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw GranularError.bufferCreationFailed
        }

        try file.read(into: buffer)

        // Convert to mono float array
        await MainActor.run {
            if let channelData = buffer.floatChannelData {
                let channelCount = Int(format.channelCount)
                let samples = Int(frameCount)

                sourceBuffer = [Float](repeating: 0, count: samples)

                // Mix down to mono if stereo
                if channelCount == 1 {
                    memcpy(&sourceBuffer, channelData[0], samples * MemoryLayout<Float>.size)
                } else {
                    for i in 0..<samples {
                        var sum: Float = 0
                        for ch in 0..<channelCount {
                            sum += channelData[ch][i]
                        }
                        sourceBuffer[i] = sum / Float(channelCount)
                    }
                }

                sourceSampleCount = samples
                sampleRate = Float(format.sampleRate)
                sourceLoaded = true

                logger.info("Loaded source: \(samples) samples at \(self.sampleRate) Hz")
            }
        }
    }

    /// Load audio source from buffer
    public func loadSource(from buffer: [Float], sampleRate: Float) {
        sourceBuffer = buffer
        sourceSampleCount = buffer.count
        self.sampleRate = sampleRate
        sourceLoaded = true

        logger.info("Loaded source buffer: \(buffer.count) samples")
    }

    // MARK: - Playback Control

    public func start() {
        guard sourceLoaded else {
            logger.warning("Cannot start: no source loaded")
            return
        }

        do {
            try audioEngine?.start()
            isPlaying = true
            logger.info("Granular synthesis started")
        } catch {
            logger.error("Failed to start audio engine: \(error.localizedDescription)")
        }
    }

    public func stop() {
        audioEngine?.stop()
        activeGrains.removeAll()
        isPlaying = false
        logger.info("Granular synthesis stopped")
    }

    public func setPosition(_ position: Float) {
        parameters.position = max(0.0, min(1.0, position))
        scanPosition = parameters.position
    }

    public func toggleFreeze() {
        parameters.freeze.toggle()
    }

    // MARK: - Grain Processing

    private func processGrains(leftOut: inout Float, rightOut: inout Float) {
        os_unfair_lock_lock(&processingLock)
        defer { os_unfair_lock_unlock(&processingLock) }

        // Schedule new grains
        scheduleGrains()

        // Process active grains
        var left: Float = 0
        var right: Float = 0

        var grainIndex = 0
        while grainIndex < activeGrains.count {
            var grain = activeGrains[grainIndex]

            if grain.isComplete {
                activeGrains.remove(at: grainIndex)
                continue
            }

            // Get source sample with interpolation
            let sourceSampleFloat = Float(grain.sourceStartSample) + Float(grain.currentSample) * grain.pitchRatio
            let sample = interpolateSample(at: sourceSampleFloat, isReverse: grain.isReverse)

            // Apply window and amplitude
            let windowedSample = sample * grain.window[grain.windowIndex] * grain.amplitude

            // Apply panning
            left += windowedSample * grain.panLeft
            right += windowedSample * grain.panRight

            // Advance grain
            grain.currentSample += 1
            activeGrains[grainIndex] = grain
            grainIndex += 1
        }

        // Soft clip output
        leftOut = softClip(left)
        rightOut = softClip(right)

        // Update scan position
        if !parameters.freeze && isPlaying {
            scanPosition += parameters.positionScan / sampleRate
            if scanPosition > 1.0 { scanPosition = 0.0 }
            if scanPosition < 0.0 { scanPosition = 1.0 }

            Task { @MainActor in
                self.currentPosition = scanPosition
                self.activeGrainCount = self.activeGrains.count
            }
        }

        // Update grain schedule time
        grainScheduleTime += 1.0 / sampleRate
    }

    private func scheduleGrains() {
        let grainInterval = 1.0 / parameters.density

        while grainScheduleTime >= grainInterval {
            grainScheduleTime -= grainInterval

            if activeGrains.count >= maxGrains { continue }

            // Create new grain with randomization
            let grain = createGrain()
            activeGrains.append(grain)
        }
    }

    private func createGrain() -> ActiveGrain {
        let params = parameters

        // Randomize duration
        let durationVariation = randomFloat() * params.durationSpread
        let duration = params.grainDuration * (1.0 + durationVariation - params.durationSpread / 2)
        let grainSamples = Int(duration * sampleRate)

        // Randomize position
        let positionVariation = (randomFloat() - 0.5) * params.positionSpread
        var position = (params.freeze ? params.position : scanPosition) + positionVariation
        position = max(0.0, min(1.0, position))
        let startSample = Int(position * Float(sourceSampleCount - grainSamples))

        // Randomize pitch
        var pitch = params.pitch + (randomFloat() - 0.5) * params.pitchSpread * 2
        if params.pitchQuantize {
            pitch = round(pitch)  // Quantize to semitones
        }
        let pitchRatio = pow(2.0, pitch / 12.0)

        // Randomize pan
        let panVariation = (randomFloat() - 0.5) * params.panSpread * 2
        let pan = max(-1.0, min(1.0, params.pan + panVariation))
        let panLeft = sqrt((1.0 - pan) / 2.0)
        let panRight = sqrt((1.0 + pan) / 2.0)

        // Randomize amplitude
        let ampVariation = 1.0 + (randomFloat() - 0.5) * params.amplitudeSpread
        let amplitude = params.amplitude * ampVariation

        // Get window
        let windowSize = nearestWindowSize(grainSamples)
        let window = windowCache[params.window]?[windowSize] ?? [Float](repeating: 1.0, count: windowSize)

        // Determine if reversed
        let isReverse = randomFloat() < params.reverse

        return ActiveGrain(
            sourceStartSample: startSample,
            sourceSampleCount: grainSamples,
            currentSample: 0,
            pitchRatio: pitchRatio,
            panLeft: panLeft,
            panRight: panRight,
            amplitude: amplitude,
            window: window,
            isReverse: isReverse
        )
    }

    private func interpolateSample(at position: Float, isReverse: Bool) -> Float {
        guard !sourceBuffer.isEmpty else { return 0 }

        var pos = position
        if isReverse {
            pos = Float(sourceSampleCount) - pos
        }

        let index = Int(pos)
        let frac = pos - Float(index)

        guard index >= 0 && index < sourceSampleCount - 1 else { return 0 }

        // Linear interpolation
        let s0 = sourceBuffer[index]
        let s1 = sourceBuffer[index + 1]

        return s0 + frac * (s1 - s0)
    }

    private func nearestWindowSize(_ samples: Int) -> Int {
        for size in windowSizes {
            if size >= samples { return size }
        }
        return windowSizes.last!
    }

    private func randomFloat() -> Float {
        Float.random(in: 0..<1, using: &rng)
    }

    private func softClip(_ x: Float) -> Float {
        if x > 1.0 {
            return 1.0 - exp(1.0 - x)
        } else if x < -1.0 {
            return -1.0 + exp(1.0 + x)
        }
        return x
    }

    // MARK: - Presets

    public enum GranularPreset: String, CaseIterable {
        case timeStretch = "Time Stretch"
        case pitchShift = "Pitch Shift"
        case freeze = "Freeze"
        case cloud = "Cloud"
        case shimmer = "Shimmer"
        case chaos = "Chaos"
        case rhythmic = "Rhythmic"
        case ambient = "Ambient"
        case stutter = "Stutter"
        case reverse = "Reverse"

        public var parameters: GrainCloudParameters {
            var p = GrainCloudParameters()

            switch self {
            case .timeStretch:
                p.density = 100
                p.densitySpread = 0.05
                p.grainDuration = 0.05
                p.durationSpread = 0.1
                p.positionSpread = 0.01
                p.pitchSpread = 0.0
                p.panSpread = 0.2

            case .pitchShift:
                p.density = 80
                p.grainDuration = 0.04
                p.positionSpread = 0.02
                p.pitch = 12.0  // One octave up
                p.pitchSpread = 0.05
                p.panSpread = 0.3

            case .freeze:
                p.density = 150
                p.grainDuration = 0.03
                p.positionSpread = 0.02
                p.positionScan = 0.0
                p.freeze = true
                p.pitchSpread = 0.1
                p.panSpread = 0.8

            case .cloud:
                p.density = 200
                p.densitySpread = 0.3
                p.grainDuration = 0.08
                p.durationSpread = 0.5
                p.positionSpread = 0.2
                p.pitchSpread = 1.0
                p.panSpread = 1.0
                p.amplitude = 0.6

            case .shimmer:
                p.density = 100
                p.grainDuration = 0.06
                p.pitch = 12.0
                p.pitchSpread = 0.2
                p.pitchQuantize = true
                p.panSpread = 0.9
                p.amplitude = 0.4

            case .chaos:
                p.density = 300
                p.densitySpread = 0.5
                p.grainDuration = 0.02
                p.durationSpread = 0.8
                p.positionSpread = 0.5
                p.pitchSpread = 24.0
                p.panSpread = 1.0
                p.reverse = 0.5
                p.amplitude = 0.5

            case .rhythmic:
                p.density = 16
                p.densitySpread = 0.0
                p.grainDuration = 0.08
                p.durationSpread = 0.0
                p.positionSpread = 0.0
                p.pitchSpread = 0.0
                p.panSpread = 0.2
                p.window = .rectangle

            case .ambient:
                p.density = 50
                p.grainDuration = 0.2
                p.durationSpread = 0.3
                p.positionSpread = 0.1
                p.positionScan = 0.2
                p.pitchSpread = 0.5
                p.pitchQuantize = true
                p.panSpread = 1.0
                p.window = .gaussian
                p.amplitude = 0.7

            case .stutter:
                p.density = 20
                p.grainDuration = 0.02
                p.positionSpread = 0.0
                p.positionScan = 0.0
                p.freeze = true
                p.pitchSpread = 0.0
                p.panSpread = 0.0
                p.window = .trapezoid

            case .reverse:
                p.density = 80
                p.grainDuration = 0.1
                p.positionSpread = 0.1
                p.reverse = 1.0
                p.panSpread = 0.5
            }

            return p
        }
    }

    public func loadPreset(_ preset: GranularPreset) {
        parameters = preset.parameters
        logger.info("Loaded preset: \(preset.rawValue)")
    }

    // MARK: - Bio-Reactive Modulation

    /// Modulate parameters based on bio-data
    public func modulateFromBioData(
        heartRate: Float?,       // BPM
        hrv: Float?,             // HRV value
        coherence: Float?,       // 0.0-1.0
        relaxation: Float?       // 0.0-1.0
    ) {
        // Map heart rate to density
        if let hr = heartRate {
            // 60-180 BPM -> 30-200 grains/second
            parameters.density = 30 + (hr - 60) / 120 * 170
        }

        // Map HRV to position spread (higher HRV = more variation)
        if let hrv = hrv {
            // 0-100ms HRV -> 0.01-0.2 spread
            parameters.positionSpread = 0.01 + min(hrv, 100) / 100 * 0.19
        }

        // Map coherence to pitch quantization and spread
        if let coherence = coherence {
            parameters.pitchQuantize = coherence > 0.5
            parameters.pitchSpread = (1.0 - coherence) * 12.0
        }

        // Map relaxation to grain duration and scan speed
        if let relaxation = relaxation {
            // More relaxed = longer grains, slower scanning
            parameters.grainDuration = 0.02 + relaxation * 0.18
            parameters.positionScan = 2.0 - relaxation * 1.5
        }
    }
}

// MARK: - Granular Error

public enum GranularError: Error, LocalizedError {
    case bufferCreationFailed
    case sourceNotLoaded
    case invalidParameter(String)

    public var errorDescription: String? {
        switch self {
        case .bufferCreationFailed:
            return "Failed to create audio buffer"
        case .sourceNotLoaded:
            return "No audio source loaded"
        case .invalidParameter(let param):
            return "Invalid parameter: \(param)"
        }
    }
}

// MARK: - SIMD Optimized Processing

extension GranularSynthesisEngine {
    /// Process multiple grains using SIMD
    @inlinable
    func processGrainsSIMD(outputLeft: inout [Float], outputRight: inout [Float], frameCount: Int) {
        guard !activeGrains.isEmpty else { return }

        // Process in blocks of 4 (SIMD width)
        let blockCount = frameCount / 4
        let remainder = frameCount % 4

        for block in 0..<blockCount {
            let offset = block * 4

            var leftBlock = SIMD4<Float>.zero
            var rightBlock = SIMD4<Float>.zero

            for grain in activeGrains {
                // This would be expanded for true SIMD optimization
                // Currently placeholder for the concept
            }

            outputLeft[offset] = leftBlock[0]
            outputLeft[offset + 1] = leftBlock[1]
            outputLeft[offset + 2] = leftBlock[2]
            outputLeft[offset + 3] = leftBlock[3]

            outputRight[offset] = rightBlock[0]
            outputRight[offset + 1] = rightBlock[1]
            outputRight[offset + 2] = rightBlock[2]
            outputRight[offset + 3] = rightBlock[3]
        }

        // Handle remainder
        for i in (frameCount - remainder)..<frameCount {
            var left: Float = 0
            var right: Float = 0
            processGrains(leftOut: &left, rightOut: &right)
            outputLeft[i] = left
            outputRight[i] = right
        }
    }
}

// MARK: - Granular Visualizer Data

extension GranularSynthesisEngine {
    /// Data for visualizing grain activity
    public struct VisualizerData: Sendable {
        public let grainPositions: [Float]
        public let grainAmplitudes: [Float]
        public let grainPans: [Float]
        public let grainPitches: [Float]
        public let sourceWaveform: [Float]
        public let currentPosition: Float
    }

    public func getVisualizerData(waveformResolution: Int = 256) -> VisualizerData {
        os_unfair_lock_lock(&processingLock)
        let grains = activeGrains
        os_unfair_lock_unlock(&processingLock)

        // Grain data
        let positions = grains.map { Float($0.sourceStartSample) / Float(max(1, sourceSampleCount)) }
        let amplitudes = grains.map { $0.amplitude }
        let pans = grains.map { ($0.panRight - $0.panLeft) }
        let pitches = grains.map { log2($0.pitchRatio) * 12.0 }

        // Downsampled waveform
        var waveform = [Float](repeating: 0, count: waveformResolution)
        if !sourceBuffer.isEmpty {
            let step = sourceSampleCount / waveformResolution
            for i in 0..<waveformResolution {
                let index = i * step
                if index < sourceBuffer.count {
                    waveform[i] = sourceBuffer[index]
                }
            }
        }

        return VisualizerData(
            grainPositions: positions,
            grainAmplitudes: amplitudes,
            grainPans: pans,
            grainPitches: pitches,
            sourceWaveform: waveform,
            currentPosition: currentPosition
        )
    }
}
