import Foundation
import Accelerate
import simd

// MARK: - Granular Synthesizer
// Cloud-based granular synthesis with morphing capabilities
// Inspired by: Csound, Kyma, Ableton Granulator, Reaktor Grain

/// GranularSynthesizer: Advanced granular synthesis with cloud morphing
/// Implements microsound techniques from Curtis Roads' "Microsound" (MIT Press, 2001)
///
/// Features:
/// - Multi-source grain clouds
/// - Stochastic and deterministic grain scheduling
/// - Grain cloud morphing (position, density, size)
/// - Spectral stretching and pitch shifting
/// - Spatial grain distribution
/// - Real-time parameter modulation
public final class GranularSynthesizer {

    // MARK: - Types

    /// Grain envelope shapes
    public enum GrainEnvelope: Int, CaseIterable {
        case gaussian       // Smooth, natural
        case hanning        // Classic window
        case triangle       // Linear attack/decay
        case trapezoid      // Sustain plateau
        case expodec        // Exponential decay
        case rexpodec       // Reverse exponential
        case sinc           // Band-limited
        case custom         // User-defined

        var displayName: String {
            switch self {
            case .gaussian: return "Gaussian"
            case .hanning: return "Hanning"
            case .triangle: return "Triangle"
            case .trapezoid: return "Trapezoid"
            case .expodec: return "Exp Decay"
            case .rexpodec: return "Rev Exp"
            case .sinc: return "Sinc"
            case .custom: return "Custom"
            }
        }
    }

    /// Grain scheduling modes
    public enum SchedulingMode: Int, CaseIterable {
        case synchronous    // Regular intervals
        case asynchronous   // Random timing
        case quasiSync      // Hybrid approach
        case burst          // Grain bursts
        case cloud          // Dense overlapping
        case stream         // Continuous flow
    }

    /// Grain pitch modes
    public enum PitchMode: Int, CaseIterable {
        case original       // Source pitch
        case fixed          // Fixed frequency
        case random         // Random within range
        case chromatic      // Quantized to scale
        case harmonics      // Harmonic series
        case formant        // Formant preservation
    }

    /// Source buffer for granulation
    public struct GrainSource {
        var buffer: [Float]
        var sampleRate: Float
        var name: String
        var loopStart: Int
        var loopEnd: Int
        var isLooping: Bool

        public init(buffer: [Float], sampleRate: Float = 44100, name: String = "Source") {
            self.buffer = buffer
            self.sampleRate = sampleRate
            self.name = name
            self.loopStart = 0
            self.loopEnd = buffer.count
            self.isLooping = true
        }

        /// Create from waveform generator
        public static func fromWaveform(_ type: WaveformType, length: Int = 44100) -> GrainSource {
            var buffer = [Float](repeating: 0, count: length)
            let phase_inc = Float.pi * 2 / Float(length)

            for i in 0..<length {
                let phase = Float(i) * phase_inc
                switch type {
                case .sine:
                    buffer[i] = sin(phase)
                case .saw:
                    buffer[i] = 2 * (Float(i) / Float(length)) - 1
                case .triangle:
                    let t = Float(i) / Float(length)
                    buffer[i] = 4 * abs(t - 0.5) - 1
                case .pulse:
                    buffer[i] = Float(i) < Float(length) / 2 ? 1 : -1
                case .noise:
                    buffer[i] = Float.random(in: -1...1)
                }
            }

            return GrainSource(buffer: buffer, name: type.rawValue)
        }

        public enum WaveformType: String {
            case sine, saw, triangle, pulse, noise
        }
    }

    /// Individual grain state
    private struct Grain {
        var isActive: Bool = false
        var sourceIndex: Int = 0
        var position: Float = 0          // Position in source (0-1)
        var positionIncrement: Float = 1 // Playback rate
        var currentSample: Int = 0
        var grainLength: Int = 0
        var amplitude: Float = 1
        var pan: Float = 0.5             // 0 = left, 1 = right
        var pitch: Float = 1             // Pitch ratio
        var envelope: [Float] = []
        var envelopeIndex: Int = 0
        var spatialX: Float = 0          // 3D position
        var spatialY: Float = 0
        var spatialZ: Float = 0

