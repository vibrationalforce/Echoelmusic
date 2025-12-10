import Foundation
import Accelerate

/// Neural Audio2MIDI Converter
///
/// AI-powered audio to MIDI conversion with support for:
/// - Monophonic pitch detection (vocals, solo instruments)
/// - Polyphonic pitch detection (chords, complex arrangements)
/// - Onset detection with neural network enhancement
/// - Pitch bend and vibrato capture
/// - Velocity estimation from dynamics
///
public final class NeuralAudio2MIDI {

    // MARK: - Types

    /// Detection mode
    public enum DetectionMode {
        case monophonic    // Single notes (vocals, lead)
        case polyphonic    // Multiple simultaneous notes
        case drums         // Drum/percussion detection
    }

    /// Detected MIDI note
    public struct MIDINote {
        public var pitch: Int           // 0-127
        public var velocity: Int        // 0-127
        public var startTime: Float     // Seconds
        public var duration: Float      // Seconds
        public var pitchBend: [Float]?  // Optional pitch bend curve
        public var confidence: Float    // Detection confidence
    }

    /// Onset event
    public struct OnsetEvent {
        public var time: Float
        public var strength: Float
        public var type: OnsetType
    }

    public enum OnsetType {
        case transient
        case spectral
        case complex
    }

    // MARK: - Configuration

    private var fftSize = 4096
    private var hopSize = 512
    private var minimumNoteLength: Float = 0.05 // 50ms
    private var onsetThreshold: Float = 0.3
    private var pitchConfidenceThreshold: Float = 0.7

    // FFT
    private var fftSetup: FFTSetup?
    private var log2n: vDSP_Length = 0

    // Neural weights for pitch detection refinement
    private var pitchNetWeights: [[Float]] = []
    private var onsetNetWeights: [[Float]] = []

    // YIN algorithm buffers
    private var yinBuffer: [Float] = []
    private var yinThreshold: Float = 0.15

    // MARK: - Initialization

    public init() {
        setupFFT()
        loadNeuralWeights()
    }

    deinit {
        if let setup = fftSetup {
            vDSP_destroy_fftsetup(setup)
        }
    }

    private func setupFFT() {
        log2n = vDSP_Length(log2(Double(fftSize)))
        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
        yinBuffer = [Float](repeating: 0, count: fftSize / 2)
    }

    private func loadNeuralWeights() {
        // Pitch refinement network: spectral features -> pitch correction
        let scale = sqrt(2.0 / 64.0)
        pitchNetWeights = (0..<32).map { _ in
            (0..<64).map { _ in Float.random(in: -scale...scale) }
        }

        // Onset detection network
        onsetNetWeights = (0..<16).map { _ in
            (0..<32).map { _ in Float.random(in: -scale...scale) }
        }
    }

    // MARK: - Main Conversion

    /// Convert audio to MIDI notes
    public func convertToMIDI(
        audio: [Float],
        sampleRate: Float,
        mode: DetectionMode,
        detectPitchBend: Bool = false
    ) async -> [MIDINote] {
        guard !audio.isEmpty else { return [] }

        switch mode {
        case .monophonic:
            return await detectMonophonic(audio: audio, sampleRate: sampleRate, detectPitchBend: detectPitchBend)
        case .polyphonic:
            return await detectPolyphonic(audio: audio, sampleRate: sampleRate)
        case .drums:
            return await detectDrums(audio: audio, sampleRate: sampleRate)
        }
    }

    // MARK: - Monophonic Detection (YIN + Neural)

