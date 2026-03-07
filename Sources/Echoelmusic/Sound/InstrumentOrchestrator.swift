#if canImport(AVFoundation)
import Foundation
import AVFoundation
import Combine
import Observation

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
@Observable
final class InstrumentOrchestrator {

    // MARK: - Singleton

    static let shared = InstrumentOrchestrator()

    // MARK: - Published State

    var currentInstrument: UniversalSoundLibrary.Instrument?
    var currentSynthEngine: UniversalSoundLibrary.SynthEngine?
    var isPlaying: Bool = false
    var activeVoices: Int = 0

    // MARK: - Audio Engine

    private(set) var isEngineReady: Bool = false
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

        log.audio("✅ InstrumentOrchestrator: Initialized")
        log.audio("🎹 Available Instruments: \(soundLibrary.availableInstruments.count)")
        log.audio("🎛️ Synthesis Engines: \(soundLibrary.availableSynthEngines.count)")
    }

    deinit {
        // KRITISCH: NotificationCenter Observer entfernen um Memory Leak zu verhindern
        NotificationCenter.default.removeObserver(self)
        audioEngine?.stop()
        cancellables.removeAll()
    }

    // MARK: - Audio Engine Setup

    private func setupAudioEngine() {
        // Ensure AVAudioSession is configured before creating AVAudioEngine.
        // On first launch the session may not be active yet (e.g. mic permission pending).
        if !AudioConfiguration.isSessionConfigured {
            do {
                try AudioConfiguration.configureAudioSession()
            } catch {
                log.warning("InstrumentOrchestrator: AVAudioSession not ready, deferring engine start: \(error)", category: .audio)
                return
            }
        }

        audioEngine = AVAudioEngine()

        guard let engine = audioEngine else {
            log.audio("InstrumentOrchestrator: Failed to create AVAudioEngine")
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
            log.audio("InstrumentOrchestrator: Failed to create audio format")
            return
        }
        engine.connect(player, to: mixer, format: format)

        // Start the engine
        do {
            try engine.start()
            isPlaying = true
            isEngineReady = true
            log.audio("🎵 InstrumentOrchestrator: Audio engine started")
        } catch let engineError {
            isEngineReady = false
            log.error("InstrumentOrchestrator: Failed to start audio engine: \(engineError)", category: .audio)
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
            log.audio("🎹 Selected: \(instrument.name)")
        }
    }

    /// Select instrument by index
    func selectInstrument(index: Int) {
        guard index < soundLibrary.availableInstruments.count else { return }
        currentInstrument = soundLibrary.availableInstruments[index]
        log.audio("🎹 Selected: \(currentInstrument?.name ?? "Unknown")")
    }

    /// Select synthesis engine
    func selectSynthEngine(_ type: UniversalSoundLibrary.SynthEngine.SynthType) {
        if let engine = soundLibrary.availableSynthEngines.first(where: { $0.type == type }) {
            currentSynthEngine = engine
            log.audio("🎛️ Synth Engine: \(engine.name)")
        }
    }

    // MARK: - Note Playback

    /// Play a MIDI note
    func noteOn(midiNote: Int, velocity: Float = 0.8) {
        guard isEngineReady, playerNode != nil else {
            log.warning("InstrumentOrchestrator: Audio engine not ready, ignoring noteOn", category: .audio)
            return
        }

        guard let synthEngine = currentSynthEngine else {
            log.audio("⚠️ No synthesis engine selected", level: .warning)
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

            log.audio("🎵 Note On: MIDI \(midiNote) @ \(Int(velocity * 100))% velocity")
        }
    }

    /// Stop a MIDI note
    func noteOff(midiNote: Int) {
        // Mark voice as inactive (will release with envelope)
        if let index = voices.firstIndex(where: { $0.midiNote == midiNote && $0.isActive }) {
            voices[index].isActive = false
            log.audio("🎵 Note Off: MIDI \(midiNote)")
        }
    }

    /// Stop all notes
    func allNotesOff() {
        playerNode?.stop()
        voices.removeAll()
        activeVoices = 0
        log.audio("🛑 All Notes Off")
    }

    // MARK: - Drum Playback (808/909 Style)

    /// Trigger a drum sound — dedicated synthesis per drum type for authentic sound
    func triggerDrum(_ drumType: DrumType, velocity: Float = 0.8) {
        let sampleRate: Float = 48000.0
        let samples: [Float]

        switch drumType {
        case .kick:
            samples = synthesizeKick(velocity: velocity, sampleRate: sampleRate)
        case .snare:
            samples = synthesizeSnare(velocity: velocity, sampleRate: sampleRate)
        case .hiHatClosed:
            samples = synthesizeHiHat(open: false, velocity: velocity, sampleRate: sampleRate)
        case .hiHatOpen:
            samples = synthesizeHiHat(open: true, velocity: velocity, sampleRate: sampleRate)
        case .clap:
            samples = synthesizeClap(velocity: velocity, sampleRate: sampleRate)
        default:
            // Toms, cowbell, rimshot, crash, ride — use tuned physical model
            let frequency: Float
            let duration: Float
            switch drumType {
            case .tomLow: frequency = 80.0; duration = 0.4
            case .tomMid: frequency = 120.0; duration = 0.35
            case .tomHigh: frequency = 170.0; duration = 0.3
            case .cowbell: frequency = 800.0; duration = 0.25
            case .rimShot: frequency = 600.0; duration = 0.15
            case .crash: frequency = 300.0; duration = 1.5
            case .ride: frequency = 400.0; duration = 0.8
            default: frequency = 200.0; duration = 0.3
            }
            let count = Int(duration * sampleRate)
            var buf = [Float](repeating: 0, count: count)
            // Modal synthesis: two inharmonic partials + noise transient
            for i in 0..<count {
                let t = Float(i) / sampleRate
                let env = Swift.max(0, 1.0 - t / duration) * velocity
                buf[i] = (sin(2.0 * .pi * frequency * t) * 0.6
                         + sin(2.0 * .pi * frequency * 1.47 * t) * 0.3
                         + Float.random(in: -0.1...0.1) * Swift.max(0, 1.0 - t * 20.0)) * env
            }
            samples = buf
        }

        guard let buffer = createAudioBuffer(from: samples, sampleRate: Double(sampleRate)) else { return }
        playerNode?.scheduleBuffer(buffer, at: nil, options: [])
        if playerNode?.isPlaying == false {
            playerNode?.play()
        }
        log.audio("Drum: \(drumType) @ \(Int(velocity * 100))%")
    }

    // MARK: - Dedicated Drum Synthesis

    /// 808-style kick: sine wave with exponential pitch sweep
    private func synthesizeKick(velocity: Float, sampleRate: Float) -> [Float] {
        let duration: Float = 0.5
        let count = Int(duration * sampleRate)
        var buffer = [Float](repeating: 0, count: count)

        let startFreq: Float = 150.0  // Click transient
        let endFreq: Float = 45.0     // Fundamental body

        for i in 0..<count {
            let t = Float(i) / sampleRate
            // Exponential frequency sweep — pitch drops fast then settles
            let freq = endFreq + (startFreq - endFreq) * exp(-t * 25.0)
            // Phase accumulation for clean sweep
            let phase = 2.0 * .pi * (endFreq * t + (startFreq - endFreq) / 25.0 * (1.0 - exp(-t * 25.0)))
            // Amplitude: fast attack, medium decay
            let amp = exp(-t * 5.0) * velocity
            // Soft saturation for warmth
            let raw = sin(phase) * amp
            buffer[i] = tanh(raw * 1.5) * 0.9
        }

        return buffer
    }

    /// Snare: tuned body (sine + triangle) + noise burst through bandpass
    private func synthesizeSnare(velocity: Float, sampleRate: Float) -> [Float] {
        let duration: Float = 0.3
        let count = Int(duration * sampleRate)
        var buffer = [Float](repeating: 0, count: count)

        for i in 0..<count {
            let t = Float(i) / sampleRate

            // Tonal body — two sine partials with pitch drop
            let bodyFreq: Float = 180.0 + 40.0 * exp(-t * 30.0)
            let body = (sin(2.0 * .pi * bodyFreq * t) * 0.5
                       + sin(2.0 * .pi * bodyFreq * 1.5 * t) * 0.2)
                       * exp(-t * 15.0)

            // Noise component — bandpass filtered white noise for snare wire
            let noise = Float.random(in: -1.0...1.0) * exp(-t * 10.0) * 0.7

            buffer[i] = (body + noise) * velocity
        }

        // Bandpass the noise portion (simple 2-pass filter)
        var lp: Float = 0.0
        let lpCoeff: Float = 2.0 * sin(.pi * 8000.0 / sampleRate)
        for i in 0..<count {
            lp += lpCoeff * (buffer[i] - lp)
            buffer[i] = lp
        }

        return buffer
    }

    /// Hi-hat: filtered noise with metallic ring
    private func synthesizeHiHat(open: Bool, velocity: Float, sampleRate: Float) -> [Float] {
        let duration: Float = open ? 0.4 : 0.08
        let count = Int(duration * sampleRate)
        var buffer = [Float](repeating: 0, count: count)
        let decayRate: Float = open ? 6.0 : 40.0

        for i in 0..<count {
            let t = Float(i) / sampleRate
            // Metallic ring: sum of inharmonic frequencies (square of primes)
            let ring = sin(2.0 * .pi * 3500.0 * t) * 0.15
                     + sin(2.0 * .pi * 5200.0 * t) * 0.1
                     + sin(2.0 * .pi * 7400.0 * t) * 0.08
            // Filtered noise
            let noise = Float.random(in: -1.0...1.0) * 0.5

            buffer[i] = (noise + ring) * exp(-t * decayRate) * velocity
        }

        // Highpass filter to remove low end
        var hp: Float = 0.0
        for i in 0..<count {
            let prev = hp
            hp = 0.95 * (prev + buffer[i] - (i > 0 ? buffer[i - 1] : 0.0))
            buffer[i] = hp
        }

        return buffer
    }

    /// Clap: layered noise bursts with pre-delay
    private func synthesizeClap(velocity: Float, sampleRate: Float) -> [Float] {
        let duration: Float = 0.25
        let count = Int(duration * sampleRate)
        var buffer = [Float](repeating: 0, count: count)

        // 3 micro-bursts before main clap (hand clap layering)
        let burstPositions: [Float] = [0.0, 0.012, 0.024, 0.035]
        for burstStart in burstPositions {
            let startSample = Int(burstStart * sampleRate)
            let burstLength = Int(0.008 * sampleRate)
            for i in startSample..<Swift.min(startSample + burstLength, count) {
                let t = Float(i - startSample) / Float(burstLength)
                let env = (1.0 - t) * (1.0 - t)
                buffer[i] += Float.random(in: -1.0...1.0) * env * velocity * 0.4
            }
        }

        // Main clap body with bandpass character
        let mainStart = Int(0.035 * sampleRate)
        for i in mainStart..<count {
            let t = Float(i - mainStart) / sampleRate
            buffer[i] += Float.random(in: -1.0...1.0) * exp(-t * 12.0) * velocity * 0.6
        }

        // Bandpass filter for realistic frequency range
        var bp: Float = 0.0
        let bpCoeff: Float = 2.0 * sin(.pi * 2500.0 / sampleRate)
        for i in 0..<count {
            bp += bpCoeff * (buffer[i] - bp)
            buffer[i] = bp
        }

        return buffer
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

        // Stereo widening: subtle phase offset between L/R for spatial depth
        // This creates a natural "room" effect without being phasey in mono
        let stereoOffset = 12  // ~0.25ms at 48kHz — Haas-effect sweet spot
        if let leftChannel = buffer.floatChannelData?[0],
           let rightChannel = buffer.floatChannelData?[1] {
            for i in 0..<samples.count {
                leftChannel[i] = samples[i]
                // Right channel gets slightly delayed copy — creates stereo image
                let rightIndex = Swift.max(0, i - stereoOffset)
                rightChannel[i] = samples[rightIndex]
            }
        }

        return buffer
    }

    private func applyVelocityEnvelope(_ samples: [Float], velocity: Float) -> [Float] {
        var result = samples
        let sampleRate: Float = 48000.0

        // Professional ADSR with exponential curves
        let attackTime: Float = 0.015   // 15ms — fast but click-free
        let decayTime: Float = 0.3      // 300ms decay to sustain level
        let sustainLevel: Float = 0.6   // 60% sustain
        let releaseTime: Float = 0.25   // 250ms release — smooth tail

        let attackSamples = Swift.min(Int(attackTime * sampleRate), samples.count / 4)
        let decaySamples = Swift.min(Int(decayTime * sampleRate), samples.count / 3)
        let releaseSamples = Swift.min(Int(releaseTime * sampleRate), samples.count / 3)
        let sustainEnd = samples.count - releaseSamples

        for i in 0..<samples.count {
            let envelope: Float
            if i < attackSamples {
                // Exponential attack — natural rise
                let t = Float(i) / Float(attackSamples)
                envelope = t * t  // Quadratic curve, gentler onset
            } else if i < attackSamples + decaySamples {
                // Exponential decay from peak to sustain
                let t = Float(i - attackSamples) / Float(decaySamples)
                envelope = sustainLevel + (1.0 - sustainLevel) * (1.0 - t) * (1.0 - t)
            } else if i < sustainEnd {
                // Sustain with very subtle natural fade
                let sustainDuration = Float(sustainEnd - attackSamples - decaySamples)
                let t = Float(i - attackSamples - decaySamples) / Swift.max(1.0, sustainDuration)
                envelope = sustainLevel * (1.0 - t * 0.1)  // Gentle 10% fade over sustain
            } else {
                // Exponential release — smooth fade to silence
                let t = Float(i - sustainEnd) / Float(releaseSamples)
                let releaseLevel = sustainLevel * 0.9  // Start from end of sustain fade
                envelope = releaseLevel * (1.0 - t) * (1.0 - t)
            }
            result[i] *= envelope * velocity
        }

        return result
    }

    // Note: Drum envelope is now built into each dedicated drum synthesis method above

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

    // MARK: - Synth Freeze Pipeline

    /// Freeze current synth engine into EchoelSampler zones
    /// Renders the synth at multiple notes and velocity layers, creating a multi-sampled instrument
    func freezeToSampler(
        _ sampler: EchoelSampler,
        notes: [Int] = [36, 48, 60, 72, 84],
        velocityLayers: [Int] = [40, 80, 120],
        duration: Float = 2.0
    ) -> Int {
        guard let synthEngine = currentSynthEngine else {
            log.audio("InstrumentOrchestrator: No synth engine to freeze")
            return 0
        }

        let sampleRate: Float = 48000.0
        let name = currentInstrument?.name ?? synthEngine.name

        let count = sampler.freezeMultiSampled(
            render: { frameCount, frequency, velocity in
                var samples = synthEngine.synthesize(
                    frequency: frequency,
                    duration: Float(frameCount) / sampleRate,
                    sampleRate: sampleRate
                )
                let vel = Float(velocity) / 127.0
                samples = self.applyVelocityEnvelope(samples, velocity: vel)
                return samples
            },
            notes: notes,
            velocityLayers: velocityLayers,
            duration: duration,
            name: name
        )

        log.audio("InstrumentOrchestrator: Froze \(name) → \(count) sampler zones (\(notes.count) notes x \(velocityLayers.count) layers)")
        return count
    }

    /// Quick freeze: render current synth at a single note into one sampler zone
    func quickFreeze(_ sampler: EchoelSampler, note: Int = 60, duration: Float = 2.0) -> Int {
        guard let synthEngine = currentSynthEngine else { return -1 }

        let sampleRate: Float = 48000.0
        let frequency = midiNoteToFrequency(note)
        let name = currentInstrument?.name ?? synthEngine.name

        return sampler.freezeSynthToZone(
            render: { frameCount in
                synthEngine.synthesize(
                    frequency: frequency,
                    duration: Float(frameCount) / sampleRate,
                    sampleRate: sampleRate
                )
            },
            duration: duration,
            rootNote: note,
            name: "\(name)_frozen",
            loopEnabled: true
        )
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

// Note: AudioEngine filter/effect methods are defined in AudioEngine.swift
#endif
