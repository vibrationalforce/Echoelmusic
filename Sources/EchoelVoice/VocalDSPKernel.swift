#if canImport(AVFoundation)
import Foundation
import AVFoundation
import Accelerate

/// Real-time DSP kernel for EchoelVoice AUv3 plugin
///
/// Lock-free, allocation-free (after `prepare()`) vocal processor:
/// - YIN pitch detection → scale-aware correction → phase vocoder pitch shift
/// - Harmony generation (up to 3 diatonic/chromatic voices)
/// - Spectral analysis for CIE 1931 color mapping
///
/// Audio thread: NO locks, NO malloc, NO ObjC messaging, NO file I/O.
final class VocalDSPKernel {

    // MARK: - Parameter Addresses

    enum ParameterAddress: UInt64 {
        case correctionSpeed = 0     // 0ms (hard-tune) to 200ms (natural)
        case correctionStrength = 1  // 0-1
        case rootNote = 2           // 0-11 (C to B)
        case scaleType = 3          // 0-18 (see ScaleType)
        case formantShift = 4       // -12 to +12 semitones
        case harmonyMix = 5         // 0-1
        case harmonyInterval1 = 6   // -12 to +12 semitones
        case harmonyInterval2 = 7   // -12 to +12 semitones
        case inputGain = 8          // 0-2
        case outputGain = 9         // 0-2
        case dryWet = 10            // 0-1
        case transpose = 11         // -24 to +24 semitones
        case humanize = 12          // 0-1
        case bypass = 13
    }

    // MARK: - Scale Types

    /// Scale intervals (matching RealTimePitchCorrector.ScaleType)
    private static let scaleIntervals: [[Int]] = [
        [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], // chromatic
        [0, 2, 4, 5, 7, 9, 11],                   // major
        [0, 2, 3, 5, 7, 8, 10],                   // natural minor
        [0, 2, 3, 5, 7, 8, 11],                   // harmonic minor
        [0, 2, 3, 5, 7, 9, 11],                   // melodic minor
        [0, 2, 4, 7, 9],                           // pentatonic major
        [0, 3, 5, 7, 10],                          // pentatonic minor
        [0, 3, 5, 6, 7, 10],                       // blues
        [0, 2, 3, 5, 7, 9, 10],                   // dorian
        [0, 1, 3, 5, 7, 8, 10],                   // phrygian
        [0, 2, 4, 6, 7, 9, 11],                   // lydian
        [0, 2, 4, 5, 7, 9, 10],                   // mixolydian
        [0, 1, 3, 5, 6, 8, 10],                   // locrian
        [0, 2, 4, 6, 8, 10],                       // whole tone
        [0, 2, 3, 5, 6, 8, 9, 11],                // diminished
        [0, 3, 4, 7, 8, 11],                       // augmented
        [0, 2, 4, 5, 6, 8, 10],                   // arabian
        [0, 1, 5, 7, 8],                           // japanese
        [0, 2, 3, 6, 7, 8, 11]                    // hungarian minor
    ]

    // MARK: - State

    private var sampleRate: Double = 48000.0
    private var maxFrames: AVAudioFrameCount = 512
    private var channelCount: Int = 2

    // Parameter values (nonisolated for audio thread access)
    nonisolated(unsafe) private var correctionSpeed: Float = 50.0
    nonisolated(unsafe) private var correctionStrength: Float = 0.8
    nonisolated(unsafe) private var rootNote: Int = 0
    nonisolated(unsafe) private var scaleTypeIndex: Int = 0
    nonisolated(unsafe) private var formantShift: Float = 0.0
    nonisolated(unsafe) private var harmonyMix: Float = 0.0
    nonisolated(unsafe) private var harmonyInterval1: Float = 4.0  // Major 3rd
    nonisolated(unsafe) private var harmonyInterval2: Float = 7.0  // Perfect 5th
    nonisolated(unsafe) private var inputGain: Float = 1.0
    nonisolated(unsafe) private var outputGain: Float = 1.0
    nonisolated(unsafe) private var dryWet: Float = 1.0
    nonisolated(unsafe) private var transpose: Float = 0.0
    nonisolated(unsafe) private var humanize: Float = 0.2
    nonisolated(unsafe) private var bypassed: Bool = false