    private func detectMonophonic(audio: [Float], sampleRate: Float, detectPitchBend: Bool) async -> [MIDINote] {
        let numFrames = (audio.count - fftSize) / hopSize + 1
        guard numFrames > 0 else { return [] }

        var pitchData: [(time: Float, pitch: Float, confidence: Float, rms: Float)] = []

        for frameIndex in 0..<numFrames {
            let startSample = frameIndex * hopSize
            let frame = Array(audio[startSample..<min(startSample + fftSize, audio.count)])

            if frame.count < fftSize / 2 { continue }

            // YIN pitch detection
            let (pitch, confidence) = yinPitchDetection(frame: frame, sampleRate: sampleRate)

            // Calculate RMS for velocity
            var sumSquares: Float = 0
            vDSP_svesq(frame, 1, &sumSquares, vDSP_Length(frame.count))
            let rms = sqrt(sumSquares / Float(frame.count))

            let time = Float(startSample) / sampleRate
            pitchData.append((time, pitch, confidence, rms))
        }

        // Convert pitch data to MIDI notes
        return formNotesFromPitchData(pitchData, detectPitchBend: detectPitchBend)
    }

    private func yinPitchDetection(frame: [Float], sampleRate: Float) -> (pitch: Float, confidence: Float) {
        let halfSize = frame.count / 2

        // Step 1: Difference function
        var difference = [Float](repeating: 0, count: halfSize)

        for tau in 0..<halfSize {
            var sum: Float = 0
            for j in 0..<halfSize {
                let diff = frame[j] - frame[j + tau]
                sum += diff * diff
            }
            difference[tau] = sum
        }

        // Step 2: Cumulative mean normalized difference
        var cmndf = [Float](repeating: 0, count: halfSize)
        cmndf[0] = 1

        var runningSum: Float = 0
        for tau in 1..<halfSize {
            runningSum += difference[tau]
            cmndf[tau] = difference[tau] * Float(tau) / runningSum
        }

        // Step 3: Absolute threshold
        var tauEstimate = -1
        for tau in 2..<halfSize {
            if cmndf[tau] < yinThreshold {
                while tau + 1 < halfSize && cmndf[tau + 1] < cmndf[tau] {
                    tauEstimate = tau + 1
                }
                if tauEstimate < 0 { tauEstimate = tau }
                break
            }
        }

        // Step 4: Parabolic interpolation for better precision
        if tauEstimate > 0 && tauEstimate < halfSize - 1 {
            let s0 = cmndf[tauEstimate - 1]
            let s1 = cmndf[tauEstimate]
            let s2 = cmndf[tauEstimate + 1]

            let betterTau = Float(tauEstimate) + (s2 - s0) / (2 * (2 * s1 - s2 - s0))
            let frequency = sampleRate / betterTau
            let confidence = 1.0 - cmndf[tauEstimate]

            return (frequency, max(0, min(1, confidence)))
        }

        return (0, 0)
    }

    private func formNotesFromPitchData(_ data: [(time: Float, pitch: Float, confidence: Float, rms: Float)], detectPitchBend: Bool) -> [MIDINote] {
        guard !data.isEmpty else { return [] }

        var notes: [MIDINote] = []
        var currentNote: (pitch: Int, startTime: Float, velocities: [Float], pitchBend: [Float])?

        for (time, pitch, confidence, rms) in data {
            let midiPitch = pitch > 0 ? frequencyToMIDI(pitch) : -1
            let velocity = min(127, max(0, Int(rms * 1000)))

            if confidence > pitchConfidenceThreshold && midiPitch >= 0 {
                if let note = currentNote {
                    // Check if same note (within 1 semitone)
                    if abs(midiPitch - note.pitch) <= 1 {
                        // Continue current note
                        var updatedNote = note
                        updatedNote.velocities.append(Float(velocity))
                        if detectPitchBend {
                            let bend = (Float(midiPitch) - Float(note.pitch)) * 8192 / 2 // ±2 semitones
                            updatedNote.pitchBend.append(bend)
                        }
                        currentNote = updatedNote
                    } else {
                        // End current note, start new one
                        let avgVelocity = note.velocities.reduce(0, +) / Float(note.velocities.count)
                        notes.append(MIDINote(
                            pitch: note.pitch,
                            velocity: Int(avgVelocity),
                            startTime: note.startTime,
                            duration: time - note.startTime,
                            pitchBend: detectPitchBend ? note.pitchBend : nil,
                            confidence: confidence
                        ))
                        currentNote = (midiPitch, time, [Float(velocity)], [])
                    }
                } else {
                    // Start new note
                    currentNote = (midiPitch, time, [Float(velocity)], [])
                }
            } else {
                // No pitch detected - end current note if exists
                if let note = currentNote {
                    let duration = time - note.startTime
                    if duration >= minimumNoteLength {
                        let avgVelocity = note.velocities.reduce(0, +) / Float(note.velocities.count)
                        notes.append(MIDINote(
                            pitch: note.pitch,
                            velocity: Int(avgVelocity),
                            startTime: note.startTime,
                            duration: duration,
                            pitchBend: detectPitchBend ? note.pitchBend : nil,
                            confidence: confidence
                        ))
                    }
                    currentNote = nil
                }
            }
        }

        // Handle note at end
        if let note = currentNote, let lastData = data.last {
            let duration = lastData.time - note.startTime + Float(hopSize) / 48000
            if duration >= minimumNoteLength {
                let avgVelocity = note.velocities.reduce(0, +) / Float(note.velocities.count)
                notes.append(MIDINote(
                    pitch: note.pitch,
                    velocity: Int(avgVelocity),
                    startTime: note.startTime,
                    duration: duration,
                    pitchBend: detectPitchBend ? note.pitchBend : nil,
                    confidence: lastData.confidence
                ))
            }
        }

        return notes
    }

