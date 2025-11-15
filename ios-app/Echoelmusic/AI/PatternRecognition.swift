import Foundation
import AVFoundation
import Accelerate

// MARK: - Pattern Recognition Engine
/// AI-powered pattern recognition for music analysis
/// Phase 6.1: Chord Detection, Key/Scale Detection, Beat Detection
class PatternRecognition: ObservableObject {

    // MARK: - Published Properties
    @Published var detectedChord: Chord?
    @Published var detectedKey: Key?
    @Published var detectedScale: Scale?
    @Published var detectedTempo: Double = 120.0
    @Published var confidence: Float = 0.0

    // MARK: - Audio Analysis
    private let fftSize = 4096
    private var fftSetup: vDSP_DFT_Setup?

    init() {
        setupFFT()
    }

    deinit {
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }

    // MARK: - FFT Setup
    private func setupFFT() {
        fftSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            vDSP_Length(fftSize),
            vDSP_DFT_Direction.FORWARD
        )
    }

    // MARK: - Chord Detection
    /// Detects chord from audio buffer using chromagram analysis
    func detectChord(from buffer: AVAudioPCMBuffer) -> Chord? {
        guard let floatData = buffer.floatChannelData?[0] else { return nil }
        let frameCount = Int(buffer.frameLength)

        // 1. Calculate chromagram (12-bin pitch class profile)
        let chromagram = calculateChromagram(samples: floatData, count: frameCount)

        // 2. Find active notes (peaks in chromagram)
        let activeNotes = findActiveNotes(chromagram: chromagram, threshold: 0.3)

        // 3. Match to known chord templates
        let chord = matchChordTemplate(activeNotes: activeNotes)

        // Update published property
        DispatchQueue.main.async {
            self.detectedChord = chord
            self.confidence = chord?.confidence ?? 0.0
        }

        return chord
    }

    /// Calculates chromagram (pitch class profile) from audio samples
    private func calculateChromagram(samples: UnsafeMutablePointer<Float>, count: Int) -> [Float] {
        var chromagram = [Float](repeating: 0.0, count: 12)

        // Perform FFT
        guard let setup = fftSetup else { return chromagram }

        var realPart = [Float](repeating: 0.0, count: fftSize)
        var imagPart = [Float](repeating: 0.0, count: fftSize)

        // Copy samples to real part (zero-pad if needed)
        let copyCount = min(count, fftSize)
        for i in 0..<copyCount {
            realPart[i] = samples[i]
        }

        // Apply Hann window
        var window = [Float](repeating: 0.0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        vDSP_vmul(realPart, 1, window, 1, &realPart, 1, vDSP_Length(fftSize))

        // Perform DFT
        realPart.withUnsafeMutableBufferPointer { realPtr in
            imagPart.withUnsafeMutableBufferPointer { imagPtr in
                vDSP_DFT_Execute(setup, realPtr.baseAddress!, imagPtr.baseAddress!, realPtr.baseAddress!, imagPtr.baseAddress!)
            }
        }

        // Calculate magnitude spectrum
        var magnitudes = [Float](repeating: 0.0, count: fftSize / 2)
        var complexSplit = DSPSplitComplex(realp: &realPart, imagp: &imagPart)
        vDSP_zvabs(&complexSplit, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))

        // Map frequencies to pitch classes (C, C#, D, ... B)
        let sampleRate: Float = 44100.0
        let freqResolution = sampleRate / Float(fftSize)

        for bin in 0..<(fftSize / 2) {
            let frequency = Float(bin) * freqResolution
            if frequency < 50 || frequency > 4000 { continue } // Focus on musical range

            // Convert frequency to MIDI note
            let midiNote = 12.0 * log2(frequency / 440.0) + 69.0
            let pitchClass = Int(midiNote.rounded()) % 12

            if pitchClass >= 0 && pitchClass < 12 {
                chromagram[pitchClass] += magnitudes[bin]
            }
        }

        // Normalize chromagram
        var maxValue: Float = 0.0
        vDSP_maxv(chromagram, 1, &maxValue, vDSP_Length(12))
        if maxValue > 0 {
            var normalizedChromagram = chromagram
            vDSP_vsdiv(chromagram, 1, &maxValue, &normalizedChromagram, 1, vDSP_Length(12))
            return normalizedChromagram
        }

        return chromagram
    }

    /// Finds active notes from chromagram
    private func findActiveNotes(chromagram: [Float], threshold: Float) -> Set<PitchClass> {
        var activeNotes = Set<PitchClass>()

        for (index, strength) in chromagram.enumerated() {
            if strength >= threshold {
                if let pitchClass = PitchClass(rawValue: index) {
                    activeNotes.insert(pitchClass)
                }
            }
        }

        return activeNotes
    }

    /// Matches active notes to known chord templates
    private func matchChordTemplate(activeNotes: Set<PitchClass>) -> Chord? {
        guard !activeNotes.isEmpty else { return nil }

        var bestMatch: Chord?
        var bestScore: Float = 0.0

        // Try all possible root notes
        for root in PitchClass.allCases {
            // Try different chord types
            for chordType in ChordType.allCases {
                let template = chordType.pitchClasses(root: root)
                let score = calculateTemplateMatch(activeNotes: activeNotes, template: template)

                if score > bestScore {
                    bestScore = score
                    bestMatch = Chord(root: root, type: chordType, confidence: score)
                }
            }
        }

        return bestMatch
    }

    /// Calculates how well active notes match a chord template
    private func calculateTemplateMatch(activeNotes: Set<PitchClass>, template: Set<PitchClass>) -> Float {
        let intersection = activeNotes.intersection(template)
        let union = activeNotes.union(template)

        if union.isEmpty { return 0.0 }

        // Jaccard similarity
        return Float(intersection.count) / Float(union.count)
    }

    // MARK: - Key Detection
    /// Detects musical key using Krumhansl-Schmuckler algorithm
    func detectKey(from buffer: AVAudioPCMBuffer) -> Key? {
        guard let floatData = buffer.floatChannelData?[0] else { return nil }
        let frameCount = Int(buffer.frameLength)

        // Calculate chromagram
        let chromagram = calculateChromagram(samples: floatData, count: frameCount)

        // Correlate with major/minor key profiles
        var bestKey: Key?
        var bestCorrelation: Float = -1.0

        for tonic in PitchClass.allCases {
            // Try major
            let majorCorr = correlateWithKeyProfile(chromagram: chromagram, tonic: tonic, mode: .major)
            if majorCorr > bestCorrelation {
                bestCorrelation = majorCorr
                bestKey = Key(tonic: tonic, mode: .major)
            }

            // Try minor
            let minorCorr = correlateWithKeyProfile(chromagram: chromagram, tonic: tonic, mode: .minor)
            if minorCorr > bestCorrelation {
                bestCorrelation = minorCorr
                bestKey = Key(tonic: tonic, mode: .minor)
            }
        }

        // Update published property
        DispatchQueue.main.async {
            self.detectedKey = bestKey
        }

        return bestKey
    }

    /// Correlates chromagram with key profile (Krumhansl-Schmuckler weights)
    private func correlateWithKeyProfile(chromagram: [Float], tonic: PitchClass, mode: KeyMode) -> Float {
        let profile: [Float]

        switch mode {
        case .major:
            // Krumhansl-Schmuckler major profile
            profile = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88]
        case .minor:
            // Krumhansl-Schmuckler minor profile
            profile = [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17]
        }

        // Rotate profile to match tonic
        let rotatedProfile = rotateArray(profile, by: tonic.rawValue)

        // Calculate Pearson correlation
        return pearsonCorrelation(x: chromagram, y: rotatedProfile)
    }

    /// Rotates array by n positions
    private func rotateArray<T>(_ array: [T], by n: Int) -> [T] {
        guard !array.isEmpty else { return array }
        let rotation = ((n % array.count) + array.count) % array.count
        return Array(array[rotation...] + array[..<rotation])
    }

    /// Calculates Pearson correlation coefficient
    private func pearsonCorrelation(x: [Float], y: [Float]) -> Float {
        guard x.count == y.count, !x.isEmpty else { return 0.0 }

        let n = Float(x.count)

        // Calculate means
        var meanX: Float = 0.0
        var meanY: Float = 0.0
        vDSP_meanv(x, 1, &meanX, vDSP_Length(x.count))
        vDSP_meanv(y, 1, &meanY, vDSP_Length(y.count))

        // Calculate covariance and standard deviations
        var sumXY: Float = 0.0
        var sumX2: Float = 0.0
        var sumY2: Float = 0.0

        for i in 0..<x.count {
            let dx = x[i] - meanX
            let dy = y[i] - meanY
            sumXY += dx * dy
            sumX2 += dx * dx
            sumY2 += dy * dy
        }

        let denominator = sqrt(sumX2 * sumY2)
        if denominator == 0 { return 0.0 }

        return sumXY / denominator
    }

    // MARK: - Tempo Detection
    /// Detects tempo using onset detection and autocorrelation
    func detectTempo(from buffer: AVAudioPCMBuffer) -> Double {
        guard let floatData = buffer.floatChannelData?[0] else { return 120.0 }
        let frameCount = Int(buffer.frameLength)
        let sampleRate = buffer.format.sampleRate

        // 1. Detect onsets (beats)
        let onsets = detectOnsets(samples: floatData, count: frameCount, sampleRate: sampleRate)

        // 2. Calculate inter-onset intervals (IOIs)
        var intervals: [Double] = []
        for i in 1..<onsets.count {
            let interval = Double(onsets[i] - onsets[i-1]) / sampleRate
            intervals.append(interval)
        }

        // 3. Find most common interval (using histogram)
        guard !intervals.isEmpty else { return 120.0 }

        let medianInterval = intervals.sorted()[intervals.count / 2]
        let tempo = 60.0 / medianInterval // BPM

        // Constrain to reasonable range (60-200 BPM)
        let constrainedTempo = max(60.0, min(200.0, tempo))

        // Update published property
        DispatchQueue.main.async {
            self.detectedTempo = constrainedTempo
        }

        return constrainedTempo
    }

    /// Detects onsets using spectral flux
    private func detectOnsets(samples: UnsafeMutablePointer<Float>, count: Int, sampleRate: Double) -> [Int] {
        var onsets: [Int] = []

        let hopSize = 512
        let numFrames = count / hopSize

        var prevMagnitudes = [Float](repeating: 0.0, count: fftSize / 2)
        var spectralFlux: [Float] = []

        for frame in 0..<numFrames {
            let startSample = frame * hopSize
            let endSample = min(startSample + fftSize, count)

            // Get magnitude spectrum for this frame
            // (reuse chromagram calculation but without pitch class mapping)
            let magnitudes = calculateMagnitudeSpectrum(samples: samples + startSample, count: endSample - startSample)

            // Calculate spectral flux (difference from previous frame)
            var flux: Float = 0.0
            for i in 0..<min(magnitudes.count, prevMagnitudes.count) {
                let diff = max(0, magnitudes[i] - prevMagnitudes[i])
                flux += diff
            }
            spectralFlux.append(flux)

            prevMagnitudes = magnitudes
        }

        // Find peaks in spectral flux
        let threshold = calculateThreshold(values: spectralFlux)

        for (index, flux) in spectralFlux.enumerated() {
            if flux > threshold {
                // Check if it's a local maximum
                let isLocalMax = (index == 0 || flux > spectralFlux[index - 1]) &&
                                (index == spectralFlux.count - 1 || flux > spectralFlux[index + 1])

                if isLocalMax {
                    let samplePosition = index * hopSize
                    onsets.append(samplePosition)
                }
            }
        }

        return onsets
    }

    /// Calculates magnitude spectrum
    private func calculateMagnitudeSpectrum(samples: UnsafeMutablePointer<Float>, count: Int) -> [Float] {
        guard let setup = fftSetup else { return [] }

        var realPart = [Float](repeating: 0.0, count: fftSize)
        var imagPart = [Float](repeating: 0.0, count: fftSize)

        // Copy and window
        let copyCount = min(count, fftSize)
        for i in 0..<copyCount {
            realPart[i] = samples[i]
        }

        var window = [Float](repeating: 0.0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        vDSP_vmul(realPart, 1, window, 1, &realPart, 1, vDSP_Length(fftSize))

        // FFT
        realPart.withUnsafeMutableBufferPointer { realPtr in
            imagPart.withUnsafeMutableBufferPointer { imagPtr in
                vDSP_DFT_Execute(setup, realPtr.baseAddress!, imagPtr.baseAddress!, realPtr.baseAddress!, imagPtr.baseAddress!)
            }
        }

        // Magnitude
        var magnitudes = [Float](repeating: 0.0, count: fftSize / 2)
        var complexSplit = DSPSplitComplex(realp: &realPart, imagp: &imagPart)
        vDSP_zvabs(&complexSplit, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))

        return magnitudes
    }

    /// Calculates adaptive threshold (mean + 1.5 * std dev)
    private func calculateThreshold(values: [Float]) -> Float {
        guard !values.isEmpty else { return 0.0 }

        var mean: Float = 0.0
        vDSP_meanv(values, 1, &mean, vDSP_Length(values.count))

        // Calculate standard deviation
        var deviations = values.map { $0 - mean }
        var squaredDeviations = [Float](repeating: 0.0, count: deviations.count)
        vDSP_vsq(deviations, 1, &squaredDeviations, 1, vDSP_Length(deviations.count))

        var variance: Float = 0.0
        vDSP_meanv(squaredDeviations, 1, &variance, vDSP_Length(squaredDeviations.count))

        let stdDev = sqrt(variance)

        return mean + 1.5 * stdDev
    }

    // MARK: - Scale Detection
    /// Detects scale from detected key
    func detectScale() -> Scale? {
        guard let key = detectedKey else { return nil }

        // Common scales for each mode
        let scale: Scale
        switch key.mode {
        case .major:
            scale = Scale(root: key.tonic, type: .major)
        case .minor:
            scale = Scale(root: key.tonic, type: .naturalMinor)
        }

        DispatchQueue.main.async {
            self.detectedScale = scale
        }

        return scale
    }
}

