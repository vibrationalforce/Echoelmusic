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

    private var audioEngine: AudioEngine?
    let bioSourceManager = BioSourceManager()
    private let weatherProvider = WeatherProvider()
    private var circadianClock = CircadianClock()
    private var ouraClient: OuraRingClient?

    /// DDSP synth — nonisolated(unsafe) because audio thread reads it
    nonisolated(unsafe) private let ambienceSynth = EchoelDDSP(sampleRate: 48000)

    /// Cellular automata texture layer — evolving generative texture
    nonisolated(unsafe) private let textureSynth: EchoelCellular = {
        let t = EchoelCellular(cellCount: 128, sampleRate: 48000)
        t.synthMode = .additive
        t.rule = .rule90  // Fractal — organic texture
        t.gain = 0.15     // Subtle background layer
        t.frequency = 110  // A2 base
        t.evolutionRate = 8 // Slow evolution
        return t
    }()

    /// Pointer for lock-free audio thread flag — is the soundscape actively generating?
    nonisolated(unsafe) private var _isGeneratingPtr: UnsafeMutablePointer<Bool>?

    /// Pre-allocated scratch buffers for audio render block — NO heap allocation
    nonisolated(unsafe) private var _padScratch = [Float](repeating: 0, count: 4096)
    nonisolated(unsafe) private var _texScratch = [Float](repeating: 0, count: 4096)

    /// NotificationCenter observer token for cleanup
    nonisolated(unsafe) private var routeChangeObserver: NSObjectProtocol?

    /// AVAudioSourceNode that bridges DDSP render to AVAudioEngine graph
    private var sourceNode: AVAudioSourceNode?
    private var updateTimer: Timer?
    let sessionTracker = SessionTracker()
    private var sampleCounter: Int = 0

    // MARK: - Lifecycle

    func connect(audio: AudioEngine, bio: EchoelBioEngine) {
        self.audioEngine = audio

        // Create source node with render block that pulls from DDSP
        let synth = ambienceSynth
        let texture = textureSynth
        // Capture pre-allocated scratch buffers (COW — first mutation copies once, then reuses)
        let padRef = _padScratch
        let texRef = _texScratch

        // Capture pointer to atomic flag — safe for audio thread read
        nonisolated(unsafe) let isGeneratingPtr = UnsafeMutablePointer<Bool>.allocate(capacity: 1)
        isGeneratingPtr.initialize(to: false)
        self._isGeneratingPtr = isGeneratingPtr

        let node = AVAudioSourceNode { @Sendable _, _, frameCount, audioBufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let count = min(Int(frameCount), 4096)

            // Output silence when not playing
            guard isGeneratingPtr.pointee else {
                for buffer in ablPointer {
                    guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                    memset(data, 0, count * MemoryLayout<Float>.size)
                }
                return noErr
            }

            // Use pre-allocated scratch buffers
            var pad = padRef
            var tex = texRef
            for i in 0..<count { pad[i] = 0; tex[i] = 0 }

            synth.render(buffer: &pad, frameCount: count)
            texture.render(buffer: &tex, frameCount: count)

            // Mix: pad + texture
            for buffer in ablPointer {
                guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                for i in 0..<count {
                    data[i] = pad[i] + tex[i]
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

        // Auto-sync Oura data every 10 minutes if connected
        startOuraAutoSync()

        // Monitor audio route changes for Bluetooth speakers
        setupAudioRouteMonitoring()

        log.log(.info, category: .system, "SoundscapeEngine connected — source node attached")
    }

    /// Last completed session (for saving to SwiftData)
    var lastCompletedSession: SoundscapeSession?

    func togglePlayback() {
        isPlaying.toggle()
        if isPlaying {
            ambienceSynth.amplitude = 0.6
            ambienceSynth.noteOn(frequency: circadianClock.suggestedBaseFrequency)
            _isGeneratingPtr?.pointee = true
            sessionTracker.start(
                source: bioSourceManager.primarySource,
                phase: circadianClock.currentPhase,
                weather: weatherProvider.current.condition
            )
        } else {
            _isGeneratingPtr?.pointee = false
            ambienceSynth.noteOff()
            lastCompletedSession = sessionTracker.stop(
                source: bioSourceManager.primarySource,
                phase: circadianClock.currentPhase,
                weather: weatherProvider.current.condition
            )
        }
        log.log(.info, category: .audio, "Soundscape \(isPlaying ? "playing" : "paused")")
    }

    // MARK: - Update Loop

    private func update() {
        guard isPlaying else { return }

        // 1. Update bio source manager (fuses all sources)
        bioSourceManager.update()
        let snapshot = bioSourceManager.snapshot

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
            source: snapshot.source,
            temperature: weather.temperature,
            weatherCondition: weather.condition,
            windSpeed: weather.windSpeed,
            humidity: weather.humidity,
            circadianPhase: circadian
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

        // 5. Update texture layer bio-reactivity
        textureSynth.coherence = Float(state.coherence)
        textureSynth.frequency = circadianClock.suggestedBaseFrequency * 0.5 // One octave below pad

        // 6. Apply weather modulation
        applyWeatherModulation(weather)

        // 6. Apply circadian modulation
        applyCircadianModulation(circadian)

        // 7. Record bio sample for session history (~1Hz, every 60th frame)
        sampleCounter += 1
        if sampleCounter >= 60 {
            sampleCounter = 0
            sessionTracker.recordSample(
                hr: state.heartRate,
                hrv: state.hrv,
                coherence: state.coherence
            )
        }
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

    // MARK: - Oura Auto-Sync

    private var ouraTimer: Timer?

    private func startOuraAutoSync() {
        guard ouraClient != nil else { return }
        // Initial sync
        Task { await refreshOuraData() }
        // Then every 10 minutes
        ouraTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshOuraData()
            }
        }
        log.log(.info, category: .system, "Oura auto-sync started (10 min interval)")
    }

    // MARK: - Audio Route Monitoring

    /// Current audio output device name
    var audioOutputName: String = "Speaker"

    private func setupAudioRouteMonitoring() {
        #if canImport(AVFoundation) && !os(macOS)
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateAudioRoute()
            }
        }
        updateAudioRoute()
        #endif
    }

    private func updateAudioRoute() {
        #if canImport(AVFoundation) && !os(macOS)
        let route = AVAudioSession.sharedInstance().currentRoute
        if let output = route.outputs.first {
            audioOutputName = output.portName
            let isBluetooth = output.portType == .bluetoothA2DP
                || output.portType == .bluetoothLE
                || output.portType == .bluetoothHFP
            if isBluetooth {
                log.log(.info, category: .audio, "Bluetooth audio: \(output.portName)")
            }
        } else {
            audioOutputName = "Speaker"
        }
        #endif
    }

    nonisolated deinit {
        _isGeneratingPtr?.deinitialize(count: 1)
        _isGeneratingPtr?.deallocate()
        if let observer = routeChangeObserver {
            NotificationCenter.default.removeObserver(observer)
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