        mutating func reset() {
            isActive = false
            currentSample = 0
            envelopeIndex = 0
        }
    }

    /// Cloud parameters for morphing
    public struct CloudParameters {
        public var position: Float = 0.5      // Source position (0-1)
        public var positionSpread: Float = 0.1
        public var density: Float = 50        // Grains per second
        public var size: Float = 50           // Grain size in ms
        public var sizeSpread: Float = 10     // Random variation
        public var pitch: Float = 1.0         // Pitch ratio
        public var pitchSpread: Float = 0.0   // Random pitch variation
        public var amplitude: Float = 1.0
        public var pan: Float = 0.5
        public var panSpread: Float = 0.0
        public var sprayAmount: Float = 0     // Temporal jitter
        public var reverse: Float = 0         // Probability of reverse grains

        public init() {}
    }

    // MARK: - Properties

    /// Sample rate
    private var sampleRate: Float = 44100

    /// Maximum grains
    private let maxGrains = 256

    /// Grain pool
    private var grains: [Grain] = []

    /// OPTIMIZATION: O(1) active grain tracking (replaces O(n) linear scan)
    private var activeGrainTracker = ActiveIndexTracker(capacity: 256)

    /// Active grain count
    private var activeGrainCount: Int = 0

    /// Grain sources (up to 4 for morphing)
    private var sources: [GrainSource] = []

    /// Current cloud parameters
    public var cloud = CloudParameters()

    /// Morphing target (for cloud interpolation)
    public var morphTarget = CloudParameters()

    /// Morphing amount (0-1)
    public var morphAmount: Float = 0

    /// Grain envelope type
    public var envelopeType: GrainEnvelope = .gaussian

    /// Scheduling mode
    public var schedulingMode: SchedulingMode = .cloud

    /// Pitch mode
    public var pitchMode: PitchMode = .original

    /// Grain scheduling timer
    private var grainTimer: Float = 0
    private var nextGrainTime: Float = 0

    /// Pre-computed envelopes
    private var envelopeCache: [[Float]] = []
    private let envelopeSizes = [64, 128, 256, 512, 1024, 2048, 4096, 8192]

    /// Random number generator
    private var rng = SystemRandomNumberGenerator()

    /// Freeze mode (stop grain position advancement)
    public var freeze: Bool = false

    /// Scrub position (manual position control)
    public var scrubPosition: Float? = nil

    /// Output buffer for stereo
    private var outputLeft: [Float] = []
    private var outputRight: [Float] = []

    /// Global volume
    public var volume: Float = 0.8

    /// Spatial mode
    public var spatialEnabled: Bool = false

    /// Listener position
    public var listenerPosition: SIMD3<Float> = .zero

    // MARK: - Initialization

    public init(sampleRate: Float = 44100) {
        self.sampleRate = sampleRate

        // Initialize grain pool
        grains = [Grain](repeating: Grain(), count: maxGrains)

        // Pre-compute envelopes
        precomputeEnvelopes()

        // Add default source
        sources.append(GrainSource.fromWaveform(.sine))
    }

    /// Pre-compute envelope tables for efficiency
    private func precomputeEnvelopes() {
        envelopeCache = []

        for size in envelopeSizes {
            var envelope = [Float](repeating: 0, count: size)

            for i in 0..<size {
                let t = Float(i) / Float(size - 1)  // 0 to 1

                switch envelopeType {
                case .gaussian:
                    // Gaussian window: e^(-0.5 * ((t-0.5)/σ)²)
                    let sigma: Float = 0.25
                    let x = (t - 0.5) / sigma
                    envelope[i] = exp(-0.5 * x * x)

                case .hanning:
                    // Hanning: 0.5 * (1 - cos(2πt))
                    envelope[i] = 0.5 * (1 - cos(2 * .pi * t))

                case .triangle:
                    envelope[i] = t < 0.5 ? 2 * t : 2 * (1 - t)

                case .trapezoid:
                    if t < 0.1 {
                        envelope[i] = t / 0.1
                    } else if t > 0.9 {
                        envelope[i] = (1 - t) / 0.1
                    } else {
                        envelope[i] = 1
                    }

                case .expodec:
                    envelope[i] = exp(-5 * t)

                case .rexpodec:
                    envelope[i] = 1 - exp(-5 * t)

                case .sinc:
                    let x = (t - 0.5) * 10
                    envelope[i] = x == 0 ? 1 : sin(.pi * x) / (.pi * x)

                case .custom:
                    envelope[i] = 0.5 * (1 - cos(2 * .pi * t))
                }
            }

            envelopeCache.append(envelope)
        }
    }

