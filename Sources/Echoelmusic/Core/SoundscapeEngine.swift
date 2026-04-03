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

    // MARK: - Multi-Voice Chord Pad
    // 4 DDSP voices in musical intervals = rich meditative chord
    // User can mix levels via sliders

    /// Root voice (e.g. A2 = 110Hz)
    nonisolated(unsafe) private let voiceRoot = EchoelDDSP(sampleRate: 48000)
    /// Fifth (e.g. E3 = 165Hz, ratio 3:2)
    nonisolated(unsafe) private let voiceFifth = EchoelDDSP(sampleRate: 48000)
    /// Octave (e.g. A3 = 220Hz)
    nonisolated(unsafe) private let voiceOctave = EchoelDDSP(sampleRate: 48000)
    /// High shimmer (e.g. E4 = 330Hz, soft)
    nonisolated(unsafe) private let voiceHigh = EchoelDDSP(sampleRate: 48000)

    // User-controllable mix levels (exposed to UI via sliders)
    var mixRoot: Float = 0.40 { didSet { _mixLevels.pointee = (mixRoot, mixFifth, mixOctave, mixHigh) } }
    var mixFifth: Float = 0.25 { didSet { _mixLevels.pointee = (mixRoot, mixFifth, mixOctave, mixHigh) } }
    var mixOctave: Float = 0.20 { didSet { _mixLevels.pointee = (mixRoot, mixFifth, mixOctave, mixHigh) } }
    var mixHigh: Float = 0.10 { didSet { _mixLevels.pointee = (mixRoot, mixFifth, mixOctave, mixHigh) } }

    /// Lock-free mix levels for audio thread
    nonisolated(unsafe) private let _mixLevels: UnsafeMutablePointer<(Float, Float, Float, Float)> = {
        let p = UnsafeMutablePointer<(Float, Float, Float, Float)>.allocate(capacity: 1)
        p.initialize(to: (0.40, 0.25, 0.20, 0.10))
        return p
    }()

    /// Cellular automata texture layer — subtle background shimmer
    nonisolated(unsafe) private let textureSynth: EchoelCellular = {
        let t = EchoelCellular(cellCount: 128, sampleRate: 48000)
        t.synthMode = .additive
        t.rule = .rule90
        t.gain = 0.03       // Very quiet shimmer
        t.frequency = 55
        t.evolutionRate = 2  // Glacial
        t.smoothing = 0.8
        return t
    }()

    /// All 4 DDSP voices (for SoundDesignView access)
    var allVoices: [EchoelDDSP] { [voiceRoot, voiceFifth, voiceOctave, voiceHigh] }

    /// Configure all voices — dark trance pad (Timbaland "Cry Me A River" inspired)
    /// Minor chord, filter sweep, pulsing LFO, analog character
    private func configureVoices() {
        for voice in [voiceRoot, voiceFifth, voiceOctave, voiceHigh] {
            voice.harmonicity = 0.75       // Less pure = more analog/thick character
            voice.noiseLevel = 0.04        // Slight noise = analog warmth
            voice.spectralShape = .dark    // Dark rolloff
            voice.brightness = 0.25        // Dark but not dead
            voice.attack = 0.3             // Quick but smooth
            voice.decay = 0.5
            voice.sustain = 0.8            // Strong sustain
            voice.release = 1.5
            voice.reverbMix = 0.35         // Spacious
            voice.reverbDecay = 2.0
            voice.vibratoDepth = 0.06      // Slight detune wobble
        }
        // Individual voice character
        voiceRoot.vibratoRate = 0.15       // Very slow drift
        voiceRoot.brightness = 0.3         // Root slightly brighter

        voiceFifth.vibratoRate = 0.12      // Different drift = phasing
        voiceFifth.brightness = 0.2

        voiceOctave.vibratoRate = 0.18
        voiceOctave.brightness = 0.15      // Darker up top

        voiceHigh.vibratoRate = 0.1
        voiceHigh.brightness = 0.1         // Very dark shimmer
        voiceHigh.harmonicity = 0.65       // More texture on high voice
    }

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
        configureVoices()

        // Create source node with render block that pulls from DDSP
        let root = voiceRoot
        let fifth = voiceFifth
        let octave = voiceOctave
        let high = voiceHigh
        let texture = textureSynth
        let padRef = _padScratch
        let texRef = _texScratch
        let mixPtr = _mixLevels

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

            // Render 4 voices into scratch buffers
            var pad = padRef
            var tex = texRef
            for i in 0..<count { pad[i] = 0; tex[i] = 0 }

            // Render each voice and mix with levels
            var v1 = [Float](repeating: 0, count: count)
            var v2 = [Float](repeating: 0, count: count)
            var v3 = [Float](repeating: 0, count: count)
            var v4 = [Float](repeating: 0, count: count)
            root.render(buffer: &v1, frameCount: count)
            fifth.render(buffer: &v2, frameCount: count)
            octave.render(buffer: &v3, frameCount: count)
            high.render(buffer: &v4, frameCount: count)
            texture.render(buffer: &tex, frameCount: count)

            // Mix all voices with user-controllable levels + texture
            let mix = mixPtr.pointee
            for buffer in ablPointer {
                guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                for i in 0..<count {
                    data[i] = v1[i] * mix.0 + v2[i] * mix.1 + v3[i] * mix.2 + v4[i] * mix.3 + tex[i]
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
            let baseFreq = circadianClock.suggestedBaseFrequency
            // Minor chord: root, minor 3rd (6:5), fifth (3:2), octave (2:1)
            // Dark, moody, Timbaland-style
            voiceRoot.noteOn(frequency: baseFreq)
            voiceFifth.noteOn(frequency: baseFreq * 1.2)     // Minor third (6:5)
            voiceOctave.noteOn(frequency: baseFreq * 1.5)    // Perfect fifth (3:2)
            voiceHigh.noteOn(frequency: baseFreq * 2.0)      // Octave
            _isGeneratingPtr?.pointee = true
            sessionTracker.start(
                source: bioSourceManager.primarySource,
                phase: circadianClock.currentPhase,
                weather: weatherProvider.current.condition
            )
        } else {
            _isGeneratingPtr?.pointee = false
            voiceRoot.noteOff()
            voiceFifth.noteOff()
            voiceOctave.noteOff()
            voiceHigh.noteOff()
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
            coherence: snapshot.coherence,
            source: snapshot.source,
            temperature: weather.temperature,
            weatherCondition: weather.condition,
            windSpeed: weather.windSpeed,
            humidity: weather.humidity,
            circadianPhase: circadian
        )

        // 4. Apply bio-reactive parameters to ALL voices
        // Heart rate is PRIMARY modulation source
        let normalizedHR = ((state.heartRate - 40) / 160).clamped(to: 0...1)
        for voice in [voiceRoot, voiceFifth, voiceOctave, voiceHigh] {
            voice.applyBioReactive(
                coherence: Float(state.coherence),
                hrvVariability: Float(state.hrv),
                heartRate: Float(normalizedHR)
            )
        }

        // 5. Update texture layer
        textureSynth.coherence = Float(state.coherence)

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
        let reverbBlend = (1.0 - weather.temperature.clamped(to: 0...1)) * 0.4
        let noiseFloor = weather.windSpeed.clamped(to: 0...1) * 0.1
        for voice in [voiceRoot, voiceFifth, voiceOctave, voiceHigh] {
            voice.reverbMix = Float(reverbBlend) + 0.15
            voice.noiseLevel = Float(noiseFloor) + 0.01
        }
    }

    private func applyCircadianModulation(_ phase: CircadianPhase) {
        let shape: EchoelDDSP.SpectralShape
        switch phase {
        case .sleep:    shape = .dark
        case .wake:     shape = .natural
        case .active:   shape = .natural
        case .windDown: shape = .dark
        }

        // Update base frequency and shape for all voices
        if isPlaying {
            let baseFreq = circadianClock.suggestedBaseFrequency
            voiceRoot.frequency = baseFreq
            voiceFifth.frequency = baseFreq * 1.2     // Minor third
            voiceOctave.frequency = baseFreq * 1.5    // Fifth
            voiceHigh.frequency = baseFreq * 2.0      // Octave
        }

        for voice in [voiceRoot, voiceFifth, voiceOctave, voiceHigh] {
            voice.spectralShape = shape
        }
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
        _mixLevels.deinitialize(count: 1)
        _mixLevels.deallocate()
        if let observer = routeChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

// MARK: - Unified State

struct SoundscapeState {
    // Bio (heart rate is primary)
    var heartRate: Double = 72
    var hrv: Double = 0.5
    var coherence: Double = 0.5
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
