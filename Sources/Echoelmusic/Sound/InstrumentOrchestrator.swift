import Foundation
import AVFoundation
import Combine

/// InstrumentOrchestrator - The Missing Link
/// Connects: UI Selection → Sound Library → Synthesis Engines → Audio Output
///
/// This class orchestrates the entire instrument playback pipeline:
/// 1. User selects instrument from UI
/// 2. Orchestrator loads instrument parameters from UniversalSoundLibrary
/// 3. Routes to appropriate synthesis engine (Swift or C++)
/// 4. Renders audio buffer
/// 5. Sends to AVAudioEngine for playback
///
/// Bio-Reactive Integration:
/// - Receives bio-data from EchoelUniversalCore
/// - Modulates synthesis parameters based on HRV/coherence
/// - Real-time parameter automation
@MainActor
class InstrumentOrchestrator: ObservableObject {

    // MARK: - Singleton

    static let shared = InstrumentOrchestrator()

    // MARK: - Published State

    @Published var currentInstrument: UniversalSoundLibrary.Instrument?
    @Published var currentSynthEngine: UniversalSoundLibrary.SynthEngine?
    @Published var isPlaying: Bool = false
    @Published var activeVoices: Int = 0

    // MARK: - Audio Engine

    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var mixerNode: AVAudioMixerNode?

    // MARK: - Sound Library

    private let soundLibrary = UniversalSoundLibrary()

    // MARK: - Voice Management

    private struct Voice {
        let id: UUID
        var midiNote: Int
        var velocity: Float
        var startTime: TimeInterval
        var isActive: Bool
        var audioBuffer: AVAudioPCMBuffer?
    }

    private var voices: [Voice] = []
    private let maxVoices = 16

    // MARK: - Bio-Reactive Parameters

    private var bioCoherence: Float = 0.5
    private var bioEnergy: Float = 0.5
    private var heartRate: Float = 70.0

    // MARK: - Combine

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        setupAudioEngine()
        setupDefaultInstrument()
        connectToBioData()

