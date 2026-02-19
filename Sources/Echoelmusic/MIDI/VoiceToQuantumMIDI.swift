// VoiceToQuantumMIDI.swift
// Echoelmusic - Voice Input to Super Intelligent Quantum MIDI Bridge
// λ∞ Ralph Wiggum Apple Ökosystem Environment Lambda Loop Mode
//
// "Ich sing' und die Quantenwelt singt mit!" - Ralph Wiggum, Vocal Physicist
//
// Created 2026-01-21 - Phase 10000.3 VOICE TO QUANTUM MIDI
//
// ═══════════════════════════════════════════════════════════════════════════════
// VOICE INPUT MODES:
// - Direct: Stimme → MIDI Note (monophon)
// - Harmonizer: Stimme → Quantum Akkorde (polyphon)
// - Choir: Stimme → Orchester Sections
// - Bio-Reactive: Stimme + Biometrics → Lebendige Musik
// - Entangled: Zwei Stimmen verschränkt
// ═══════════════════════════════════════════════════════════════════════════════

import Foundation
import AVFoundation
import Combine
import Accelerate

// MARK: - Voice to Quantum MIDI Constants

public enum VoiceQuantumConstants {
    // Pitch detection
    public static let minFrequency: Float = 60.0      // Hz (low bass voice)
    public static let maxFrequency: Float = 2000.0    // Hz (high soprano + harmonics)
    public static let silenceThreshold: Float = 0.01  // RMS threshold
    public static let pitchSmoothingFactor: Float = 0.7

    // MIDI conversion
    public static let midiNoteA4: Int = 69
    public static let frequencyA4: Float = 440.0

    // Harmonizer intervals (in semitones)
    public static let majorTriad: [Int] = [0, 4, 7]
    public static let minorTriad: [Int] = [0, 3, 7]
    public static let powerChord: [Int] = [0, 7, 12]
    public static let fifthsStack: [Int] = [0, 7, 14, 21]
    public static let octaves: [Int] = [-12, 0, 12, 24]
}

// MARK: - Voice Input Mode

/// Different modes for voice-to-MIDI conversion
public enum VoiceInputMode: String, CaseIterable, Identifiable, Sendable {
    case direct = "Direct"                      // 1:1 voice to MIDI note
    case harmonizer = "Harmonizer"              // Voice + harmony voices
    case quantumChoir = "Quantum Choir"         // Voice to full orchestra
    case bioReactive = "Bio-Reactive"           // Voice modulated by biometrics
    case entangled = "Entangled Duet"          // Two voices quantum-linked
    case vocoder = "Quantum Vocoder"            // Robotic quantum voice
    case formantShift = "Formant Shifter"       // Chipmunk/Giant effect
    case pitchCorrect = "Pitch Correct"         // Auto-tune to scale

    public var id: String { rawValue }

    public var description: String {
        switch self {
        case .direct: return "Deine Stimme direkt als MIDI Note"
        case .harmonizer: return "Automatische Mehrstimmigkeit"
        case .quantumChoir: return "Steuere das ganze Orchester"
        case .bioReactive: return "Herzschlag + Atmung + Stimme"
        case .entangled: return "Zwei Stimmen verschränkt"
        case .vocoder: return "Roboter-Stimme mit Quantum-Färbung"
        case .formantShift: return "Formant-Verschiebung (Chipmunk/Riese)"
        case .pitchCorrect: return "Auto-Tune zur gewählten Tonart"
        }
    }
}

// MARK: - Harmony Mode

/// Harmony generation modes for the harmonizer
public enum HarmonyMode: String, CaseIterable, Identifiable, Sendable {
    case major = "Dur"
    case minor = "Moll"
    case power = "Power Chord"
    case fifths = "Quinten-Stapel"
    case octaves = "Oktaven"
    case quantum = "Quantum Superposition"
    case fibonacci = "Fibonacci Harmonie"
    case sacredGeometry = "Sacred Geometry"
    case bioCoherent = "Bio-Coherent"

    public var id: String { rawValue }

    public var intervals: [Int] {
        switch self {
        case .major: return [0, 4, 7]
        case .minor: return [0, 3, 7]
        case .power: return [0, 7, 12]
        case .fifths: return [0, 7, 14, 21]
        case .octaves: return [-12, 0, 12, 24]
        case .quantum: return [0, 2, 4, 5, 7, 9, 11]  // All scale degrees until "measured"
        case .fibonacci: return [0, 1, 2, 3, 5, 8]    // Fibonacci semitones
        case .sacredGeometry: return [0, 4, 7, 11, 14] // Golden ratio approximation
        case .bioCoherent: return [0, 7, 12]          // Dynamic based on coherence
        }
    }
}