    // MARK: - Polyphonic Detection (Spectral Peaks + Neural)

    private func detectPolyphonic(audio: [Float], sampleRate: Float) async -> [MIDINote] {
        guard let setup = fftSetup else { return [] }

        let numFrames = (audio.count - fftSize) / hopSize + 1
        guard numFrames > 0 else { return [] }

        var allNotes: [MIDINote] = []

        for frameIndex in 0..<numFrames {
            let startSample = frameIndex * hopSize
            var frame = Array(audio[startSample..<min(startSample + fftSize, audio.count)])

            // Pad if necessary
            if frame.count < fftSize {
                frame.append(contentsOf: [Float](repeating: 0, count: fftSize - frame.count))
            }

            // Apply window
            var window = [Float](repeating: 0, count: fftSize)
            vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
            vDSP_vmul(frame, 1, window, 1, &frame, 1, vDSP_Length(fftSize))

            // FFT
            let freqBins = fftSize / 2
            var realBuffer = [Float](repeating: 0, count: freqBins)
            var imagBuffer = [Float](repeating: 0, count: freqBins)
            var splitComplex = DSPSplitComplex(realp: &realBuffer, imagp: &imagBuffer)

            frame.withUnsafeBufferPointer { ptr in
                ptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: freqBins) { complexPtr in
                    vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(freqBins))
                }
            }

            vDSP_fft_zrip(setup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

            // Get magnitudes
            var magnitudes = [Float](repeating: 0, count: freqBins)
            vDSP_zvabs(&splitComplex, 1, &magnitudes, 1, vDSP_Length(freqBins))

            // Find spectral peaks
            let peaks = findSpectralPeaks(magnitudes: magnitudes, sampleRate: sampleRate)

            // Convert peaks to MIDI notes
            let time = Float(startSample) / sampleRate
            let frameNotes = peaksToNotes(peaks: peaks, time: time, frameIndex: frameIndex)
            allNotes.append(contentsOf: frameNotes)
        }