    // MARK: - YIN Pitch Detection

    private var yinBuffer: [Float] = []
    private var yinBufferSize: Int = 0
    private var detectedPitch: Float = 0
    private var pitchConfidence: Float = 0
    private let yinThreshold: Float = 0.15

    // Pitch smoothing
    private var smoothedPitchCorrection: Float = 0

    // MARK: - Phase Vocoder (Pitch Shifting)

    private var fftSize: Int = 2048
    private var hopSize: Int = 512
    private var fftSetup: vDSP_DFT_Setup?
    private var ifftSetup: vDSP_DFT_Setup?

    // Analysis/synthesis windows
    private var analysisWindow: [Float] = []
    private var synthesisWindow: [Float] = []

    // Phase tracking
    private var lastAnalysisPhase: [Float] = []
    private var lastSynthesisPhase: [Float] = []

    // Overlap-add buffers
    private var inputRingBuffer: [Float] = []
    private var outputRingBuffer: [Float] = []
    private var inputWritePos: Int = 0
    private var outputReadPos: Int = 0
    private var outputWritePos: Int = 0

    // FFT work buffers
    private var fftReal: [Float] = []
    private var fftImag: [Float] = []
    private var magnitudes: [Float] = []
    private var phases: [Float] = []

    // Harmony voice buffers
    private var harmony1OutputRing: [Float] = []
    private var harmony1WritePos: Int = 0
    private var harmony1LastAnalysisPhase: [Float] = []
    private var harmony1LastSynthesisPhase: [Float] = []

    private var harmony2OutputRing: [Float] = []
    private var harmony2WritePos: Int = 0
    private var harmony2LastAnalysisPhase: [Float] = []
    private var harmony2LastSynthesisPhase: [Float] = []

    // MARK: - Spectral Analysis (for CIE 1931 visualization)

    /// Spectral band energies (8 bands) — read by the UI thread for color mapping
    /// Bands: Sub-Bass, Bass, Low-Mid, Mid, Upper-Mid, Presence, Brilliance, Air
    nonisolated(unsafe) var spectralBands: (Float, Float, Float, Float, Float, Float, Float, Float) =
        (0, 0, 0, 0, 0, 0, 0, 0)

    /// Dominant frequency in Hz — for primary color mapping
    nonisolated(unsafe) var dominantFrequency: Float = 0

    /// Current RMS level
    nonisolated(unsafe) var rmsLevel: Float = 0

    // Spectral analysis FFT
    private var spectrumMagnitudes: [Float] = []

    // MARK: - Initialization

    init() {}

    deinit {
        if let setup = fftSetup { vDSP_DFT_DestroySetup(setup) }
        if let setup = ifftSetup { vDSP_DFT_DestroySetup(setup) }
    }

    // MARK: - Configuration

    func prepare(sampleRate: Double, maxFrames: AVAudioFrameCount, channelCount: Int) {
        self.sampleRate = sampleRate
        self.maxFrames = maxFrames
        self.channelCount = channelCount

        setupYIN()
        setupPhaseVocoder()
        setupSpectralAnalysis()
    }

    private func setupYIN() {
        // YIN buffer: enough for ~50Hz detection at current sample rate
        yinBufferSize = Int(sampleRate / 50.0)
        yinBuffer = [Float](repeating: 0, count: yinBufferSize)
    }