// MARK: - Voice Analysis Data

/// Real-time voice analysis results
public struct VoiceAnalysisData: Sendable {
    public var frequency: Float = 0           // Detected pitch in Hz
    public var midiNote: UInt8 = 60           // MIDI note number
    public var midiNoteFraction: Float = 0    // Cents deviation from note
    public var amplitude: Float = 0           // RMS amplitude 0-1
    public var isVoiced: Bool = false         // Voice detected vs silence
    public var confidence: Float = 0          // Pitch detection confidence
    public var formantFrequencies: [Float] = [] // F1, F2, F3 formants
    public var brightness: Float = 0.5        // Spectral centroid (dull → bright)
    public var breathiness: Float = 0         // Noise-to-harmonic ratio

    public init() {}

    /// Convert frequency to MIDI note number with cents
    public static func frequencyToMIDI(_ freq: Float) -> (note: UInt8, cents: Float) {
        guard freq > 0 else { return (0, 0) }

        let noteFloat = 12.0 * log2(freq / VoiceQuantumConstants.frequencyA4) + Float(VoiceQuantumConstants.midiNoteA4)
        let noteInt = Int(noteFloat.rounded())
        let cents = (noteFloat - Float(noteInt)) * 100

        return (UInt8(max(0, min(127, noteInt))), cents)
    }
}

// MARK: - Voice to Quantum MIDI Bridge

/// Bridge that connects voice input to the Super Intelligent Quantum MIDI Out system
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
@MainActor
public final class VoiceToQuantumMIDI: ObservableObject {

    // MARK: - Published Properties

    @Published public var isActive: Bool = false
    @Published public var mode: VoiceInputMode = .harmonizer
    @Published public var harmonyMode: HarmonyMode = .major
    @Published public var voiceData: VoiceAnalysisData = VoiceAnalysisData()

    // Voice settings
    @Published public var transpose: Int = 0              // Semitones (-24 to +24)
    @Published public var harmonyVoices: Int = 3          // Number of harmony voices
    @Published public var formantShift: Float = 0         // -1 (giant) to +1 (chipmunk)
    @Published public var pitchCorrectStrength: Float = 0.5 // 0 = natural, 1 = hard tune
    @Published public var voiceGain: Float = 1.0          // Input gain

    // Scale for pitch correction
    @Published public var rootNote: Int = 0               // 0 = C, 1 = C#, etc.
    @Published public var scale: [Int] = [0, 2, 4, 5, 7, 9, 11] // Major scale

    // Target instruments
    @Published public var leadInstrument: QuantumMIDIVoice.InstrumentTarget = .bioReactive
    @Published public var harmonyInstruments: [QuantumMIDIVoice.InstrumentTarget] = [
        .violins, .violas, .cellos
    ]
    @Published public var choirInstruments: [QuantumMIDIVoice.InstrumentTarget] = [
        .sopranos, .altos, .tenors, .choirBasses
    ]

    // MARK: - Private Properties

    private var quantumMIDIOut: QuantumMIDIOut?
    private var pitchDetector = PitchDetector()
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?

    private var lastMIDINote: UInt8 = 0
    private var activeHarmonyNotes: [UInt8] = []
    private var smoothedPitch: Float = 0
    private var cancellables = Set<AnyCancellable>()

    // YIN pitch detector parameters
    private let bufferSize: Int = 2048
    private let yinThreshold: Float = 0.15
    private var yinBuffer: [Float] = []

    // MARK: - Initialization

    public init(quantumMIDIOut: QuantumMIDIOut? = nil) {
        self.quantumMIDIOut = quantumMIDIOut
        self.yinBuffer = Array(repeating: 0, count: bufferSize)
    }

    // MARK: - Lifecycle

    /// Start voice input processing
    public func start() async throws {
        guard !isActive else { return }

        // Initialize Quantum MIDI Out if not provided
        if quantumMIDIOut == nil {
            quantumMIDIOut = QuantumMIDIOut(polyphony: 32)
        }

        try await quantumMIDIOut?.start()

        // Setup audio engine
        try setupAudioEngine()

        isActive = true
        log.audio("🎤⚛️ VoiceToQuantumMIDI ACTIVATED - Mode: \(mode.rawValue)")
    }