    /// Rebuild envelopes when type changes
    public func setEnvelopeType(_ type: GrainEnvelope) {
        envelopeType = type
        precomputeEnvelopes()
    }

    // MARK: - Source Management

    /// Add a grain source
    public func addSource(_ source: GrainSource) {
        guard sources.count < 4 else { return }
        sources.append(source)
    }

    /// Replace source at index
    public func setSource(_ source: GrainSource, at index: Int) {
        guard index < 4 else { return }
        while sources.count <= index {
            sources.append(GrainSource.fromWaveform(.sine))
        }
        sources[index] = source
    }

    /// Load audio file as source (stub - requires platform-specific implementation)
    public func loadAudioFile(url: URL, at index: Int) {
        // Platform-specific audio loading would go here
        // For now, create a placeholder
        let placeholder = GrainSource(
            buffer: [Float](repeating: 0, count: 44100),
            sampleRate: sampleRate,
            name: url.lastPathComponent
        )
        setSource(placeholder, at: index)
    }

    // MARK: - Grain Scheduling

    /// Calculate next grain time based on scheduling mode
    private func calculateNextGrainTime() -> Float {
        let density = interpolate(cloud.density, morphTarget.density, morphAmount)
        let baseInterval = sampleRate / max(density, 1)

        switch schedulingMode {
        case .synchronous:
            return baseInterval

        case .asynchronous:
            return baseInterval * Float.random(in: 0.5...1.5, using: &rng)

        case .quasiSync:
            let jitter = baseInterval * 0.2 * Float.random(in: -1...1, using: &rng)
            return baseInterval + jitter

        case .burst:
            // Occasional burst of grains
            if Float.random(in: 0...1, using: &rng) < 0.1 {
                return baseInterval * 0.1
            }
            return baseInterval * 2

        case .cloud:
            // Dense overlapping cloud
            return baseInterval * Float.random(in: 0.3...1.0, using: &rng)

        case .stream:
            // Continuous smooth stream
            return baseInterval * 0.5
        }
    }