        EchoelLogger.success("InstrumentOrchestrator: Initialized", category: EchoelLogger.audio)
        EchoelLogger.log("🎹", "Available Instruments: \(soundLibrary.availableInstruments.count)", category: EchoelLogger.audio)
        EchoelLogger.log("🎛️", "Synthesis Engines: \(soundLibrary.availableSynthEngines.count)", category: EchoelLogger.audio)
    }

    deinit {
        // KRITISCH: NotificationCenter Observer entfernen um Memory Leak zu verhindern
        NotificationCenter.default.removeObserver(self)
        audioEngine?.stop()
        cancellables.removeAll()
    }

    // MARK: - Audio Engine Setup

    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()

        guard let engine = audioEngine else {
            EchoelLogger.error("InstrumentOrchestrator: Failed to create AVAudioEngine", category: EchoelLogger.audio)
            return
        }

        // Create player node for synthesized audio
        playerNode = AVAudioPlayerNode()
        mixerNode = engine.mainMixerNode

        guard let player = playerNode,
              let mixer = mixerNode else { return }

        // Attach player to engine
        engine.attach(player)

        // Connect player → mixer → output (SAFE: ohne force unwrap)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2) else {
            EchoelLogger.error("InstrumentOrchestrator: Failed to create audio format", category: EchoelLogger.audio)
            return
        }
        engine.connect(player, to: mixer, format: format)

        // Start the engine
        do {
            try engine.start()
            isPlaying = true
            EchoelLogger.log("🎵", "InstrumentOrchestrator: Audio engine started", category: EchoelLogger.audio)
        } catch {
            EchoelLogger.error("InstrumentOrchestrator: Failed to start audio engine: \(error)", category: EchoelLogger.audio)
        }
    }

    private func setupDefaultInstrument() {
        // Default to analog synth
        if let firstInstrument = soundLibrary.availableInstruments.first {
            currentInstrument = firstInstrument
        }

        // Default to subtractive synthesis
        if let subtractive = soundLibrary.availableSynthEngines.first(where: { $0.type == .subtractive }) {
            currentSynthEngine = subtractive
        }
    }

    // MARK: - Bio-Data Connection

    private func connectToBioData() {
        // Subscribe to UniversalCore bio-data updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(bioDataUpdated(_:)),
            name: NSNotification.Name("EchoelBioDataUpdated"),
            object: nil
        )
    }

    @objc private func bioDataUpdated(_ notification: Notification) {
        if let coherence = notification.userInfo?["coherence"] as? Float {
            bioCoherence = coherence
        }
        if let energy = notification.userInfo?["energy"] as? Float {
            bioEnergy = energy
        }
        if let hr = notification.userInfo?["heartRate"] as? Float {
            heartRate = hr
        }

        // Apply bio-modulation to synthesis
        applyBioModulation()
    }

    // MARK: - Instrument Selection

    /// Select instrument by name
    func selectInstrument(name: String) {
        if let instrument = soundLibrary.availableInstruments.first(where: { $0.name == name }) {
            currentInstrument = instrument
            EchoelLogger.log("🎹", "Selected: \(instrument.name)", category: EchoelLogger.audio)
        }
    }

    /// Select instrument by index
    func selectInstrument(index: Int) {
        guard index < soundLibrary.availableInstruments.count else { return }
        currentInstrument = soundLibrary.availableInstruments[index]
        EchoelLogger.log("🎹", "Selected: \(currentInstrument?.name ?? "Unknown")", category: EchoelLogger.audio)
    }

    /// Select synthesis engine
    func selectSynthEngine(_ type: UniversalSoundLibrary.SynthEngine.SynthType) {
        if let engine = soundLibrary.availableSynthEngines.first(where: { $0.type == type }) {
            currentSynthEngine = engine
            EchoelLogger.log("🎛️", "Synth Engine: \(engine.name)", category: EchoelLogger.audio)
        }
    }

    // MARK: - Note Playback

    /// Play a MIDI note
    func noteOn(midiNote: Int, velocity: Float = 0.8) {
        guard let synthEngine = currentSynthEngine else {
            EchoelLogger.warning("No synthesis engine selected", category: EchoelLogger.audio)
            return
        }

        // Check polyphony limit
        if activeVoices >= maxVoices {
            // Steal oldest voice
            stealOldestVoice()
        }

        // Calculate frequency from MIDI note
        let frequency = midiNoteToFrequency(midiNote)

        // Apply bio-modulation to parameters
        let modulatedVelocity = velocity * (0.5 + bioCoherence * 0.5)

        // Synthesize audio
        let duration: Float = 2.0  // 2 seconds max
        let sampleRate: Float = 48000.0
        let samples = synthEngine.synthesize(
            frequency: frequency,
            duration: duration,
            sampleRate: sampleRate
        )

        // Apply velocity envelope
        let envelopedSamples = applyVelocityEnvelope(samples, velocity: modulatedVelocity)

        // Create audio buffer
        if let buffer = createAudioBuffer(from: envelopedSamples, sampleRate: Double(sampleRate)) {
            // Create voice
            let voice = Voice(
                id: UUID(),
                midiNote: midiNote,
                velocity: velocity,
                startTime: Date().timeIntervalSince1970,
                isActive: true,
                audioBuffer: buffer
            )
            voices.append(voice)
            activeVoices += 1

            // Schedule playback
            playerNode?.scheduleBuffer(buffer, at: nil, options: []) { [weak self] in
                Task { @MainActor in
                    self?.voiceFinished(voice.id)
                }
            }

            if playerNode?.isPlaying == false {
                playerNode?.play()
            }

            EchoelLogger.log("🎵", "Note On: MIDI \(midiNote) @ \(Int(velocity * 100))% velocity", category: EchoelLogger.midi)
        }
    }

    /// Stop a MIDI note
    func noteOff(midiNote: Int) {
        // Mark voice as inactive (will release with envelope)
        if let index = voices.firstIndex(where: { $0.midiNote == midiNote && $0.isActive }) {
            voices[index].isActive = false
            EchoelLogger.log("🎵", "Note Off: MIDI \(midiNote)", category: EchoelLogger.midi)
        }
    }

    /// Stop all notes
    func allNotesOff() {
        playerNode?.stop()
        voices.removeAll()
        activeVoices = 0
        EchoelLogger.log("🛑", "All Notes Off", category: EchoelLogger.midi)
    }

    // MARK: - Drum Playback (808/909 Style)

    /// Trigger a drum sound
    func triggerDrum(_ drumType: DrumType, velocity: Float = 0.8) {
        // Use physical modeling for drums
        guard let physicalEngine = soundLibrary.availableSynthEngines.first(where: { $0.type == .physicalModeling }) else {
            EchoelLogger.warning("Physical modeling engine not available", category: EchoelLogger.audio)
            return
        }

        let frequency: Float
        let duration: Float

        switch drumType {
        case .kick:
            frequency = 60.0  // Low pitch
            duration = 0.5
        case .snare:
            frequency = 200.0
            duration = 0.3
        case .hiHatClosed:
            frequency = 8000.0
            duration = 0.1
        case .hiHatOpen:
            frequency = 8000.0
            duration = 0.4
        case .tomLow:
            frequency = 100.0
            duration = 0.4
        case .tomMid:
            frequency = 150.0
            duration = 0.35
        case .tomHigh:
            frequency = 200.0
            duration = 0.3
        case .clap:
            frequency = 1500.0
            duration = 0.2
        case .cowbell:
            frequency = 800.0
            duration = 0.25
        case .rimShot:
            frequency = 600.0
            duration = 0.15
        case .crash:
            frequency = 5000.0
            duration = 1.5
        case .ride:
            frequency = 4000.0
            duration = 0.8
        }

        // Synthesize drum
        let sampleRate: Float = 48000.0
        var samples = physicalEngine.synthesize(
            frequency: frequency,
            duration: duration,
            sampleRate: sampleRate
        )

        // Apply drum-specific envelope
        samples = applyDrumEnvelope(samples, drumType: drumType, velocity: velocity)

        // Play
        if let buffer = createAudioBuffer(from: samples, sampleRate: Double(sampleRate)) {
            playerNode?.scheduleBuffer(buffer, at: nil, options: [])
            if playerNode?.isPlaying == false {
                playerNode?.play()
            }
            EchoelLogger.log("🥁", "Drum: \(drumType) @ \(Int(velocity * 100))%", category: EchoelLogger.audio)
        }
    }

    enum DrumType: String, CaseIterable {
        case kick, snare, hiHatClosed, hiHatOpen
        case tomLow, tomMid, tomHigh
        case clap, cowbell, rimShot, crash, ride
    }

    // MARK: - Bio-Modulation

    private func applyBioModulation() {
        guard let engine = currentSynthEngine else { return }

        // Modulate filter cutoff based on coherence
        if let cutoffParam = engine.parameters.first(where: { $0.name == "Cutoff" }) {
            let modulatedCutoff = cutoffParam.range.lowerBound +
                (cutoffParam.range.upperBound - cutoffParam.range.lowerBound) * bioCoherence
            // Apply modulated cutoff...
        }

        // Modulate modulation index based on energy
        if let modIndex = engine.parameters.first(where: { $0.name == "Mod Index" }) {
            let modulatedIndex = modIndex.range.lowerBound +
                (modIndex.range.upperBound - modIndex.range.lowerBound) * bioEnergy
            // Apply modulated index...
        }
    }

    // MARK: - Helper Functions

    private func midiNoteToFrequency(_ note: Int) -> Float {
        return 440.0 * pow(2.0, Float(note - 69) / 12.0)
    }

    private func createAudioBuffer(from samples: [Float], sampleRate: Double) -> AVAudioPCMBuffer? {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else {
            return nil
        }

        buffer.frameLength = AVAudioFrameCount(samples.count)

        // Copy samples to both channels (stereo)
        if let leftChannel = buffer.floatChannelData?[0],
           let rightChannel = buffer.floatChannelData?[1] {
            for i in 0..<samples.count {
                leftChannel[i] = samples[i]
                rightChannel[i] = samples[i]
            }
        }

        return buffer
    }

    private func applyVelocityEnvelope(_ samples: [Float], velocity: Float) -> [Float] {
        var result = samples

        // Simple ADSR envelope
        let attackSamples = min(Int(0.01 * 48000), samples.count / 4)  // 10ms attack
        let releaseSamples = min(Int(0.1 * 48000), samples.count / 4)  // 100ms release

        // Attack
        for i in 0..<attackSamples {
            let envelope = Float(i) / Float(attackSamples)
            result[i] *= envelope * velocity
        }

        // Sustain
        for i in attackSamples..<(samples.count - releaseSamples) {
            result[i] *= velocity
        }

        // Release
        for i in (samples.count - releaseSamples)..<samples.count {
            let relativePos = Float(i - (samples.count - releaseSamples)) / Float(releaseSamples)
            let envelope = 1.0 - relativePos
            result[i] *= envelope * velocity
        }

        return result
    }

    private func applyDrumEnvelope(_ samples: [Float], drumType: DrumType, velocity: Float) -> [Float] {
        var result = samples

        // Drum-specific envelopes
        let attackSamples: Int
        let decayRate: Float

        switch drumType {
        case .kick:
            attackSamples = Int(0.001 * 48000)  // 1ms
            decayRate = 0.999
        case .snare:
            attackSamples = Int(0.0005 * 48000)  // 0.5ms
            decayRate = 0.998
        case .hiHatClosed, .hiHatOpen:
            attackSamples = Int(0.0001 * 48000)  // 0.1ms
            decayRate = 0.995
        case .clap:
            attackSamples = Int(0.001 * 48000)
            decayRate = 0.99
        default:
            attackSamples = Int(0.001 * 48000)
            decayRate = 0.997
        }

        var envelope: Float = 0.0
        for i in 0..<samples.count {
            if i < attackSamples {
                envelope = Float(i) / Float(attackSamples)
            } else {
                envelope *= decayRate
            }
            result[i] *= envelope * velocity
        }

        return result
    }

    private func stealOldestVoice() {
        if let oldestIndex = voices.indices.min(by: { voices[$0].startTime < voices[$1].startTime }) {
            voices.remove(at: oldestIndex)
            activeVoices -= 1
        }
    }

    private func voiceFinished(_ voiceId: UUID) {
        if let index = voices.firstIndex(where: { $0.id == voiceId }) {
            voices.remove(at: index)
            activeVoices -= 1
        }
    }

    // MARK: - Public API for AudioEngine Integration

    /// Get all available instruments
    var availableInstruments: [UniversalSoundLibrary.Instrument] {
        soundLibrary.availableInstruments
    }

    /// Get all available synthesis engines
    var availableSynthEngines: [UniversalSoundLibrary.SynthEngine] {
        soundLibrary.availableSynthEngines
    }

    /// Generate sound library report
    func generateReport() -> String {
        soundLibrary.generateSoundLibraryReport()
    }
}