    /// Stop voice input processing
    public func stop() {
        isActive = false

        // Stop all notes
        stopAllHarmonyNotes()
        if lastMIDINote > 0 {
            quantumMIDIOut?.noteOff(note: lastMIDINote, instrument: leadInstrument)
            lastMIDINote = 0
        }

        // Stop audio engine
        audioEngine?.stop()
        audioEngine = nil

        quantumMIDIOut?.stop()

        log.audio("🎤⚛️ VoiceToQuantumMIDI DEACTIVATED")
    }

    // MARK: - Audio Engine Setup

    private func setupAudioEngine() throws {
        audioEngine = AVAudioEngine()

        guard let engine = audioEngine else {
            throw VoiceQuantumError.audioEngineSetupFailed
        }

        inputNode = engine.inputNode
        let format = inputNode?.outputFormat(forBus: 0)

        guard let audioFormat = format else {
            throw VoiceQuantumError.invalidAudioFormat
        }

        // Install tap on input
        inputNode?.installTap(onBus: 0, bufferSize: AVAudioFrameCount(bufferSize), format: audioFormat) { [weak self] buffer, time in
            Task { @MainActor in
                self?.processAudioBuffer(buffer)
            }
        }

        try engine.start()
    }

    // MARK: - Audio Processing

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)

        // Copy to YIN buffer
        let samplesToProcess = min(frameCount, bufferSize)
        for i in 0..<samplesToProcess {
            yinBuffer[i] = channelData[i] * voiceGain
        }

        // Calculate RMS amplitude
        var rms: Float = 0
        vDSP_rmsqv(yinBuffer, 1, &rms, vDSP_Length(samplesToProcess))
        voiceData.amplitude = rms

        // Check for silence
        if rms < VoiceQuantumConstants.silenceThreshold {
            handleSilence()
            return
        }

        // Detect pitch using YIN algorithm
        let sampleRate = Float(buffer.format.sampleRate)
        if let (frequency, confidence) = detectPitchYIN(sampleRate: sampleRate) {
            voiceData.isVoiced = true
            voiceData.confidence = confidence

            // Smooth the pitch
            smoothedPitch = VoiceQuantumConstants.pitchSmoothingFactor * smoothedPitch +
                           (1.0 - VoiceQuantumConstants.pitchSmoothingFactor) * frequency

            voiceData.frequency = smoothedPitch

            // Convert to MIDI
            let (note, cents) = VoiceAnalysisData.frequencyToMIDI(smoothedPitch)
            voiceData.midiNote = note
            voiceData.midiNoteFraction = cents

            // Calculate brightness (spectral centroid approximation)
            voiceData.brightness = calculateBrightness()

            // Process based on mode
            processVoiceToMIDI()
        }
    }

    // MARK: - Pitch Detection (delegates to shared PitchDetector)

    private func detectPitchYIN(sampleRate: Float) -> (frequency: Float, confidence: Float)? {
        let frequency = pitchDetector.detectPitch(samples: yinBuffer, sampleRate: sampleRate)
        guard frequency > 0,
              frequency >= VoiceQuantumConstants.minFrequency,
              frequency <= VoiceQuantumConstants.maxFrequency else { return nil }
        return (frequency, 0.9) // PitchDetector only returns voiced results above threshold
    }

    private func calculateBrightness() -> Float {
        // Simple brightness estimation based on high frequency content
        var highSum: Float = 0
        var totalSum: Float = 0

        let midpoint = bufferSize / 4

        for i in 0..<bufferSize/2 {
            let magnitude = abs(yinBuffer[i])
            totalSum += magnitude
            if i > midpoint {
                highSum += magnitude
            }
        }

        return totalSum > 0 ? highSum / totalSum : 0.5
    }

    // MARK: - Voice to MIDI Processing

    private func processVoiceToMIDI() {
        guard let midiOut = quantumMIDIOut else { return }

        var targetNote = Int(voiceData.midiNote) + transpose

        // Apply pitch correction if enabled
        if mode == .pitchCorrect || pitchCorrectStrength > 0 {
            targetNote = applyPitchCorrection(targetNote)
        }

        let finalNote = UInt8(max(0, min(127, targetNote)))
        let velocity = voiceData.amplitude.mapped(from: 0...0.5, to: 0.3...1.0)

        // Update bio input with voice data
        midiOut.updateBioInput(coherence: voiceData.confidence)

        switch mode {
        case .direct:
            processDirectMode(note: finalNote, velocity: velocity)

        case .harmonizer:
            processHarmonizerMode(note: finalNote, velocity: velocity)

        case .quantumChoir:
            processQuantumChoirMode(note: finalNote, velocity: velocity)

        case .bioReactive:
            processBioReactiveMode(note: finalNote, velocity: velocity)

        case .entangled:
            processEntangledMode(note: finalNote, velocity: velocity)

        case .vocoder:
            processVocoderMode(note: finalNote, velocity: velocity)

        case .formantShift:
            processFormantShiftMode(note: finalNote, velocity: velocity)

        case .pitchCorrect:
            processDirectMode(note: finalNote, velocity: velocity) // Already pitch-corrected
        }
    }

    // MARK: - Mode Implementations

    private func processDirectMode(note: UInt8, velocity: Float) {
        guard let midiOut = quantumMIDIOut else { return }

        // Note changed?
        if note != lastMIDINote {
            // Note off for previous
            if lastMIDINote > 0 {
                midiOut.noteOff(note: lastMIDINote, instrument: leadInstrument)
            }

            // Note on for new
            midiOut.noteOn(note: note, velocity: velocity, instrument: leadInstrument)
            lastMIDINote = note
        }
    }

    private func processHarmonizerMode(note: UInt8, velocity: Float) {
        guard let midiOut = quantumMIDIOut else { return }

        let intervals = harmonyMode.intervals
        let voicesToUse = min(harmonyVoices, intervals.count)

        // Calculate harmony notes
        var newHarmonyNotes: [UInt8] = []
        for i in 0..<voicesToUse {
            let harmonyNote = Int(note) + intervals[i]
            if harmonyNote >= 0 && harmonyNote <= 127 {
                newHarmonyNotes.append(UInt8(harmonyNote))
            }
        }

        // Turn off notes that are no longer needed
        for oldNote in activeHarmonyNotes {
            if !newHarmonyNotes.contains(oldNote) {
                let instrumentIndex = activeHarmonyNotes.firstIndex(of: oldNote) ?? 0
                let instrument = harmonyInstruments[instrumentIndex % harmonyInstruments.count]
                midiOut.noteOff(note: oldNote, instrument: instrument)
            }
        }

        // Turn on new notes
        for (index, newNote) in newHarmonyNotes.enumerated() {
            if !activeHarmonyNotes.contains(newNote) {
                let instrument = harmonyInstruments[index % harmonyInstruments.count]
                let harmonyVelocity = velocity * (1.0 - Float(index) * 0.1) // Slightly quieter harmonies
                midiOut.noteOn(note: newNote, velocity: harmonyVelocity, instrument: instrument)
            }
        }

        activeHarmonyNotes = newHarmonyNotes
        lastMIDINote = note
    }

    private func processQuantumChoirMode(note: UInt8, velocity: Float) {
        guard let midiOut = quantumMIDIOut else { return }

        // Map voice to choir sections based on pitch
        let octave = Int(note) / 12

        // Distribute across choir
        var choirNotes: [(UInt8, QuantumMIDIVoice.InstrumentTarget)] = []

        if octave >= 5 { // High voice → Sopranos
            choirNotes.append((note, .sopranos))
            choirNotes.append((note - 12, .altos))
        } else if octave >= 4 { // Mid-high → Altos
            choirNotes.append((note, .altos))
            choirNotes.append((note + 12, .sopranos))
            choirNotes.append((note - 12, .tenors))
        } else if octave >= 3 { // Mid-low → Tenors
            choirNotes.append((note, .tenors))
            choirNotes.append((note + 12, .altos))
            choirNotes.append((note - 12, .choirBasses))
        } else { // Low → Basses
            choirNotes.append((note, .choirBasses))
            choirNotes.append((note + 12, .tenors))
        }

        // Also add string support
        choirNotes.append((note, .violins))
        choirNotes.append((note - 7, .cellos)) // Fifth below

        // Update: stop old, start new
        if note != lastMIDINote {
            for instrument in choirInstruments + [.violins, .cellos] {
                if lastMIDINote > 0 {
                    midiOut.noteOff(note: lastMIDINote, instrument: instrument)
                }
            }

            for (choirNote, instrument) in choirNotes {
                midiOut.noteOn(note: choirNote, velocity: velocity * 0.8, instrument: instrument)
            }

            lastMIDINote = note
        }
    }

    private func processBioReactiveMode(note: UInt8, velocity: Float) {
        guard let midiOut = quantumMIDIOut else { return }

        // Bio input modulates the harmony
        let coherence = midiOut.bioInput.coherence
        let breathPhase = midiOut.bioInput.breathPhase

        // Higher coherence = more consonant harmony
        let dynamicHarmony: [Int]
        if coherence > 0.8 {
            dynamicHarmony = [0, 7, 12] // Perfect intervals
        } else if coherence > 0.5 {
            dynamicHarmony = [0, 4, 7] // Major triad
        } else if coherence > 0.3 {
            dynamicHarmony = [0, 3, 7] // Minor triad
        } else {
            dynamicHarmony = [0, 4, 7, 10] // Dominant 7 (tension)
        }

        // Breathing modulates velocity
        let breathModulatedVelocity = velocity * (0.7 + breathPhase * 0.3)

        // Process like harmonizer but with dynamic harmony
        var newHarmonyNotes: [UInt8] = []
        for interval in dynamicHarmony {
            let harmonyNote = Int(note) + interval
            if harmonyNote >= 0 && harmonyNote <= 127 {
                newHarmonyNotes.append(UInt8(harmonyNote))
            }
        }

        // Update notes
        for oldNote in activeHarmonyNotes where !newHarmonyNotes.contains(oldNote) {
            midiOut.noteOff(note: oldNote, instrument: .bioReactive)
        }

        for newNote in newHarmonyNotes where !activeHarmonyNotes.contains(newNote) {
            midiOut.noteOn(note: newNote, velocity: breathModulatedVelocity, instrument: .bioReactive)
        }

        activeHarmonyNotes = newHarmonyNotes
        lastMIDINote = note
    }

    private func processEntangledMode(note: UInt8, velocity: Float) {
        guard let midiOut = quantumMIDIOut else { return }

        // Create quantum entanglement between two notes
        // Second voice is "anti-correlated" (inverted interval from center)
        let centerNote: UInt8 = 60 // Middle C as center
        let interval = Int(note) - Int(centerNote)
        let entangledNote = UInt8(max(0, min(127, Int(centerNote) - interval)))

        // Note changed?
        if note != lastMIDINote {
            if lastMIDINote > 0 {
                midiOut.noteOff(note: lastMIDINote, instrument: .quantumField)
                let oldEntangled = UInt8(max(0, min(127, Int(centerNote) - (Int(lastMIDINote) - Int(centerNote)))))
                midiOut.noteOff(note: oldEntangled, instrument: .entangledPair)
            }

            // Create entangled pair with quantum state
            let quantumState = QuantumMIDIVoice.QuantumVoiceState(
                coherence: voiceData.confidence,
                phase: Float.random(in: 0...Float.pi * 2),
                superposition: 0.5
            )

            midiOut.noteOn(note: note, velocity: velocity, instrument: .quantumField, quantumState: quantumState)
            midiOut.noteOn(note: entangledNote, velocity: velocity * 0.8, instrument: .entangledPair, quantumState: quantumState)

            lastMIDINote = note
        }
    }

    private func processVocoderMode(note: UInt8, velocity: Float) {
        guard let midiOut = quantumMIDIOut else { return }

        // Vocoder: quantize to chromatic, play multiple oscillators
        let vocoderNotes: [Int] = [
            Int(note),
            Int(note) + 12,
            Int(note) - 12,
            Int(note) + 7
        ]

        if note != lastMIDINote {
            // Stop old
            for oldNote in activeHarmonyNotes {
                midiOut.noteOff(note: oldNote, instrument: .subtractive)
            }

            // Start new with formant-like brightness control
            var newNotes: [UInt8] = []
            for (index, vNote) in vocoderNotes.enumerated() {
                if vNote >= 0 && vNote <= 127 {
                    let vocoderVelocity = velocity * (1.0 - Float(index) * 0.15)
                    midiOut.noteOn(note: UInt8(vNote), velocity: vocoderVelocity, instrument: .subtractive)
                    newNotes.append(UInt8(vNote))
                }
            }

            activeHarmonyNotes = newNotes
            lastMIDINote = note
        }
    }

    private func processFormantShiftMode(note: UInt8, velocity: Float) {
        guard let midiOut = quantumMIDIOut else { return }

        // Formant shift: transpose pitch but keep formant character
        // Positive shift = chipmunk (higher pitch, same formants)
        // Negative shift = giant (lower pitch, same formants)

        let shiftSemitones = Int(formantShift * 12) // ±12 semitones
        let shiftedNote = UInt8(max(0, min(127, Int(note) + shiftSemitones)))

        if shiftedNote != lastMIDINote {
            if lastMIDINote > 0 {
                midiOut.noteOff(note: lastMIDINote, instrument: .physicalModeling)
            }

            midiOut.noteOn(note: shiftedNote, velocity: velocity, instrument: .physicalModeling)
            lastMIDINote = shiftedNote
        }
    }

    // MARK: - Pitch Correction

    private func applyPitchCorrection(_ note: Int) -> Int {
        guard !scale.isEmpty else { return note }

        // Find nearest note in scale
        let noteInOctave = note % 12
        let octave = note / 12

        var nearestScaleNote = scale[0]
        var minDistance = 12

        for scaleNote in scale {
            let adjusted = (scaleNote + rootNote) % 12
            let distance = abs(noteInOctave - adjusted)
            let wrappedDistance = min(distance, 12 - distance)

            if wrappedDistance < minDistance {
                minDistance = wrappedDistance
                nearestScaleNote = adjusted
            }
        }

        // Interpolate based on correction strength
        let correctedNote = octave * 12 + nearestScaleNote
        let difference = correctedNote - note
        let actualCorrection = Int(Float(difference) * pitchCorrectStrength)

        return note + actualCorrection
    }

    // MARK: - Silence Handling

    private func handleSilence() {
        voiceData.isVoiced = false

        // Turn off all notes on silence
        if lastMIDINote > 0 {
            quantumMIDIOut?.noteOff(note: lastMIDINote, instrument: leadInstrument)
            lastMIDINote = 0
        }

        stopAllHarmonyNotes()
    }

    private func stopAllHarmonyNotes() {
        guard let midiOut = quantumMIDIOut else { return }

        for note in activeHarmonyNotes {
            for instrument in harmonyInstruments {
                midiOut.noteOff(note: note, instrument: instrument)
            }
        }
        activeHarmonyNotes.removeAll()
    }

    // MARK: - Presets

    /// Classic 3-voice harmony
    public func loadClassicHarmonizerPreset() {
        mode = .harmonizer
        harmonyMode = .major
        harmonyVoices = 3
        harmonyInstruments = [.violins, .violas, .cellos]
        transpose = 0
    }

    /// Full quantum choir
    public func loadQuantumChoirPreset() {
        mode = .quantumChoir
        choirInstruments = [.sopranos, .altos, .tenors, .choirBasses]
        transpose = 0
    }

    /// Bio-reactive meditation
    public func loadMeditationPreset() {
        mode = .bioReactive
        harmonyMode = .bioCoherent
        harmonyVoices = 4
        pitchCorrectStrength = 0.3
        scale = [0, 2, 4, 7, 9] // Pentatonic
    }

    /// Quantum vocoder robot
    public func loadVocoderPreset() {
        mode = .vocoder
        transpose = 0
        leadInstrument = .subtractive
    }

    /// Entangled duet
    public func loadEntangledDuetPreset() {
        mode = .entangled
        leadInstrument = .quantumField
    }
}

// MARK: - Errors

public enum VoiceQuantumError: Error, LocalizedError {
    case audioEngineSetupFailed
    case invalidAudioFormat
    case microphonePermissionDenied

    public var errorDescription: String? {
        switch self {
        case .audioEngineSetupFailed: return "Audio engine setup failed"
        case .invalidAudioFormat: return "Invalid audio format"
        case .microphonePermissionDenied: return "Microphone permission denied"
        }
    }
}

// MARK: - Extensions

private extension Float {
    func mapped(from source: ClosedRange<Float>, to destination: ClosedRange<Float>) -> Float {
        let normalized = (self - source.lowerBound) / (source.upperBound - source.lowerBound)
        let clamped = max(0, min(1, normalized))
        return destination.lowerBound + clamped * (destination.upperBound - destination.lowerBound)
    }
}