    /// Spawn a new grain
    private func spawnGrain() {
        // OPTIMIZED: Find inactive grain slot using tracker
        var grainIndex: Int? = nil
        for i in 0..<maxGrains {
            if !activeGrainTracker.contains(i) {
                grainIndex = i
                break
            }
        }
        guard let grainIndex = grainIndex else { return }

        var grain = Grain()
        grain.isActive = true

        // Interpolate cloud parameters
        let position = scrubPosition ?? interpolate(cloud.position, morphTarget.position, morphAmount)
        let posSpread = interpolate(cloud.positionSpread, morphTarget.positionSpread, morphAmount)
        let size = interpolate(cloud.size, morphTarget.size, morphAmount)
        let sizeSpread = interpolate(cloud.sizeSpread, morphTarget.sizeSpread, morphAmount)
        let pitch = interpolate(cloud.pitch, morphTarget.pitch, morphAmount)
        let pitchSpread = interpolate(cloud.pitchSpread, morphTarget.pitchSpread, morphAmount)
        let amp = interpolate(cloud.amplitude, morphTarget.amplitude, morphAmount)
        let pan = interpolate(cloud.pan, morphTarget.pan, morphAmount)
        let panSpread = interpolate(cloud.panSpread, morphTarget.panSpread, morphAmount)
        let spray = interpolate(cloud.sprayAmount, morphTarget.sprayAmount, morphAmount)
        let reverse = interpolate(cloud.reverse, morphTarget.reverse, morphAmount)

        // Apply randomization
        grain.position = position + posSpread * Float.random(in: -1...1, using: &rng)
        grain.position = max(0, min(1, grain.position))

        let grainSizeMs = size + sizeSpread * Float.random(in: -1...1, using: &rng)
        grain.grainLength = Int((grainSizeMs / 1000) * sampleRate)
        grain.grainLength = max(32, min(8192, grain.grainLength))

        // Determine pitch
        var grainPitch = pitch + pitchSpread * Float.random(in: -1...1, using: &rng)

        switch pitchMode {
        case .original:
            break
        case .fixed:
            grainPitch = pitch
        case .random:
            grainPitch = Float.random(in: 0.25...4, using: &rng)
        case .chromatic:
            let semitones = round(12 * log2(grainPitch))
            grainPitch = pow(2, semitones / 12)
        case .harmonics:
            let harmonic = Float(Int.random(in: 1...8, using: &rng))
            grainPitch = harmonic
        case .formant:
            // Keep formants by adjusting grain size inversely
            grain.grainLength = Int(Float(grain.grainLength) / grainPitch)
        }

        // Reverse probability
        if Float.random(in: 0...1, using: &rng) < reverse {
            grainPitch = -abs(grainPitch)
        }

        grain.pitch = grainPitch
        grain.positionIncrement = grainPitch

        grain.amplitude = amp
        grain.pan = pan + panSpread * Float.random(in: -1...1, using: &rng)
        grain.pan = max(0, min(1, grain.pan))

        // Select source (morphing between sources)
        grain.sourceIndex = min(Int(morphAmount * Float(sources.count)), sources.count - 1)

        // Get appropriate envelope
        let envIndex = envelopeSizes.firstIndex { $0 >= grain.grainLength } ?? (envelopeSizes.count - 1)
        grain.envelope = envelopeCache[envIndex]

        // Spatial position (for 3D audio)
        if spatialEnabled {
            grain.spatialX = Float.random(in: -1...1, using: &rng)
            grain.spatialY = Float.random(in: -0.5...0.5, using: &rng)
            grain.spatialZ = Float.random(in: -1...0, using: &rng)
        }

        grains[grainIndex] = grain
        activeGrainTracker.activate(grainIndex)
        activeGrainCount = activeGrainTracker.count
    }

    // MARK: - Audio Processing

    /// Process audio buffer
    public func process(buffer: UnsafeMutablePointer<Float>, frameCount: Int) {
        // Ensure output buffers are sized correctly
        if outputLeft.count < frameCount {
            outputLeft = [Float](repeating: 0, count: frameCount)
            outputRight = [Float](repeating: 0, count: frameCount)
        }

        // Clear output
        vDSP_vclr(&outputLeft, 1, vDSP_Length(frameCount))
        vDSP_vclr(&outputRight, 1, vDSP_Length(frameCount))

        // Process each sample
        for sample in 0..<frameCount {
            // Grain scheduling
            grainTimer += 1
            if grainTimer >= nextGrainTime {
                spawnGrain()
                grainTimer = 0
                nextGrainTime = calculateNextGrainTime()
            }

            // Sum all active grains - OPTIMIZED: O(activeGrains) instead of O(maxGrains)
            var sumL: Float = 0
            var sumR: Float = 0
            var indicesToDeactivate: [Int] = []

            for i in activeGrainTracker.getActiveIndices() {
                let grainOutput = processGrain(&grains[i])

                if grainOutput.isFinished {
                    grains[i].reset()
                    indicesToDeactivate.append(i)
                } else {
                    sumL += grainOutput.left
                    sumR += grainOutput.right
                }
            }

            // Batch deactivate finished grains
            for i in indicesToDeactivate {
                activeGrainTracker.deactivate(i)
            }
            activeGrainCount = activeGrainTracker.count

            outputLeft[sample] = sumL
            outputRight[sample] = sumR
        }

        // Apply volume and write to output (mono mix for now)
        var vol = volume
        vDSP_vsmul(&outputLeft, 1, &vol, &outputLeft, 1, vDSP_Length(frameCount))
        vDSP_vsmul(&outputRight, 1, &vol, &outputRight, 1, vDSP_Length(frameCount))

        // Mix to mono output
        var half: Float = 0.5
        vDSP_vasm(&outputLeft, 1, &outputRight, 1, &half, buffer, 1, vDSP_Length(frameCount))
    }

