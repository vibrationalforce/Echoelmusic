import Foundation
import AVFoundation
import Accelerate

// ═══════════════════════════════════════════════════════════════════════════════
// BREAKBEAT CHOPPER - JUNGLE & DNB SLICE MACHINE
// ═══════════════════════════════════════════════════════════════════════════════
//
// Classic breakbeat manipulation inspired by:
// • Akai S-series samplers (S950, S1000, S3000)
// • E-mu SP-1200, MPC workflow
// • ReCycle, Propellerhead ReBirth
// • Modern: Serato Sample, XLN XO
//
// Features:
// • Transient detection for auto-slicing
// • Slice reordering, randomization, shuffling
// • Per-slice pitch shift (classic resampling style)
// • Time stretch (granular, phase vocoder, élastique-style)
// • Roll/stutter effects
// • Reverse, half-speed, double-speed
// • Pattern sequencer with swing
// • Bio-reactive slice selection
//
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - Slice

/// A single slice of a breakbeat
struct BreakSlice: Identifiable, Equatable {
    let id: UUID
    var startSample: Int
    var endSample: Int
    var originalIndex: Int  // Position in original break

    // Per-slice parameters
    var pitch: Float = 0.0        // Semitones (-24 to +24)
    var gain: Float = 1.0         // 0-2
    var pan: Float = 0.0          // -1 (L) to +1 (R)
    var reverse: Bool = false
    var mute: Bool = false

    // Playback modifiers
    var stretchFactor: Float = 1.0  // 0.5 = half speed, 2.0 = double
    var attack: Float = 0.0         // ms
    var decay: Float = 0.0          // ms

    var lengthSamples: Int {
        return endSample - startSample
    }

    init(start: Int, end: Int, index: Int) {
        self.id = UUID()
        self.startSample = start
        self.endSample = end
        self.originalIndex = index
    }
}

// MARK: - Pattern Step

/// A step in a pattern sequence
struct PatternStep: Identifiable {
    let id: UUID
    var sliceIndex: Int?      // nil = rest/silence
    var velocity: Float       // 0-1
    var pitch: Float          // Additional pitch offset
    var reverse: Bool
    var roll: RollType?
    var probability: Float    // 0-1 (for generative patterns)

    enum RollType: String, CaseIterable {
        case none = "None"
        case r2 = "1/2"
        case r3 = "1/3"
        case r4 = "1/4"
        case r6 = "1/6"
        case r8 = "1/8"

        var divisions: Int {
            switch self {
            case .none: return 1
            case .r2: return 2
            case .r3: return 3
            case .r4: return 4
            case .r6: return 6
            case .r8: return 8
            }
        }
    }

    init(sliceIndex: Int?, velocity: Float = 1.0) {
        self.id = UUID()
        self.sliceIndex = sliceIndex
        self.velocity = velocity
        self.pitch = 0
        self.reverse = false
        self.roll = nil
        self.probability = 1.0
    }

    static func rest() -> PatternStep {
        return PatternStep(sliceIndex: nil, velocity: 0)
    }
}

// MARK: - Pattern

/// A sequence pattern for the chopper
struct ChopPattern: Identifiable {
    let id: UUID
    var name: String
    var steps: [PatternStep]
    var stepsPerBar: Int = 16
    var swing: Float = 0.0  // 0-100%
    var length: Int         // Number of steps

    init(name: String, length: Int = 16) {
        self.id = UUID()
        self.name = name
        self.length = length
        self.steps = (0..<length).map { i in
            PatternStep(sliceIndex: i % 8)  // Default: cycle through 8 slices
        }
    }

    /// Create pattern from slice indices
    static func fromIndices(_ indices: [Int?], name: String = "Custom") -> ChopPattern {
        var pattern = ChopPattern(name: name, length: indices.count)
        pattern.steps = indices.map { PatternStep(sliceIndex: $0) }
        return pattern
    }
}