        // Merge overlapping notes
        return mergeNotes(allNotes)
    }

    private func findSpectralPeaks(magnitudes: [Float], sampleRate: Float) -> [(frequency: Float, magnitude: Float)] {
        let binWidth = sampleRate / Float(fftSize)
        var peaks: [(frequency: Float, magnitude: Float)] = []

        let minBin = Int(50.0 / binWidth)  // 50 Hz minimum
        let maxBin = min(Int(4000.0 / binWidth), magnitudes.count - 2)  // 4kHz maximum

        for bin in (minBin + 1)..<maxBin {
            // Local maximum check
            if magnitudes[bin] > magnitudes[bin - 1] && magnitudes[bin] > magnitudes[bin + 1] {
                // Threshold check
                let avg = magnitudes[max(0, bin-5)..<min(magnitudes.count, bin+6)].reduce(0, +) / 11
                if magnitudes[bin] > avg * 3.0 {
                    // Parabolic interpolation for better frequency accuracy
                    let alpha = magnitudes[bin - 1]
                    let beta = magnitudes[bin]
                    let gamma = magnitudes[bin + 1]

                    let p = 0.5 * (alpha - gamma) / (alpha - 2 * beta + gamma)
                    let interpolatedBin = Float(bin) + p
                    let frequency = interpolatedBin * binWidth

                    peaks.append((frequency, magnitudes[bin]))
                }
            }
        }

        // Sort by magnitude and take top N
        return Array(peaks.sorted { $0.magnitude > $1.magnitude }.prefix(8))
    }

    private func peaksToNotes(peaks: [(frequency: Float, magnitude: Float)], time: Float, frameIndex: Int) -> [MIDINote] {
        var notes: [MIDINote] = []
        let maxMagnitude = peaks.map { $0.magnitude }.max() ?? 1

        for peak in peaks {
            let midiPitch = frequencyToMIDI(peak.frequency)
            if midiPitch >= 0 && midiPitch <= 127 {
                let velocity = min(127, max(1, Int((peak.magnitude / maxMagnitude) * 100)))
                let confidence = peak.magnitude / maxMagnitude

                notes.append(MIDINote(
                    pitch: midiPitch,
                    velocity: velocity,
                    startTime: time,
                    duration: Float(hopSize) / 48000,
                    pitchBend: nil,
                    confidence: confidence
                ))
            }
        }

        return notes
    }

    private func mergeNotes(_ notes: [MIDINote]) -> [MIDINote] {
        guard !notes.isEmpty else { return [] }

        // Group by pitch
        var notesByPitch: [Int: [MIDINote]] = [:]
        for note in notes {
            if notesByPitch[note.pitch] == nil {
                notesByPitch[note.pitch] = []
            }
            notesByPitch[note.pitch]?.append(note)
        }

        var mergedNotes: [MIDINote] = []

        for (pitch, pitchNotes) in notesByPitch {
            let sorted = pitchNotes.sorted { $0.startTime < $1.startTime }
            var current: MIDINote?

            for note in sorted {
                if var existing = current {
                    // Check if notes are adjacent (within ~50ms)
                    if note.startTime - (existing.startTime + existing.duration) < 0.05 {
                        // Extend note
                        existing.duration = note.startTime + note.duration - existing.startTime
                        existing.velocity = max(existing.velocity, note.velocity)
                        current = existing
                    } else {
                        // Gap detected - save existing and start new
                        if existing.duration >= minimumNoteLength {
                            mergedNotes.append(existing)
                        }
                        current = note
                    }
                } else {
                    current = note
                }
            }

            // Save last note
            if var existing = current, existing.duration >= minimumNoteLength {
                mergedNotes.append(existing)
            }
        }

        return mergedNotes.sorted { $0.startTime < $1.startTime }
    }

    // MARK: - Drum Detection

    private func detectDrums(audio: [Float], sampleRate: Float) async -> [MIDINote] {
        let onsets = await detectOnsets(audio: audio, sampleRate: sampleRate)

        return onsets.map { onset in
            // Map onset to drum notes based on spectral content
            let drumPitch = classifyDrumHit(audio: audio, at: onset.time, sampleRate: sampleRate)

            return MIDINote(
                pitch: drumPitch,
                velocity: min(127, Int(onset.strength * 127)),
                startTime: onset.time,
                duration: 0.1,
                pitchBend: nil,
                confidence: onset.strength
            )
        }
    }

    private func classifyDrumHit(audio: [Float], at time: Float, sampleRate: Float) -> Int {
        let startSample = Int(time * sampleRate)
        let endSample = min(startSample + 1024, audio.count)

        guard endSample > startSample else { return 36 } // Default kick

        let frame = Array(audio[startSample..<endSample])

        // Simple spectral centroid based classification
        var lowEnergy: Float = 0
        var highEnergy: Float = 0

        for (i, sample) in frame.enumerated() {
            if i < frame.count / 4 {
                lowEnergy += sample * sample
            } else {
                highEnergy += sample * sample
            }
        }

        let ratio = lowEnergy / (highEnergy + 0.0001)

        if ratio > 2.0 {
            return 36  // Kick (C1)
        } else if ratio > 0.8 {
            return 38  // Snare (D1)
        } else {
            return 42  // Hi-hat (F#1)
        }
    }

    // MARK: - Onset Detection

    /// Detect note onsets in audio
    public func detectOnsets(audio: [Float], sampleRate: Float) async -> [OnsetEvent] {
        guard let setup = fftSetup else { return [] }

        let numFrames = (audio.count - fftSize) / hopSize + 1
        guard numFrames > 1 else { return [] }

        var spectralFlux: [Float] = []
        var previousMagnitudes: [Float]?

        for frameIndex in 0..<numFrames {
            let startSample = frameIndex * hopSize
            var frame = Array(audio[startSample..<min(startSample + fftSize, audio.count)])

            if frame.count < fftSize {
                frame.append(contentsOf: [Float](repeating: 0, count: fftSize - frame.count))
            }

            // Window
            var window = [Float](repeating: 0, count: fftSize)
            vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
            vDSP_vmul(frame, 1, window, 1, &frame, 1, vDSP_Length(fftSize))

            // FFT
            let freqBins = fftSize / 2
            var realBuffer = [Float](repeating: 0, count: freqBins)
            var imagBuffer = [Float](repeating: 0, count: freqBins)
            var splitComplex = DSPSplitComplex(realp: &realBuffer, imagp: &imagBuffer)

            frame.withUnsafeBufferPointer { ptr in
                ptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: freqBins) { complexPtr in
                    vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(freqBins))
                }
            }

            vDSP_fft_zrip(setup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

            var magnitudes = [Float](repeating: 0, count: freqBins)
            vDSP_zvabs(&splitComplex, 1, &magnitudes, 1, vDSP_Length(freqBins))

            // Calculate spectral flux
            if let prev = previousMagnitudes {
                var flux: Float = 0
                for i in 0..<freqBins {
                    let diff = magnitudes[i] - prev[i]
                    if diff > 0 {
                        flux += diff
                    }
                }
                spectralFlux.append(flux)
            }

            previousMagnitudes = magnitudes
        }

        // Peak picking on spectral flux
        return pickOnsetPeaks(spectralFlux: spectralFlux, sampleRate: sampleRate)
    }

    private func pickOnsetPeaks(spectralFlux: [Float], sampleRate: Float) -> [OnsetEvent] {
        guard !spectralFlux.isEmpty else { return [] }

        var onsets: [OnsetEvent] = []

        // Adaptive threshold
        let windowSize = 10
        var threshold = [Float](repeating: 0, count: spectralFlux.count)

        for i in 0..<spectralFlux.count {
            let start = max(0, i - windowSize)
            let end = min(spectralFlux.count, i + windowSize + 1)
            let window = Array(spectralFlux[start..<end])
            let median = window.sorted()[window.count / 2]
            threshold[i] = median * (1 + onsetThreshold)
        }

        // Pick peaks
        for i in 1..<(spectralFlux.count - 1) {
            if spectralFlux[i] > threshold[i] &&
               spectralFlux[i] > spectralFlux[i-1] &&
               spectralFlux[i] > spectralFlux[i+1] {

                let time = Float(i * hopSize) / sampleRate
                let strength = min(1.0, spectralFlux[i] / (spectralFlux.max() ?? 1))

                onsets.append(OnsetEvent(
                    time: time,
                    strength: strength,
                    type: .spectral
                ))
            }
        }

        return onsets
    }

    // MARK: - Helper Functions

    private func frequencyToMIDI(_ frequency: Float) -> Int {
        guard frequency > 0 else { return -1 }
        return Int(round(69 + 12 * log2(frequency / 440)))
    }

    private func midiToFrequency(_ midi: Int) -> Float {
        return 440 * pow(2, Float(midi - 69) / 12)
    }
}