    /// Process stereo buffer
    public func processStereo(
        left: UnsafeMutablePointer<Float>,
        right: UnsafeMutablePointer<Float>,
        frameCount: Int
    ) {
        // Ensure output buffers are sized correctly
        if outputLeft.count < frameCount {
            outputLeft = [Float](repeating: 0, count: frameCount)
            outputRight = [Float](repeating: 0, count: frameCount)
        }

        // Clear output
        vDSP_vclr(&outputLeft, 1, vDSP_Length(frameCount))
        vDSP_vclr(&outputRight, 1, vDSP_Length(frameCount))

        for sample in 0..<frameCount {
            // Grain scheduling
            grainTimer += 1
            if grainTimer >= nextGrainTime {
                spawnGrain()
                grainTimer = 0
                nextGrainTime = calculateNextGrainTime()
            }

            var sumL: Float = 0
            var sumR: Float = 0
            var indicesToDeactivate: [Int] = []

            // OPTIMIZED: Only iterate active grains
            for i in activeGrainTracker.getActiveIndices() {
                let grainOutput = processGrain(&grains[i])

                if grainOutput.isFinished {
                    grains[i].reset()
                    indicesToDeactivate.append(i)
                } else {
                    sumL += grainOutput.left
                    sumR += grainOutput.right
                }
            }

            for i in indicesToDeactivate {
                activeGrainTracker.deactivate(i)
            }
            activeGrainCount = activeGrainTracker.count

            outputLeft[sample] = sumL
            outputRight[sample] = sumR
        }

        // Apply volume using SIMD
        var vol = volume
        vDSP_vsmul(&outputLeft, 1, &vol, left, 1, vDSP_Length(frameCount))
        vDSP_vsmul(&outputRight, 1, &vol, right, 1, vDSP_Length(frameCount))
    }

    /// Process single grain and return stereo output
    private func processGrain(_ grain: inout Grain) -> (left: Float, right: Float, isFinished: Bool) {
        guard grain.currentSample < grain.grainLength else {
            return (0, 0, true)
        }

        guard grain.sourceIndex < sources.count else {
            return (0, 0, true)
        }

        let source = sources[grain.sourceIndex]
        guard !source.buffer.isEmpty else {
            return (0, 0, true)
        }

        // Calculate source position
        let sourceLength = Float(source.buffer.count)
        var readPos = grain.position * sourceLength + Float(grain.currentSample) * grain.positionIncrement

        // Handle looping/bounds
        if source.isLooping {
            while readPos < 0 {
                readPos += sourceLength
            }
            while readPos >= sourceLength {
                readPos -= sourceLength
            }
        } else {
            readPos = max(0, min(sourceLength - 1, readPos))
        }

        // Linear interpolation for sample
        let readIndex = Int(readPos)
        let frac = readPos - Float(readIndex)
        let s0 = source.buffer[readIndex]
        let s1 = source.buffer[(readIndex + 1) % source.buffer.count]
        let sample = s0 + frac * (s1 - s0)

        // Apply envelope
        let envProgress = Float(grain.currentSample) / Float(grain.grainLength)
        let envIndex = Int(envProgress * Float(grain.envelope.count - 1))
        let envelope = grain.envelope[min(envIndex, grain.envelope.count - 1)]

        let output = sample * envelope * grain.amplitude

        // Apply panning
        let panL = cos(grain.pan * .pi / 2)
        let panR = sin(grain.pan * .pi / 2)

        var left = output * panL
        var right = output * panR

        // Apply 3D spatialization if enabled
        if spatialEnabled {
            let grainPos = SIMD3<Float>(grain.spatialX, grain.spatialY, grain.spatialZ)
            let distance = simd_length(grainPos - listenerPosition)
            let attenuation = 1.0 / max(1, distance)
            left *= attenuation
            right *= attenuation

            // Simple ILD (interaural level difference)
            let azimuth = atan2(grain.spatialX, -grain.spatialZ)
            left *= 0.5 + 0.5 * cos(azimuth - .pi / 4)
            right *= 0.5 + 0.5 * cos(azimuth + .pi / 4)
        }

        grain.currentSample += 1

        return (left, right, false)
    }