// MARK: - Stretch Algorithm

enum StretchAlgorithm: String, CaseIterable {
    case resample = "Resample"           // Classic pitch-linked (Akai style)
    case repitch = "Repitch"             // Same as resample
    case granular = "Granular"           // Granular synthesis
    case phaseVocoder = "Phase Vocoder"  // FFT-based
    case elastique = "Élastique"         // High-quality (simulated)

    var description: String {
        switch self {
        case .resample: return "Classic pitch-linked stretching (SP-1200 style)"
        case .repitch: return "Pitch changes with speed"
        case .granular: return "Granular time-stretch with crossfade"
        case .phaseVocoder: return "FFT-based, preserves pitch"
        case .elastique: return "High-quality formant-preserving"
        }
    }
}

// MARK: - Shuffle Algorithms

enum ShuffleAlgorithm: String, CaseIterable {
    case random = "Random"
    case reverse = "Reverse"
    case everyOther = "Every Other"
    case pairs = "Swap Pairs"
    case thirds = "Rotate Thirds"
    case scramble = "Scramble"
    case mirror = "Mirror"
    case stutter = "Stutter"

    func apply(to indices: [Int]) -> [Int] {
        var result = indices

        switch self {
        case .random:
            result.shuffle()

        case .reverse:
            result.reverse()

        case .everyOther:
            // Swap every other pair
            for i in stride(from: 0, to: result.count - 1, by: 2) {
                result.swapAt(i, i + 1)
            }

        case .pairs:
            // Group into pairs, shuffle pairs
            var pairs: [[Int]] = []
            for i in stride(from: 0, to: result.count, by: 2) {
                if i + 1 < result.count {
                    pairs.append([result[i], result[i + 1]])
                } else {
                    pairs.append([result[i]])
                }
            }
            pairs.shuffle()
            result = pairs.flatMap { $0 }

        case .thirds:
            // Rotate in groups of 3: ABC -> BCA
            for i in stride(from: 0, to: result.count - 2, by: 3) {
                let temp = result[i]
                result[i] = result[i + 1]
                result[i + 1] = result[i + 2]
                result[i + 2] = temp
            }

        case .scramble:
            // Multiple random swaps
            for _ in 0..<result.count * 2 {
                let i = Int.random(in: 0..<result.count)
                let j = Int.random(in: 0..<result.count)
                result.swapAt(i, j)
            }

        case .mirror:
            // ABCD -> ABCDDCBA
            let mirrored = result + result.reversed()
            result = Array(mirrored.prefix(indices.count))

        case .stutter:
            // Repeat each slice: ABCD -> AABBCCDD
            var stuttered: [Int] = []
            for index in result {
                stuttered.append(index)
                stuttered.append(index)
            }
            result = Array(stuttered.prefix(indices.count))
        }

        return result
    }
}

// MARK: - Breakbeat Chopper

@MainActor
class BreakbeatChopper: ObservableObject {

    // MARK: - Published State

    /// Original audio buffer
    @Published var sourceBuffer: AVAudioPCMBuffer?

    /// Detected slices
    @Published var slices: [BreakSlice] = []

    /// Current pattern
    @Published var currentPattern: ChopPattern?

    /// All saved patterns
    @Published var patterns: [ChopPattern] = []

    /// Current playback position (step index)
    @Published var currentStep: Int = 0

    /// Is playing
    @Published var isPlaying: Bool = false

    /// Master tempo (BPM)
    @Published var tempo: Float = 170.0  // Classic jungle tempo

    /// Original break tempo (detected or set)
    @Published var originalTempo: Float = 170.0

    /// Stretch algorithm
    @Published var stretchAlgorithm: StretchAlgorithm = .resample

    /// Global pitch offset
    @Published var globalPitch: Float = 0.0  // Semitones

    /// Global swing
    @Published var globalSwing: Float = 0.0  // 0-100%