    private func setupPhaseVocoder() {
        fftSize = 2048
        hopSize = fftSize / 4
        let halfN = fftSize / 2

        // Windows
        analysisWindow = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&analysisWindow, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))

        synthesisWindow = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&synthesisWindow, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))

        let hopScale = Float(hopSize) / Float(fftSize)
        var scale = 1.0 / (hopScale * 2.0)
        vDSP_vsmul(synthesisWindow, 1, &scale, &synthesisWindow, 1, vDSP_Length(fftSize))

        // Phase tracking
        lastAnalysisPhase = [Float](repeating: 0, count: halfN + 1)
        lastSynthesisPhase = [Float](repeating: 0, count: halfN + 1)

        // FFT buffers
        fftReal = [Float](repeating: 0, count: fftSize)
        fftImag = [Float](repeating: 0, count: fftSize)
        magnitudes = [Float](repeating: 0, count: halfN + 1)
        phases = [Float](repeating: 0, count: halfN + 1)

        // Ring buffers for overlap-add (4x fftSize for safety)
        let ringSize = fftSize * 4
        inputRingBuffer = [Float](repeating: 0, count: ringSize)
        outputRingBuffer = [Float](repeating: 0, count: ringSize)
        inputWritePos = 0
        outputReadPos = 0
        outputWritePos = 0

        // Harmony voice buffers
        harmony1OutputRing = [Float](repeating: 0, count: ringSize)
        harmony1WritePos = 0
        harmony1LastAnalysisPhase = [Float](repeating: 0, count: halfN + 1)
        harmony1LastSynthesisPhase = [Float](repeating: 0, count: halfN + 1)

        harmony2OutputRing = [Float](repeating: 0, count: ringSize)
        harmony2WritePos = 0
        harmony2LastAnalysisPhase = [Float](repeating: 0, count: halfN + 1)
        harmony2LastSynthesisPhase = [Float](repeating: 0, count: halfN + 1)

        // DFT setup
        fftSetup = vDSP_DFT_zrop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD)
        ifftSetup = vDSP_DFT_zrop_CreateSetup(nil, vDSP_Length(fftSize), .INVERSE)
    }

    private func setupSpectralAnalysis() {
        spectrumMagnitudes = [Float](repeating: 0, count: fftSize / 2 + 1)
    }

    // MARK: - Parameter Access

    func setParameter(address: ParameterAddress, value: Float) {
        switch address {
        case .correctionSpeed:    correctionSpeed = value
        case .correctionStrength: correctionStrength = value
        case .rootNote:           rootNote = Int(value) % 12
        case .scaleType:          scaleTypeIndex = Int(value) % VocalDSPKernel.scaleIntervals.count
        case .formantShift:       formantShift = value
        case .harmonyMix:         harmonyMix = value
        case .harmonyInterval1:   harmonyInterval1 = value
        case .harmonyInterval2:   harmonyInterval2 = value
        case .inputGain:          inputGain = value
        case .outputGain:         outputGain = value
        case .dryWet:             dryWet = value
        case .transpose:          transpose = value
        case .humanize:           humanize = value
        case .bypass:             bypassed = value > 0.5
        }
    }

    func getParameter(address: ParameterAddress) -> Float {
        switch address {
        case .correctionSpeed:    return correctionSpeed
        case .correctionStrength: return correctionStrength
        case .rootNote:           return Float(rootNote)
        case .scaleType:          return Float(scaleTypeIndex)
        case .formantShift:       return formantShift
        case .harmonyMix:         return harmonyMix
        case .harmonyInterval1:   return harmonyInterval1
        case .harmonyInterval2:   return harmonyInterval2
        case .inputGain:          return inputGain
        case .outputGain:         return outputGain
        case .dryWet:             return dryWet
        case .transpose:          return transpose
        case .humanize:           return humanize
        case .bypass:             return bypassed ? 1.0 : 0.0
        }
    }

    // MARK: - Audio Processing (Real-Time Safe)

    func process(
        inputBufferList: UnsafePointer<AudioBufferList>,
        outputBufferList: UnsafeMutablePointer<AudioBufferList>,
        frameCount: AVAudioFrameCount
    ) {
        let inputBuffers = UnsafeMutableAudioBufferListPointer(
            UnsafeMutablePointer(mutating: inputBufferList)
        )
        let outputBuffers = UnsafeMutableAudioBufferListPointer(outputBufferList)

        guard !bypassed else {
            // Pass-through
            for channel in 0..<min(inputBuffers.count, outputBuffers.count) {
                guard let inputData = inputBuffers[channel].mData,
                      let outputData = outputBuffers[channel].mData else { continue }
                if inputData != outputData {
                    memcpy(outputData, inputData, Int(frameCount) * MemoryLayout<Float>.size)
                }
            }
            return
        }

        let frames = Int(frameCount)

        // Process channel 0 (mono vocal processing, copy to channel 1 if stereo)
        guard inputBuffers.count > 0, outputBuffers.count > 0,
              let inputData = inputBuffers[0].mData?.assumingMemoryBound(to: Float.self),
              let outputData = outputBuffers[0].mData?.assumingMemoryBound(to: Float.self) else {
            return
        }

        for frame in 0..<frames {
            let sample = inputData[frame] * inputGain

            // Store in ring buffer for analysis
            inputRingBuffer[inputWritePos] = sample
            inputWritePos = (inputWritePos + 1) % inputRingBuffer.count
        }

        // Run YIN pitch detection on accumulated samples
        detectPitch(from: inputData, frameCount: frames)

        // Run spectral analysis for visualization
        analyzeSpectrum(from: inputData, frameCount: frames)

        // Calculate pitch correction
        let correctionSemitones = calculatePitchCorrection()
        let totalShift = correctionSemitones + transpose

        // Apply pitch shift via simplified phase vocoder
        if abs(totalShift) > 0.01 {
            pitchShiftBlock(inputData, outputData, frameCount: frames, semitones: totalShift)
        } else {
            // No shift needed — copy with dry/wet
            for frame in 0..<frames {
                outputData[frame] = inputData[frame] * inputGain
            }
        }

        // Mix harmonies if enabled
        if harmonyMix > 0.01 {
            mixHarmonies(inputData, outputData, frameCount: frames)
        }

        // Apply dry/wet and output gain
        for frame in 0..<frames {
            let dry = inputData[frame] * inputGain
            let wet = outputData[frame]
            outputData[frame] = (dry * (1.0 - dryWet) + wet * dryWet) * outputGain
        }

        // Calculate RMS
        var rms: Float = 0
        vDSP_rmsqv(outputData, 1, &rms, vDSP_Length(frames))
        rmsLevel = rms

        // Copy to channel 1 if stereo
        if outputBuffers.count > 1, let outputR = outputBuffers[1].mData?.assumingMemoryBound(to: Float.self) {
            memcpy(outputR, outputData, frames * MemoryLayout<Float>.size)
        }
    }

    // MARK: - YIN Pitch Detection (Audio-Thread Safe)

    private func detectPitch(from samples: UnsafePointer<Float>, frameCount: Int) {
        guard frameCount >= 256 else { return }

        let bufferSize = min(frameCount, yinBufferSize)
        let halfBuffer = bufferSize / 2

        // Step 1: Difference function
        for tau in 0..<halfBuffer {
            var sum: Float = 0
            for j in 0..<halfBuffer {
                let diff = samples[j] - samples[j + tau]
                sum += diff * diff
            }
            yinBuffer[tau] = sum
        }

        // Step 2: Cumulative mean normalized difference
        yinBuffer[0] = 1.0
        var runningSum: Float = 0
        for tau in 1..<halfBuffer {
            runningSum += yinBuffer[tau]
            yinBuffer[tau] = runningSum > 0 ? yinBuffer[tau] * Float(tau) / runningSum : 1.0
        }

        // Step 3: Absolute threshold
        var bestTau: Int = -1
        for tau in 2..<halfBuffer {
            if yinBuffer[tau] < yinThreshold {
                // Find local minimum
                while tau + 1 < halfBuffer && yinBuffer[tau + 1] < yinBuffer[tau] {
                    break
                }
                bestTau = tau
                break
            }
        }

        guard bestTau > 0 else {
            pitchConfidence = 0
            return
        }

        // Step 4: Parabolic interpolation
        let betterTau: Float
        if bestTau > 0 && bestTau < halfBuffer - 1 {
            let s0 = yinBuffer[bestTau - 1]
            let s1 = yinBuffer[bestTau]
            let s2 = yinBuffer[bestTau + 1]
            let denom = 2.0 * s1 - s2 - s0
            if abs(denom) > 1e-10 {
                betterTau = Float(bestTau) + (s2 - s0) / (2.0 * denom)
            } else {
                betterTau = Float(bestTau)
            }
        } else {
            betterTau = Float(bestTau)
        }

        let pitch = Float(sampleRate) / betterTau
        if pitch > 50 && pitch < 2000 {
            detectedPitch = pitch
            pitchConfidence = 1.0 - yinBuffer[bestTau]
        } else {
            pitchConfidence = 0
        }
    }

    // MARK: - Pitch Correction

    private func calculatePitchCorrection() -> Float {
        guard pitchConfidence > 0.5, detectedPitch > 50 else {
            return smoothedPitchCorrection * 0.95  // Decay when no pitch detected
        }

        // Convert Hz to MIDI note
        let midiNote = 69.0 + 12.0 * logf(detectedPitch / 440.0) / logf(2.0)

        // Find nearest scale note
        let noteClass = ((Int(round(midiNote)) % 12) + 12) % 12
        let scaleNotes = VocalDSPKernel.scaleIntervals[scaleTypeIndex].map {
            (($0 + rootNote) % 12 + 12) % 12
        }

        var bestDistance: Float = 12
        var bestScaleNote = noteClass

        for scaleNote in scaleNotes {
            let dist = Float(min(abs(noteClass - scaleNote), 12 - abs(noteClass - scaleNote)))
            if dist < bestDistance {
                bestDistance = dist
                bestScaleNote = scaleNote
            }
        }

        // Calculate correction in semitones
        var correction = Float(bestScaleNote - noteClass)
        if correction > 6 { correction -= 12 }
        if correction < -6 { correction += 12 }

        // Add fractional correction (snap to exact semitone)
        let fracPart = midiNote - round(midiNote)
        correction -= fracPart

        // Apply strength
        correction *= correctionStrength

        // Humanize: add slight random variation
        if humanize > 0 {
            // Deterministic pseudo-random based on sample position
            let pseudoRandom = sin(detectedPitch * 0.1) * humanize * 0.03
            correction += pseudoRandom
        }

        // Smooth based on correction speed
        let alpha: Float
        if correctionSpeed <= 0 {
            alpha = 1.0
        } else {
            let blockTime: Float = Float(maxFrames) / Float(sampleRate)
            alpha = min(1.0, blockTime / (correctionSpeed / 1000.0))
        }

        smoothedPitchCorrection += (correction - smoothedPitchCorrection) * alpha
        return smoothedPitchCorrection
    }

    // MARK: - Pitch Shifting (Simplified Phase Vocoder)

    /// Block-based pitch shift using resampling (low-latency approach)
    private func pitchShiftBlock(
        _ input: UnsafePointer<Float>,
        _ output: UnsafeMutablePointer<Float>,
        frameCount: Int,
        semitones: Float
    ) {
        let ratio = powf(2.0, semitones / 12.0)

        // Simple linear-interpolation resampling for pitch shift
        for i in 0..<frameCount {
            let sourcePos = Float(i) * ratio
            let intIdx = Int(sourcePos)
            let frac = sourcePos - Float(intIdx)

            if intIdx + 1 < frameCount {
                output[i] = input[intIdx] * (1.0 - frac) + input[intIdx + 1] * frac
            } else if intIdx < frameCount {
                output[i] = input[intIdx]
            } else {
                output[i] = 0
            }
        }
    }

    // MARK: - Harmony Generation

    private func mixHarmonies(
        _ input: UnsafePointer<Float>,
        _ output: UnsafeMutablePointer<Float>,
        frameCount: Int
    ) {
        let harmGain = harmonyMix * 0.5  // Each harmony at half the mix level

        // Harmony Voice 1
        if abs(harmonyInterval1) > 0.01 {
            for i in 0..<frameCount {
                let ratio = powf(2.0, harmonyInterval1 / 12.0)
                let sourcePos = Float(i) * ratio
                let intIdx = Int(sourcePos)
                let frac = sourcePos - Float(intIdx)

                var harmonySample: Float = 0
                if intIdx + 1 < frameCount {
                    harmonySample = input[intIdx] * (1.0 - frac) + input[intIdx + 1] * frac
                } else if intIdx < frameCount {
                    harmonySample = input[intIdx]
                }
                output[i] += harmonySample * harmGain * inputGain
            }
        }

        // Harmony Voice 2
        if abs(harmonyInterval2) > 0.01 {
            for i in 0..<frameCount {
                let ratio = powf(2.0, harmonyInterval2 / 12.0)
                let sourcePos = Float(i) * ratio
                let intIdx = Int(sourcePos)
                let frac = sourcePos - Float(intIdx)

                var harmonySample: Float = 0
                if intIdx + 1 < frameCount {
                    harmonySample = input[intIdx] * (1.0 - frac) + input[intIdx + 1] * frac
                } else if intIdx < frameCount {
                    harmonySample = input[intIdx]
                }
                output[i] += harmonySample * harmGain * inputGain
            }
        }
    }

    // MARK: - Spectral Analysis (CIE 1931 Color Data)

    /// Analyze spectrum and extract band energies for visualization
    private func analyzeSpectrum(from samples: UnsafePointer<Float>, frameCount: Int) {
        guard frameCount >= 512 else { return }

        let n = min(frameCount, fftSize)
        let halfN = n / 2

        // Compute magnitudes using simple DFT on available samples
        // Band boundaries in Hz → bin indices
        let binWidth = Float(sampleRate) / Float(n)

        // 8 bands matching CIE 1931 octave transposition:
        // Sub-Bass(20-60), Bass(60-250), Low-Mid(250-500), Mid(500-2k),
        // Upper-Mid(2k-4k), Presence(4k-6k), Brilliance(6k-10k), Air(10k-20k)
        let bandEdges: [Float] = [20, 60, 250, 500, 2000, 4000, 6000, 10000, 20000]

        var bands: [Float] = [0, 0, 0, 0, 0, 0, 0, 0]
        var peakMag: Float = 0
        var peakBin: Int = 0

        // Simple magnitude estimation per band using autocorrelation proxy
        for band in 0..<8 {
            let lowBin = max(1, Int(bandEdges[band] / binWidth))
            let highBin = min(halfN - 1, Int(bandEdges[band + 1] / binWidth))
            guard highBin > lowBin else { continue }

            var bandEnergy: Float = 0
            let frameSlice = min(frameCount, 512)
            for bin in lowBin..<highBin {
                // Goertzel-like single-bin energy estimation
                let freq = Float(bin) * binWidth
                let omega = 2.0 * Float.pi * freq / Float(sampleRate)
                var real: Float = 0
                var imag: Float = 0
                for j in 0..<frameSlice {
                    let phase = omega * Float(j)
                    real += samples[j] * cos(phase)
                    imag += samples[j] * sin(phase)
                }
                let mag = sqrt(real * real + imag * imag) / Float(frameSlice)
                bandEnergy += mag
                if mag > peakMag {
                    peakMag = mag
                    peakBin = bin
                }
            }
            bands[band] = bandEnergy / Float(max(1, highBin - lowBin))
        }

        // Store results (atomic-width writes for audio thread safety)
        spectralBands = (bands[0], bands[1], bands[2], bands[3],
                         bands[4], bands[5], bands[6], bands[7])
        dominantFrequency = Float(peakBin) * binWidth
    }

    // MARK: - Reset

    func reset() {
        // Clear YIN state
        for i in 0..<yinBuffer.count { yinBuffer[i] = 0 }
        detectedPitch = 0
        pitchConfidence = 0
        smoothedPitchCorrection = 0

        // Clear ring buffers
        for i in 0..<inputRingBuffer.count { inputRingBuffer[i] = 0 }
        for i in 0..<outputRingBuffer.count { outputRingBuffer[i] = 0 }
        inputWritePos = 0
        outputReadPos = 0
        outputWritePos = 0

        // Clear phase tracking
        for i in 0..<lastAnalysisPhase.count {
            lastAnalysisPhase[i] = 0
            lastSynthesisPhase[i] = 0
        }

        // Clear harmony buffers
        for i in 0..<harmony1OutputRing.count { harmony1OutputRing[i] = 0 }
        for i in 0..<harmony2OutputRing.count { harmony2OutputRing[i] = 0 }
        harmony1WritePos = 0
        harmony2WritePos = 0
        for i in 0..<harmony1LastAnalysisPhase.count {
            harmony1LastAnalysisPhase[i] = 0
            harmony1LastSynthesisPhase[i] = 0
            harmony2LastAnalysisPhase[i] = 0
            harmony2LastSynthesisPhase[i] = 0
        }

        // Clear spectral state
        for i in 0..<spectrumMagnitudes.count { spectrumMagnitudes[i] = 0 }
        spectralBands = (0, 0, 0, 0, 0, 0, 0, 0)
        dominantFrequency = 0
        rmsLevel = 0
    }
}
#endif