// MARK: - Supporting Types

enum PitchClass: Int, CaseIterable {
    case C = 0, CSharp, D, DSharp, E, F, FSharp, G, GSharp, A, ASharp, B

    var name: String {
        switch self {
        case .C: return "C"
        case .CSharp: return "C#"
        case .D: return "D"
        case .DSharp: return "D#"
        case .E: return "E"
        case .F: return "F"
        case .FSharp: return "F#"
        case .G: return "G"
        case .GSharp: return "G#"
        case .A: return "A"
        case .ASharp: return "A#"
        case .B: return "B"
        }
    }
}

enum ChordType: String, CaseIterable {
    case major, minor, diminished, augmented
    case major7, minor7, dominant7, diminished7
    case major6, minor6
    case sus2, sus4

    func pitchClasses(root: PitchClass) -> Set<PitchClass> {
        let r = root.rawValue
        var intervals: [Int] = []

        switch self {
        case .major:        intervals = [0, 4, 7]
        case .minor:        intervals = [0, 3, 7]
        case .diminished:   intervals = [0, 3, 6]
        case .augmented:    intervals = [0, 4, 8]
        case .major7:       intervals = [0, 4, 7, 11]
        case .minor7:       intervals = [0, 3, 7, 10]
        case .dominant7:    intervals = [0, 4, 7, 10]
        case .diminished7:  intervals = [0, 3, 6, 9]
        case .major6:       intervals = [0, 4, 7, 9]
        case .minor6:       intervals = [0, 3, 7, 9]
        case .sus2:         intervals = [0, 2, 7]
        case .sus4:         intervals = [0, 5, 7]
        }

        return Set(intervals.compactMap { PitchClass(rawValue: (r + $0) % 12) })
    }
}