    // MARK: - Configuration

    var sampleRate: Double = 44100.0
    var sliceCount: Int { slices.count }

    // Transient detection
    var transientThreshold: Float = 0.3
    var minSliceLength: Int = 1000  // Minimum samples between slices

    // MARK: - Audio Engine

    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var playbackTimer: Timer?

    // DSP buffers
    private var granularBuffer: [Float] = []
    private var windowBuffer: [Float] = []
    private let granularWindowSize = 2048
    private let granularHopSize = 512

    // MARK: - Initialization

    init() {
        setupAudioEngine()
        createDefaultPatterns()
    }

    deinit {
        stop()
    }

    private func setupAudioEngine() {
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: nil)
        audioEngine.prepare()
    }

    private func createDefaultPatterns() {
        // Original order
        patterns.append(ChopPattern.fromIndices([0,1,2,3,4,5,6,7], name: "Original"))

        // Classic jungle chops
        patterns.append(ChopPattern.fromIndices([0,0,2,3,0,5,2,7], name: "Jungle Classic"))
        patterns.append(ChopPattern.fromIndices([0,2,0,3,4,2,6,3], name: "Think Break"))
        patterns.append(ChopPattern.fromIndices([0,1,0,1,4,5,4,5], name: "Rollin"))

        // Randomized
        var randomPattern = ChopPattern(name: "Random", length: 16)
        randomPattern.steps = (0..<16).map { _ in
            PatternStep(sliceIndex: Int.random(in: 0..<8))
        }
        patterns.append(randomPattern)

        currentPattern = patterns.first
    }

    // MARK: - Audio Loading

    /// Load audio file
    func loadAudio(from url: URL) async throws {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw ChopperError.bufferCreationFailed
        }

        try file.read(into: buffer)
        sourceBuffer = buffer
        sampleRate = format.sampleRate

        // Auto-detect slices
        detectTransients()

        // Estimate original tempo
        estimateTempo()

        log.log(.info, category: .audio, "Loaded break: \(frameCount) samples, \(slices.count) slices detected")
    }

    /// Load from AVAudioPCMBuffer directly
    func loadBuffer(_ buffer: AVAudioPCMBuffer) {
        sourceBuffer = buffer
        sampleRate = buffer.format.sampleRate
        detectTransients()
        estimateTempo()
    }

    // MARK: - Transient Detection

    /// Detect transients and create slices
    func detectTransients() {
        guard let buffer = sourceBuffer,
              let channelData = buffer.floatChannelData?[0] else { return }

        let frameCount = Int(buffer.frameLength)
        slices.removeAll()

        // Energy-based transient detection
        let windowSize = 512
        var prevEnergy: Float = 0
        var sliceStart = 0
        var sliceIndex = 0

        for i in stride(from: 0, to: frameCount - windowSize, by: windowSize / 2) {
            // Calculate window energy
            var energy: Float = 0
            for j in 0..<windowSize {
                let sample = channelData[i + j]
                energy += sample * sample
            }
            energy = sqrt(energy / Float(windowSize))

            // Detect transient (sudden increase in energy)
            let energyDiff = energy - prevEnergy
            let timeSinceLastSlice = i - sliceStart

            if energyDiff > transientThreshold && timeSinceLastSlice > minSliceLength {
                // End previous slice
                if sliceStart > 0 || sliceIndex > 0 {
                    slices.append(BreakSlice(start: sliceStart, end: i, index: sliceIndex))
                    sliceIndex += 1
                }
                sliceStart = i
            }

            prevEnergy = energy
        }

        // Add final slice
        if sliceStart < frameCount {
            slices.append(BreakSlice(start: sliceStart, end: frameCount, index: sliceIndex))
        }

        log.log(.info, category: .audio, "Detected \(slices.count) slices")
    }

    /// Manually set number of equal slices
    func sliceEvenly(count: Int) {
        guard let buffer = sourceBuffer else { return }
        let frameCount = Int(buffer.frameLength)
        let sliceLength = frameCount / count

        slices = (0..<count).map { i in
            BreakSlice(
                start: i * sliceLength,
                end: min((i + 1) * sliceLength, frameCount),
                index: i
            )
        }

        log.log(.info, category: .audio, "Created \(count) even slices")
    }

    // MARK: - Tempo Detection

    /// Estimate original tempo from slice positions
    func estimateTempo() {
        guard slices.count >= 4 else {
            originalTempo = 170.0  // Default jungle tempo
            return
        }

        // Calculate average time between kicks (assuming 4/4)
        let avgSliceLength = slices.map { $0.lengthSamples }.reduce(0, +) / slices.count
        let slicesPerSecond = sampleRate / Double(avgSliceLength)

        // Assume 8 slices per bar (common for 2-bar breaks)
        let barsPerSecond = slicesPerSecond / 8.0
        let estimatedBPM = Float(barsPerSecond * 60.0 * 4.0)

        // Snap to reasonable range
        originalTempo = max(80, min(200, estimatedBPM))
        tempo = originalTempo

        log.log(.info, category: .audio, "Estimated tempo: \(Int(originalTempo)) BPM")
    }

    // MARK: - Slice Manipulation

    /// Get audio data for a slice
    func getSliceAudio(_ slice: BreakSlice) -> [Float]? {
        guard let buffer = sourceBuffer,
              let channelData = buffer.floatChannelData?[0] else { return nil }

        let length = slice.endSample - slice.startSample
        var audio = [Float](repeating: 0, count: length)

        for i in 0..<length {
            audio[i] = channelData[slice.startSample + i]
        }

        // Apply reverse if needed
        if slice.reverse {
            audio.reverse()
        }

        return audio
    }

    /// Process slice with pitch and stretch
    func processSlice(_ slice: BreakSlice) -> [Float]? {
        guard var audio = getSliceAudio(slice) else { return nil }

        // Apply pitch shift
        let totalPitch = slice.pitch + globalPitch
        if abs(totalPitch) > 0.01 {
            audio = applyPitchShift(audio, semitones: totalPitch)
        }

        // Apply time stretch
        if abs(slice.stretchFactor - 1.0) > 0.01 {
            audio = applyTimeStretch(audio, factor: slice.stretchFactor)
        }

        // Apply gain
        if abs(slice.gain - 1.0) > 0.01 {
            vDSP_vsmul(audio, 1, [slice.gain], &audio, 1, vDSP_Length(audio.count))
        }

        return audio
    }

    // MARK: - Pitch Shifting

    /// Apply pitch shift using selected algorithm
    func applyPitchShift(_ audio: [Float], semitones: Float) -> [Float] {
        switch stretchAlgorithm {
        case .resample, .repitch:
            return resamplePitchShift(audio, semitones: semitones)
        case .granular:
            return granularPitchShift(audio, semitones: semitones)
        case .phaseVocoder, .elastique:
            return phaseVocoderPitchShift(audio, semitones: semitones)
        }
    }

    /// Classic resample-based pitch shift (changes length)
    private func resamplePitchShift(_ audio: [Float], semitones: Float) -> [Float] {
        let ratio = pow(2.0, semitones / 12.0)
        let newLength = Int(Float(audio.count) / ratio)

        guard newLength > 0 else { return audio }

        var result = [Float](repeating: 0, count: newLength)

        for i in 0..<newLength {
            let srcIndex = Float(i) * ratio
            let srcIndexInt = Int(srcIndex)
            let frac = srcIndex - Float(srcIndexInt)

            if srcIndexInt + 1 < audio.count {
                // Linear interpolation
                result[i] = audio[srcIndexInt] * (1 - frac) + audio[srcIndexInt + 1] * frac
            } else if srcIndexInt < audio.count {
                result[i] = audio[srcIndexInt]
            }
        }

        return result
    }

    /// Granular pitch shift (preserves length approximately)
    private func granularPitchShift(_ audio: [Float], semitones: Float) -> [Float] {
        let grainSize = 1024
        let hopSize = 256
        let ratio = pow(2.0, semitones / 12.0)

        var result = [Float](repeating: 0, count: audio.count)
        var window = [Float](repeating: 0, count: grainSize)

        // Hann window
        for i in 0..<grainSize {
            window[i] = 0.5 * (1.0 - cos(2.0 * Float.pi * Float(i) / Float(grainSize - 1)))
        }

        var readPos: Float = 0
        var writePos = 0

        while writePos + grainSize < audio.count {
            let readIndex = Int(readPos)

            // Extract and window grain
            for i in 0..<grainSize {
                let srcIndex = readIndex + Int(Float(i) * ratio)
                if srcIndex < audio.count {
                    result[writePos + i] += audio[srcIndex] * window[i]
                }
            }

            readPos += Float(hopSize) * ratio
            writePos += hopSize
        }

        // Normalize overlapped regions
        var envelope = [Float](repeating: 0, count: audio.count)
        writePos = 0
        while writePos + grainSize < audio.count {
            for i in 0..<grainSize {
                envelope[writePos + i] += window[i]
            }
            writePos += hopSize
        }

        for i in 0..<audio.count {
            if envelope[i] > 0.001 {
                result[i] /= envelope[i]
            }
        }

        return result
    }

    /// Phase vocoder pitch shift (FFT-based)
    private func phaseVocoderPitchShift(_ audio: [Float], semitones: Float) -> [Float] {
        // Simplified phase vocoder
        // For production, would use full STFT with phase accumulation
        let ratio = pow(2.0, semitones / 12.0)

        // Use granular as fallback with overlap-add
        return granularPitchShift(audio, semitones: semitones)
    }

    // MARK: - Time Stretching

    /// Apply time stretch using selected algorithm
    func applyTimeStretch(_ audio: [Float], factor: Float) -> [Float] {
        switch stretchAlgorithm {
        case .resample, .repitch:
            // Classic: stretching changes pitch
            return resampleStretch(audio, factor: factor)
        case .granular:
            return granularStretch(audio, factor: factor)
        case .phaseVocoder, .elastique:
            return granularStretch(audio, factor: factor)  // Use granular as approximation
        }
    }

    /// Resample stretch (pitch changes with speed)
    private func resampleStretch(_ audio: [Float], factor: Float) -> [Float] {
        let newLength = Int(Float(audio.count) * factor)
        guard newLength > 0 else { return audio }

        var result = [Float](repeating: 0, count: newLength)

        for i in 0..<newLength {
            let srcIndex = Float(i) / factor
            let srcIndexInt = Int(srcIndex)
            let frac = srcIndex - Float(srcIndexInt)

            if srcIndexInt + 1 < audio.count {
                result[i] = audio[srcIndexInt] * (1 - frac) + audio[srcIndexInt + 1] * frac
            } else if srcIndexInt < audio.count {
                result[i] = audio[srcIndexInt]
            }
        }

        return result
    }

    /// Granular time stretch (preserves pitch)
    private func granularStretch(_ audio: [Float], factor: Float) -> [Float] {
        let grainSize = 2048
        let analysisHop = 512
        let synthesisHop = Int(Float(analysisHop) * factor)

        let outputLength = Int(Float(audio.count) * factor)
        var result = [Float](repeating: 0, count: outputLength)
        var envelope = [Float](repeating: 0, count: outputLength)

        // Hann window
        var window = [Float](repeating: 0, count: grainSize)
        for i in 0..<grainSize {
            window[i] = 0.5 * (1.0 - cos(2.0 * Float.pi * Float(i) / Float(grainSize - 1)))
        }

        var readPos = 0
        var writePos = 0

        while readPos + grainSize < audio.count && writePos + grainSize < outputLength {
            // Copy and window grain
            for i in 0..<grainSize {
                let sample = audio[readPos + i] * window[i]
                result[writePos + i] += sample
                envelope[writePos + i] += window[i]
            }

            readPos += analysisHop
            writePos += synthesisHop
        }

        // Normalize
        for i in 0..<outputLength {
            if envelope[i] > 0.001 {
                result[i] /= envelope[i]
            }
        }

        return result
    }

    // MARK: - Pattern Manipulation

    /// Shuffle current pattern
    func shufflePattern(algorithm: ShuffleAlgorithm) {
        guard var pattern = currentPattern else { return }

        let indices = pattern.steps.compactMap { $0.sliceIndex }
        let shuffled = algorithm.apply(to: indices)

        for (i, step) in pattern.steps.enumerated() {
            if i < shuffled.count {
                pattern.steps[i].sliceIndex = shuffled[i]
            }
        }

        currentPattern = pattern
        log.log(.info, category: .audio, "Pattern shuffled: \(algorithm.rawValue)")
    }

    /// Randomize pattern
    func randomizePattern(density: Float = 0.8) {
        guard var pattern = currentPattern else { return }

        for i in 0..<pattern.steps.count {
            if Float.random(in: 0...1) < density {
                pattern.steps[i].sliceIndex = Int.random(in: 0..<max(1, slices.count))
                pattern.steps[i].velocity = Float.random(in: 0.6...1.0)
                pattern.steps[i].reverse = Float.random(in: 0...1) < 0.1
                pattern.steps[i].pitch = Float.random(in: -2...2).rounded()
            } else {
                pattern.steps[i] = PatternStep.rest()
            }
        }

        currentPattern = pattern
        log.log(.info, category: .audio, "Pattern randomized")
    }

    /// Create stutter/roll pattern
    func createRollPattern(sliceIndex: Int, divisions: Int, length: Int = 8) {
        var pattern = ChopPattern(name: "Roll x\(divisions)", length: length)

        for i in 0..<length {
            var step = PatternStep(sliceIndex: sliceIndex)
            step.velocity = 1.0 - Float(i % divisions) * 0.1  // Velocity roll
            pattern.steps[i] = step
        }

        currentPattern = pattern
    }

    // MARK: - Playback

    /// Start pattern playback
    func play() throws {
        guard !isPlaying else { return }

        try audioEngine.start()
        playerNode.play()
        isPlaying = true
        currentStep = 0

        // Calculate step duration from tempo
        let beatsPerSecond = tempo / 60.0
        let stepsPerBeat = 4.0  // 16th notes
        let stepDuration = 1.0 / (beatsPerSecond * Float(stepsPerBeat))

        // Start playback timer
        playbackTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(stepDuration), repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.playNextStep()
            }
        }

        log.log(.info, category: .audio, "Chopper playing @ \(Int(tempo)) BPM")
    }

    /// Stop playback
    func stop() {
        playbackTimer?.invalidate()
        playbackTimer = nil
        playerNode.stop()
        isPlaying = false
        currentStep = 0
        log.log(.info, category: .audio, "Chopper stopped")
    }

    /// Play next step in pattern
    private func playNextStep() {
        guard let pattern = currentPattern,
              currentStep < pattern.steps.count else {
            currentStep = 0
            return
        }

        let step = pattern.steps[currentStep]

        // Check probability
        if Float.random(in: 0...1) > step.probability {
            currentStep = (currentStep + 1) % pattern.length
            return
        }

        // Play slice if not rest
        if let sliceIndex = step.sliceIndex,
           sliceIndex < slices.count {
            var slice = slices[sliceIndex]

            // Apply step modifiers
            slice.reverse = step.reverse
            slice.pitch += step.pitch
            slice.gain = step.velocity

            playSlice(slice, roll: step.roll)
        }

        currentStep = (currentStep + 1) % pattern.length
    }

    /// Play a single slice
    func playSlice(_ slice: BreakSlice, roll: PatternStep.RollType? = nil) {
        guard let audio = processSlice(slice),
              let format = sourceBuffer?.format else { return }

        // Handle roll/stutter
        let divisions = roll?.divisions ?? 1
        let rollLength = audio.count / divisions

        for d in 0..<divisions {
            let startOffset = d * rollLength

            // Create buffer for this roll segment
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(rollLength)) else { continue }
            buffer.frameLength = AVAudioFrameCount(rollLength)

            if let bufferData = buffer.floatChannelData?[0] {
                for i in 0..<rollLength {
                    let srcIndex = startOffset + i
                    bufferData[i] = srcIndex < audio.count ? audio[srcIndex] : 0
                }
            }

            // Schedule with delay for roll effect
            let rollDelay = Double(d) * Double(rollLength) / sampleRate
            let scheduleTime = AVAudioTime(sampleTime: playerNode.lastRenderTime?.sampleTime ?? 0 + Int64(rollDelay * sampleRate), atRate: sampleRate)

            playerNode.scheduleBuffer(buffer, at: scheduleTime)
        }
    }

    // MARK: - Export

    /// Render pattern to audio buffer
    func renderPattern(_ pattern: ChopPattern? = nil) -> AVAudioPCMBuffer? {
        guard let sourceFormat = sourceBuffer?.format else { return nil }

        let patternToRender = pattern ?? currentPattern
        guard let p = patternToRender else { return nil }

        // Calculate total length
        let beatsPerSecond = tempo / 60.0
        let stepsPerBeat: Float = 4.0
        let stepDuration = 1.0 / (beatsPerSecond * stepsPerBeat)
        let totalDuration = stepDuration * Float(p.length)
        let totalSamples = Int(Double(totalDuration) * sampleRate)

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: AVAudioFrameCount(totalSamples)) else {
            return nil
        }
        outputBuffer.frameLength = AVAudioFrameCount(totalSamples)

        guard let outputData = outputBuffer.floatChannelData?[0] else { return nil }

        // Clear buffer
        memset(outputData, 0, totalSamples * MemoryLayout<Float>.size)

        // Render each step
        for (stepIndex, step) in p.steps.enumerated() {
            guard let sliceIndex = step.sliceIndex,
                  sliceIndex < slices.count else { continue }

            var slice = slices[sliceIndex]
            slice.reverse = step.reverse
            slice.pitch += step.pitch
            slice.gain = step.velocity

            guard let sliceAudio = processSlice(slice) else { continue }

            let startSample = Int(Float(stepIndex) * stepDuration * Float(sampleRate))

            // Apply swing
            let swingOffset = (stepIndex % 2 == 1) ? Int(p.swing / 100.0 * stepDuration * Float(sampleRate) * 0.5) : 0
            let writeStart = startSample + swingOffset

            // Copy slice audio
            for i in 0..<sliceAudio.count {
                let writeIndex = writeStart + i
                if writeIndex < totalSamples {
                    outputData[writeIndex] += sliceAudio[i]
                }
            }
        }

        return outputBuffer
    }

    // MARK: - Bio-Reactive

    /// Update slice selection based on bio-signal
    func reactToBio(_ signal: BioSignal) {
        guard var pattern = currentPattern else { return }

        // High coherence = more structured patterns
        if signal.coherence > 70 {
            // Use original order slices
            for i in 0..<pattern.steps.count {
                pattern.steps[i].sliceIndex = i % slices.count
            }
        } else if signal.coherence < 30 {
            // More chaotic - randomize some steps
            for i in 0..<pattern.steps.count {
                if Float.random(in: 0...1) < 0.3 {
                    pattern.steps[i].sliceIndex = Int.random(in: 0..<max(1, slices.count))
                }
            }
        }

        // Energy affects velocity
        let energyFactor = 0.7 + signal.energy * 0.3
        for i in 0..<pattern.steps.count {
            pattern.steps[i].velocity *= energyFactor
        }

        currentPattern = pattern
    }

    // MARK: - Export to EchoelSampler

    /// Export all slices into an EchoelSampler as individual zones
    /// Each slice becomes a zone mapped to sequential MIDI notes starting at `startNote`
    func exportSlicesToSampler(_ sampler: EchoelSampler, startNote: Int = 36) -> Int {
        var loadedCount = 0
        for (index, slice) in slices.enumerated() {
            guard let audio = processSlice(slice) else { continue }

            let note = startNote + index
            guard note <= 127 else { break }

            var zone = SampleZone(name: "Slice_\(index)", rootNote: note)
            zone.sampleData = audio
            zone.sampleRate = Float(sampleRate)
            zone.keyRangeLow = note
            zone.keyRangeHigh = note
            zone.loopEnd = audio.count
            sampler.addZone(zone)
            loadedCount += 1
        }
        return loadedCount
    }

    /// Export current pattern as a single rendered zone in the sampler
    /// The full pattern render becomes one playable sample
    func exportPatternToSampler(_ sampler: EchoelSampler, rootNote: Int = 60, name: String? = nil) -> Int? {
        guard let patternBuffer = renderPattern() else { return nil }
        guard let channelData = patternBuffer.floatChannelData?[0] else { return nil }

        let length = Int(patternBuffer.frameLength)
        let data = Array(UnsafeBufferPointer(start: channelData, count: length))

        let zoneName = name ?? "Pattern_\(currentPattern?.name ?? "unknown")"
        var zone = SampleZone(name: zoneName, rootNote: rootNote)
        zone.sampleData = data
        zone.sampleRate = Float(sampleRate)
        zone.loopEnabled = true
        zone.loopStart = 0
        zone.loopEnd = data.count
        sampler.addZone(zone)
        return sampler.zones.count - 1
    }

    // MARK: - Errors

    enum ChopperError: Error, LocalizedError {
        case bufferCreationFailed
        case noSourceLoaded
        case invalidSliceIndex

        var errorDescription: String? {
            switch self {
            case .bufferCreationFailed: return "Failed to create audio buffer"
            case .noSourceLoaded: return "No source audio loaded"
            case .invalidSliceIndex: return "Invalid slice index"
            }
        }
    }
}

