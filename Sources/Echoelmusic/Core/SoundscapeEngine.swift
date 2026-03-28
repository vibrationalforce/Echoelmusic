#if canImport(SwiftUI)
import Foundation
import Observation
import Combine

/// Central hub: fuses bio data, weather, and circadian context into soundscape parameters.
/// Replaces EchoelCreativeWorkspace with a radically focused scope.
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
    private let circadianClock = CircadianClock()
    private let ambienceSynth = EchoelDDSP(sampleRate: 48000)

    private var updateTimer: Timer?

    // MARK: - Lifecycle

    func connect(audio: AudioEngine, bio: EchoelBioEngine) {
        self.audioEngine = audio
        self.bioEngine = bio

        // Start 60Hz update loop for bio → synth parameter mapping
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.update()
            }
        }

        weatherProvider.startUpdating()
        log.log(.info, category: .system, "SoundscapeEngine connected")
    }

    func togglePlayback() {
        isPlaying.toggle()
        if isPlaying {
            // Set a base frequency for ambient generation (A3 = 220Hz)
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
        ambienceSynth.applyBioReactive(
            coherence: Float(state.coherence),
            hrvVariability: Float(state.hrv),
            heartRate: Float(state.heartRate.clamped(to: 0...1)),
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
        switch phase {
        case .sleep:
            // Deep, slow, dark
            ambienceSynth.setSpectralShape(.dark)
        case .wake:
            // Gentle brightening
            ambienceSynth.setSpectralShape(.natural)
        case .active:
            // Full spectrum, responsive
            ambienceSynth.setSpectralShape(.bright)
        case .windDown:
            // Gradually darkening
            ambienceSynth.setSpectralShape(.natural)
        }
    }

    deinit {
        updateTimer?.invalidate()
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
    var source: BioDataSource = .simulated

    // Weather
    var temperature: Double = 0.5
    var weatherCondition: WeatherCondition = .clear
    var windSpeed: Double = 0.0
    var humidity: Double = 0.5

    // Circadian
    var circadianPhase: CircadianPhase = .active
}
#endif