    // MARK: - Utility

    /// Linear interpolation
    private func interpolate(_ a: Float, _ b: Float, _ t: Float) -> Float {
        return a + (b - a) * t
    }

    /// Get active grain count
    public var activeGrains: Int {
        return activeGrainCount
    }

    /// Reset all grains
    public func reset() {
        for i in 0..<maxGrains {
            grains[i].reset()
        }
        activeGrainTracker.clear()
        activeGrainCount = 0
        grainTimer = 0
    }

    /// Set sample rate
    public func setSampleRate(_ rate: Float) {
        sampleRate = rate
        reset()
    }
}

// MARK: - Cloud Morphing

extension GranularSynthesizer {

    /// Morph parameters for animation
    public struct CloudMorphSequence {
        public var keyframes: [CloudParameters]
        public var durations: [Float]  // Duration in seconds between keyframes
        public var currentIndex: Int = 0
        public var progress: Float = 0
        public var isLooping: Bool = true

        public init(keyframes: [CloudParameters] = [], durations: [Float] = []) {
            self.keyframes = keyframes
            self.durations = durations
        }
    }

    /// Create smooth morphing between cloud states
    public func createMorphSequence(from presets: [CloudParameters], duration: Float) -> CloudMorphSequence {
        let stepDuration = duration / Float(max(1, presets.count - 1))
        return CloudMorphSequence(
            keyframes: presets,
            durations: [Float](repeating: stepDuration, count: max(0, presets.count - 1))
        )
    }

    /// Update morph sequence (call per frame)
    public func updateMorphSequence(_ sequence: inout CloudMorphSequence, deltaTime: Float) {
        guard sequence.keyframes.count >= 2 else { return }
        guard sequence.currentIndex < sequence.keyframes.count - 1 else {
            if sequence.isLooping {
                sequence.currentIndex = 0
                sequence.progress = 0
            }
            return
        }

        let duration = sequence.durations[sequence.currentIndex]
        sequence.progress += deltaTime / duration

        if sequence.progress >= 1.0 {
            sequence.progress = 0
            sequence.currentIndex += 1

            if sequence.currentIndex >= sequence.keyframes.count - 1 {
                if sequence.isLooping {
                    sequence.currentIndex = 0
                }
            }
        }

        // Apply interpolated parameters
        let from = sequence.keyframes[sequence.currentIndex]
        let toIndex = min(sequence.currentIndex + 1, sequence.keyframes.count - 1)
        let to = sequence.keyframes[toIndex]

        cloud = from
        morphTarget = to
        morphAmount = sequence.progress
    }
}

// MARK: - Presets

extension GranularSynthesizer {

    /// Factory presets for common granular textures
    public enum GranularPreset: String, CaseIterable {
        case shimmer = "Shimmer"
        case freeze = "Time Freeze"
        case scatter = "Scatter"
        case stretch = "Time Stretch"
        case reverse = "Reverse Rain"
        case cloud = "Dense Cloud"
        case stream = "Grain Stream"
        case glitch = "Glitch"
        case ambient = "Ambient Pad"
        case rhythmic = "Rhythmic"

