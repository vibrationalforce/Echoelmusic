#if canImport(AVFoundation)
import Foundation
import AVFoundation
import Observation

/// Central hub: fuses bio data, weather, and circadian context into soundscape parameters.
/// Creates an AVAudioSourceNode that renders DDSP output into the AudioEngine graph.
@MainActor @Observable
final class SoundscapeEngine {

    // MARK: - State

    var isPlaying: Bool = false

    /// Unified state driving audio synthesis
    var state: SoundscapeState = .init()

    // MARK: - Engines

    private var bioEngine: EchoelBioEngine?
    private var audioEngine: AudioEngine?
    private let weatherProvider = WeatherProvider()
    private var circadianClock = CircadianClock()
    private var ouraClient: OuraRingClient?

    /// DDSP synth — nonisolated(unsafe) because audio thread reads it
    nonisolated(unsafe) private let ambienceSynth = EchoelDDSP(sampleRate: 48000)

    /// AVAudioSourceNode that bridges DDSP render to AVAudioEngine graph
    private var sourceNode: AVAudioSourceNode?
    private var updateTimer: Timer?

    // MARK: - Lifecycle

    func connect(audio: AudioEngine, bio: EchoelBioEngine) {
        self.audioEngine = audio
        self.bioEngine = bio

        // Create source node with render block that pulls from DDSP
        let synth = ambienceSynth
        let node = AVAudioSourceNode { @Sendable _, _, frameCount, audioBufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let count = Int(frameCount)

            // Render mono from DDSP
            var monoBuffer = [Float](repeating: 0, count: count)
            synth.render(buffer: &monoBuffer, frameCount: count)

            // Copy to all output channels
            for buffer in ablPointer {
                guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                for i in 0..<count {
                    data[i] = monoBuffer[i]
                }
            }
            return noErr
        }
        self.sourceNode = node
        audio.attachSourceNode(node)

        // Start 60Hz update loop for bio → synth parameter mapping
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.update()
            }
        }

        weatherProvider.startUpdating()
        log.log(.info, category: .system, "SoundscapeEngine connected — source node attached")
    }

    func togglePlayback() {
        isPlaying.toggle()
        if isPlaying {
            ambienceSynth.amplitude = 0.6
            ambienceSynth.noteOn(frequency: 220.0)
        } else {
            ambienceSynth.noteOff()
        }
        log.log(.info, category: .audio, "Soundscape \(isPlaying ? "playing" : "paused")")
    }

    // MARK: - Update Loop

    private func update() {
        guard isPlaying, let bio = bioEngine else { return }

        // 1. Read bio snapshot
        let snapshot = bio.snapshot

        // 2. Read environmental context
        let weather = weatherProvider.current
        let circadian = circadianClock.currentPhase

        // 3. Fuse into unified state
        state = SoundscapeState(
            heartRate: snapshot.heartRate,
            hrv: snapshot.hrvNormalized,
            breathPhase: snapshot.breathPhase,
            coherence: snapshot.coherence,
            lfHfRatio: snapshot.lfHfRatio,
            temperature: weather.temperature,
            weatherCondition: weather.condition,
            windSpeed: weather.windSpeed,
            humidity: weather.humidity,
            circadianPhase: circadian,
            source: snapshot.source
        )

        // 4. Apply bio-reactive parameters to synth
        // Normalize heart rate: 40-200 BPM → 0-1
        let normalizedHR = ((state.heartRate - 40) / 160).clamped(to: 0...1)
        ambienceSynth.applyBioReactive(
            coherence: Float(state.coherence),
            hrvVariability: Float(state.hrv),
            heartRate: Float(normalizedHR),
            breathPhase: Float(state.breathPhase)
        )

        // 5. Apply weather modulation
        applyWeatherModulation(weather)

        // 6. Apply circadian modulation
        applyCircadianModulation(circadian)
    }

    // MARK: - Environmental Modulation

    private func applyWeatherModulation(_ weather: WeatherSnapshot) {
        // Temperature → reverb warmth (cold = wet/spacious, warm = dry/close)
        let reverbBlend = (1.0 - weather.temperature.clamped(to: 0...1)) * 0.6
        ambienceSynth.reverbMix = Float(reverbBlend)

        // Wind → noise floor
        let noiseFloor = weather.windSpeed.clamped(to: 0...1) * 0.15
        ambienceSynth.noiseLevel = Float(noiseFloor) + 0.1
    }

    private func applyCircadianModulation(_ phase: CircadianPhase) {
        // Spectral shape based on phase
        switch phase {
        case .sleep:
            ambienceSynth.spectralShape = .dark
        case .wake:
            ambienceSynth.spectralShape = .natural
        case .active:
            ambienceSynth.spectralShape = .bright
        case .windDown:
            ambienceSynth.spectralShape = .natural
        }

        // Adjust base frequency to circadian range
        if isPlaying {
            ambienceSynth.frequency = circadianClock.suggestedBaseFrequency
        }

        // Adjust vibrato speed to circadian modulation speed
        ambienceSynth.vibratoRate = 2.0 * phase.modulationSpeed
    }

    /// Connect Oura Ring for enhanced circadian detection
    func connectOura(_ client: OuraRingClient) {
        self.ouraClient = client
        log.log(.info, category: .system, "Oura Ring connected to SoundscapeEngine")
    }

    /// Update Oura data (call periodically, e.g. every 10 min)
    func refreshOuraData() async {
        guard let oura = ouraClient else { return }
        await oura.syncDailyData()
        circadianClock.ouraSnapshot = oura.snapshot
    }

    deinit {
        updateTimer?.invalidate()
        if let node = sourceNode {
            audioEngine?.detachSourceNode(node)
        }
    }
}

// MARK: - Unified State

struct SoundscapeState {
    // Bio
    var heartRate: Double = 72
    var hrv: Double = 0.5
    var breathPhase: Double = 0.5
    var coherence: Double = 0.5
    var lfHfRatio: Double = 1.0
    var source: BioDataSource = .fallback

    // Weather
    var temperature: Double = 0.5
    var weatherCondition: WeatherCondition = .clear
    var windSpeed: Double = 0.0
    var humidity: Double = 0.5

    // Circadian
    var circadianPhase: CircadianPhase = .active
}
#endif