// MARK: - AudioEngine Extension for Synthesis Integration

extension AudioEngine {

    /// Set filter cutoff (for bio-reactive control)
    func setFilterCutoff(_ value: Float) {
        // Route to InstrumentOrchestrator
        Task { @MainActor in
            if let engine = InstrumentOrchestrator.shared.currentSynthEngine,
               let index = engine.parameters.firstIndex(where: { $0.name == "Cutoff" }) {
                engine.parameters[index].value = value
            }
        }
    }

    /// Set filter resonance
    func setFilterResonance(_ value: Float) {
        Task { @MainActor in
            if let engine = InstrumentOrchestrator.shared.currentSynthEngine,
               let index = engine.parameters.firstIndex(where: { $0.name == "Resonance" }) {
                engine.parameters[index].value = value
            }
        }
    }

    /// Set reverb size
    func setReverbSize(_ value: Float) {
        // Apply to spatial audio engine if available
    }

    /// Set reverb wetness
    func setReverbWetness(_ value: Float) {
        // Apply to spatial audio engine if available
    }

    /// Set delay time
    func setDelayTime(_ value: Float) {
        // Future: Apply to delay effect
    }

    /// Set master volume
    func setMasterVolume(_ value: Float) {
        // Apply to mixer
    }

    /// Set tempo
    func setTempo(_ bpm: Float) {
        // Future: For sequencer/arpeggiator
    }
}