struct Chord: Equatable {
    let root: PitchClass
    let type: ChordType
    let confidence: Float

    var name: String {
        "\(root.name)\(type.rawValue)"
    }
}

enum KeyMode: String {
    case major, minor
}

struct Key: Equatable {
    let tonic: PitchClass
    let mode: KeyMode

    var name: String {
        "\(tonic.name) \(mode.rawValue)"
    }
}

enum ScaleType: String {
    case major, naturalMinor, harmonicMinor, melodicMinor
    case dorian, phrygian, lydian, mixolydian, aeolian, locrian
    case pentatonicMajor, pentatonicMinor
    case blues, chromatic, wholeTone
}

struct Scale {
    let root: PitchClass
    let type: ScaleType

    var name: String {
        "\(root.name) \(type.rawValue)"
    }

    var intervals: [Int] {
        switch type {
        case .major:            return [0, 2, 4, 5, 7, 9, 11]
        case .naturalMinor:     return [0, 2, 3, 5, 7, 8, 10]
        case .harmonicMinor:    return [0, 2, 3, 5, 7, 8, 11]
        case .melodicMinor:     return [0, 2, 3, 5, 7, 9, 11]
        case .dorian:           return [0, 2, 3, 5, 7, 9, 10]
        case .phrygian:         return [0, 1, 3, 5, 7, 8, 10]
        case .lydian:           return [0, 2, 4, 6, 7, 9, 11]
        case .mixolydian:       return [0, 2, 4, 5, 7, 9, 10]
        case .aeolian:          return [0, 2, 3, 5, 7, 8, 10]
        case .locrian:          return [0, 1, 3, 5, 6, 8, 10]
        case .pentatonicMajor:  return [0, 2, 4, 7, 9]
        case .pentatonicMinor:  return [0, 3, 5, 7, 10]
        case .blues:            return [0, 3, 5, 6, 7, 10]
        case .chromatic:        return [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
        case .wholeTone:        return [0, 2, 4, 6, 8, 10]
        }
    }

    var pitchClasses: Set<PitchClass> {
        Set(intervals.compactMap { PitchClass(rawValue: (root.rawValue + $0) % 12) })
    }
}