        public var parameters: CloudParameters {
            var p = CloudParameters()

            switch self {
            case .shimmer:
                p.density = 80
                p.size = 30
                p.sizeSpread = 20
                p.pitchSpread = 0.1
                p.panSpread = 0.8

            case .freeze:
                p.density = 100
                p.size = 80
                p.positionSpread = 0.02

            case .scatter:
                p.density = 30
                p.size = 50
                p.positionSpread = 0.5
                p.panSpread = 1.0

            case .stretch:
                p.density = 60
                p.size = 100
                p.pitch = 0.25

            case .reverse:
                p.density = 40
                p.size = 60
                p.reverse = 0.7
                p.panSpread = 0.5

            case .cloud:
                p.density = 150
                p.size = 40
                p.sizeSpread = 30
                p.positionSpread = 0.3

            case .stream:
                p.density = 25
                p.size = 200
                p.positionSpread = 0.1

            case .glitch:
                p.density = 200
                p.size = 10
                p.sizeSpread = 15
                p.pitchSpread = 0.5
                p.sprayAmount = 0.5

            case .ambient:
                p.density = 50
                p.size = 150
                p.pitch = 0.5
                p.pitchSpread = 0.05
                p.panSpread = 0.6

            case .rhythmic:
                p.density = 15
                p.size = 40
                p.positionSpread = 0.02
            }

            return p
        }
    }

    /// Apply preset
    public func applyPreset(_ preset: GranularPreset) {
        cloud = preset.parameters

        switch preset {
        case .shimmer:
            setEnvelopeType(.gaussian)
            schedulingMode = .cloud

        case .freeze:
            setEnvelopeType(.hanning)
            schedulingMode = .synchronous

        case .scatter:
            setEnvelopeType(.expodec)
            schedulingMode = .asynchronous

        case .stretch:
            setEnvelopeType(.trapezoid)
            schedulingMode = .synchronous

        case .reverse:
            setEnvelopeType(.rexpodec)
            schedulingMode = .asynchronous

        case .cloud:
            setEnvelopeType(.gaussian)
            schedulingMode = .cloud

        case .stream:
            setEnvelopeType(.trapezoid)
            schedulingMode = .stream

        case .glitch:
            setEnvelopeType(.triangle)
            schedulingMode = .burst

        case .ambient:
            setEnvelopeType(.gaussian)
            schedulingMode = .cloud

        case .rhythmic:
            setEnvelopeType(.trapezoid)
            schedulingMode = .synchronous
        }
    }
}

// MARK: - Spectral Processing

extension GranularSynthesizer {

    /// Spectral freeze - capture and loop a spectral snapshot
    public func spectralFreeze(at position: Float, duration: Float = 2.0) {
        freeze = true
        scrubPosition = position
        cloud.positionSpread = 0.01
        cloud.density = 100
        cloud.size = duration * 500  // Long grains for smooth freeze
    }

    /// Release spectral freeze
    public func releaseFreeze() {
        freeze = false
        scrubPosition = nil
    }

    /// Paulstretch-style extreme time stretching
    public func paulstretch(factor: Float) {
        // Paulstretch uses very long grains with high overlap
        cloud.size = 500 * factor
        cloud.density = 200
        cloud.positionSpread = 0.02
        cloud.pitch = 1.0 / factor
        setEnvelopeType(.gaussian)
        schedulingMode = .synchronous
    }
}

// MARK: - Analysis

extension GranularSynthesizer {

    /// Get current synthesis state for visualization
    public struct SynthState {
        public var activeGrains: Int
        public var grainPositions: [Float]
        public var grainAmplitudes: [Float]
        public var grainPans: [Float]
        public var averagePosition: Float
        public var density: Float
    }

    /// Get current state for visualization
    public func getState() -> SynthState {
        var positions: [Float] = []
        var amplitudes: [Float] = []
        var pans: [Float] = []

        for grain in grains where grain.isActive {
            positions.append(grain.position)
            amplitudes.append(grain.amplitude)
            pans.append(grain.pan)
        }

        let avgPos = positions.isEmpty ? 0 : positions.reduce(0, +) / Float(positions.count)

        return SynthState(
            activeGrains: activeGrainCount,
            grainPositions: positions,
            grainAmplitudes: amplitudes,
            grainPans: pans,
            averagePosition: avgPos,
            density: cloud.density
        )
    }
}