// MARK: - Classic Break Presets

extension BreakbeatChopper {

    /// Classic jungle/DnB pattern presets
    static let classicPatterns: [(name: String, indices: [Int?])] = [
        ("Think", [0, 2, nil, 3, 0, 2, nil, 7]),
        ("Funky", [0, nil, 2, nil, 4, nil, 6, nil, 0, nil, 2, nil, 4, 6, nil, 7]),
        ("Roller", [0, 0, 2, 0, 0, 2, 0, 0, 4, 4, 6, 4, 4, 6, 4, 7]),
        ("Choppy", [0, 1, 0, 2, 0, 3, 0, 4, 0, 5, 0, 6, 0, 7, 0, 0]),
        ("Reverse", [7, 6, 5, 4, 3, 2, 1, 0]),
        ("Half-Time", [0, nil, nil, nil, 2, nil, nil, nil, 4, nil, nil, nil, 6, nil, nil, nil]),
        ("Offbeat", [nil, 1, nil, 3, nil, 5, nil, 7, nil, 1, nil, 3, nil, 5, nil, 7]),
        ("Build", [0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 2, 1, 0, 1, 2, 3])
    ]

    func loadClassicPattern(_ index: Int) {
        guard index < Self.classicPatterns.count else { return }
        let preset = Self.classicPatterns[index]
        currentPattern = ChopPattern.fromIndices(preset.indices, name: preset.name)
    }
}
