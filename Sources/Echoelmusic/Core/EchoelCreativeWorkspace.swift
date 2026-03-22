#if canImport(AVFoundation)
import Foundation
import AVFoundation
import Accelerate
import Observation

// MARK: - Creative Workspace

/// Unified workspace bridging Audio + Video engines into one workflow.
/// BPM Grid syncs audio timing with video timeline.
@preconcurrency @MainActor
@Observable
final class EchoelCreativeWorkspace {

    @MainActor static let shared = EchoelCreativeWorkspace()

    // MARK: - Published State

    var isPlaying: Bool = false
    var globalBPM: Double = 120.0
    var globalTimeSignature: TimeSignature = .fourFour

    // MARK: - Engines
    //
    // Subsystems use private(set) var + lazy initialization via deferredSetup().
    // The workspace singleton must be constructible without heavy work so that
    // views accessing EchoelCreativeWorkspace.shared don't block the first frame
    // render and trigger the iOS watchdog. Heavy engines are created in
    // deferredSetup(), called from EchoelmusicApp.task after the first frame.

    private(set) var bpmGrid: BPMGridEditEngine
    private(set) var videoEditor: VideoEditingEngine
    private(set) var proMixer: ProMixEngine
    private(set) var proSession: ProSessionEngine
    private(set) var proColor: ProColorGrading
    private(set) var loopEngine: LoopEngine

    /// Bio-reactive polyphonic DDSP synth for live performance
    private(set) var bioSynth: EchoelPolyDDSP

    #if canImport(UIKit)
    /// Stage output engine for external displays, projection mapping, AirPlay
    private(set) var stageEngine: EchoelStageEngine?
    #endif

    #if canImport(Metal)
    /// Bio-reactive visual engine — 8 modes, Metal 120fps, Hilbert bio-mapping
    private(set) var visEngine: EchoelVisEngine?
    #endif

    /// Ableton Link client for tempo sync with external devices
    private(set) var linkClient: AbletonLinkClient

    /// Adaptive audio quality engine — adjusts buffer/sample rate based on system load
    private(set) var adaptiveAudio: AdaptiveAudioEngine

    /// Step sequencer engine — pattern-based MIDI/audio sequencing
    private(set) var seqEngine: EchoelSeqEngine?

    /// DMX 512 / Art-Net lighting engine
    private(set) var luxEngine: EchoelLuxEngine?

    /// AI engine — CoreML, stem separation, generative
    private(set) var aiEngine: EchoelAIEngine?

    /// OSC network engine — UDP sync with external tools
    private(set) var oscEngine: OSCEngine?

    /// AUv3 plugin hosting engine — discover, host, route external audio units
    private(set) var interAppEngine: InterAppAudioEngine?

    /// Pro cue system — live performance cue list with GO/PAUSE/BACK
    private(set) var cueSystem: ProCueSystem?

    /// AI composer — algorithmic + Markov chain music generation
    private(set) var composerEngine: AIComposerEngine?

    #if canImport(CoreBluetooth)
    /// EEG sensor bridge — BLE device connection + FFT band extraction
    private(set) var eegBridge: EEGSensorBridge?
    #endif

    /// Oura Ring REST client — sleep, readiness, activity metrics
    private(set) var ouraClient: OuraRingClient?

    #if canImport(Network)
    /// Cross-device sync protocol — Bonjour discovery, clock sync, state relay
    private(set) var syncProtocol: EchoelSyncProtocol?

    /// AES67-compatible network audio transport
    private(set) var danteTransport: DanteTransport?

    /// NDI-compatible video streaming engine
    private(set) var ndiEngine: NDISyphonEngine?
    #endif

    #if os(visionOS)
    /// visionOS immersive experience engine
    private(set) var immersiveEngine: VisionOSImmersiveEngine?
    #endif

    /// Whether deferred heavy init has completed
    private(set) var isReady: Bool = false

    /// Current bio-coherence level (0-1) — driven by EchoelBioEngine (HealthKit or mic fallback)
    var bioCoherence: Float = 0.5

    /// Bio-feedback engine — real HealthKit data or mic-level fallback
    private let bioEngine = EchoelBioEngine.shared

    /// Connected AudioEngine for hardware output (set via connectAudioEngine)
    private weak var audioEngine: AudioEngine?

    /// Timestamp for throttling bio-level observation (~60Hz max)
    private var lastBioUpdate: CFAbsoluteTime = 0

    /// Timer that drives audio rendering during playback
    private var audioRenderTimer: Timer?

    /// Audio render buffer size in frames
    private let renderFrameCount: Int = 512

    /// Notification observer token for sequencer step triggers.
    /// nonisolated(unsafe) for deinit cleanup (NSObjectProtocol is not Sendable).
    @ObservationIgnored
    nonisolated(unsafe) private var sequencerObserver: (any NSObjectProtocol)?


    // MARK: - Init

    private init() {
        // LIGHTWEIGHT init — only set default values.
        // Heavy engine creation is deferred to deferredSetup() called from
        // EchoelmusicApp.task after the first frame renders. This prevents
        // the iOS watchdog from killing the app during launch.
        self.bpmGrid = BPMGridEditEngine(bpm: 120, timeSignature: .fourFour)
        self.videoEditor = VideoEditingEngine()
        self.proMixer = ProMixEngine(sampleRate: 48000, bufferSize: 256)
        self.proSession = ProSessionEngine()
        self.proColor = ProColorGrading()
        self.loopEngine = LoopEngine()
        self.bioSynth = EchoelPolyDDSP(harmonicCount: 32, sampleRate: 48000)
        self.linkClient = AbletonLinkClient()
        self.adaptiveAudio = AdaptiveAudioEngine()

        // Must be after ALL stored properties are initialized (@Observable macro requirement)
        self.loopEngine.setTempo(120.0)
        log.info("Creative Workspace lightweight init complete", category: .system)
    }

    nonisolated deinit {
        if let observer = sequencerObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Complete heavy initialization — call from .task after first frame renders.
    /// Creates StageEngine, VisEngine, default session channels, and bridges.
    func deferredSetup() {
        guard !isReady else { return }

        // Upgrade ProMixEngine to full default session with channels + aux buses
        self.proMixer = ProMixEngine.defaultSession()
        self.proSession = ProSessionEngine.defaultSession()

        #if canImport(UIKit)
        self.stageEngine = EchoelStageEngine.shared
        #endif
        #if canImport(Metal)
        self.visEngine = EchoelVisEngine.shared
        #endif

        // Initialize remaining EchoelTools engines
        self.seqEngine = EchoelSeqEngine.shared
        self.luxEngine = EchoelLuxEngine.shared
        self.aiEngine = EchoelAIEngine.shared
        self.oscEngine = OSCEngine.shared

        // Initialize new engines (feature matrix completion)
        self.interAppEngine = InterAppAudioEngine.shared
        self.cueSystem = ProCueSystem.shared
        self.composerEngine = AIComposerEngine.shared

        #if canImport(CoreBluetooth)
        self.eegBridge = EEGSensorBridge.shared
        #endif
        self.ouraClient = OuraRingClient.shared

        #if canImport(Network)
        self.syncProtocol = EchoelSyncProtocol.shared
        self.danteTransport = DanteTransport.shared
        self.ndiEngine = NDISyphonEngine.shared
        #endif

        #if os(visionOS)
        self.immersiveEngine = VisionOSImmersiveEngine.shared
        #endif

        // Handle incoming OSC messages for external control
        self.oscEngine?.onMessageReceived = { [weak self] message in
            Task { @MainActor [weak self] in
                self?.handleOSCMessage(message)
            }
        }

        // Wire step sequencer triggers → bio-synth audio output
        sequencerObserver = NotificationCenter.default.addObserver(
            forName: .sequencerStepTriggered,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // Extract values from notification BEFORE MainActor boundary
            // to avoid sending non-Sendable Notification across isolation domains
            guard let info = notification.userInfo,
                  let channel = info["channel"] as? VisualStepSequencer.Channel,
                  let velocity = info["velocity"] as? Float else { return }
            let baseNote = 60 + channel.rawValue * 2
            MainActor.assumeIsolated {
                guard let self else { return }
                self.bioSynth.noteOn(note: baseNote, velocity: velocity)
            }
        }

        setupBridges()

        // Bio streaming is started from EchoelmusicApp.task AFTER HealthKit authorization.
        // Do NOT start here — would lock into fallback mode before auth completes.

        isReady = true
        log.info("Creative Workspace deferred setup complete (12 EchoelTools + 9 production engines)", category: .system)
    }

    // MARK: - Bridges

    private func setupBridges() {
        // BPM Grid → Video Timeline sync (initial)
        videoEditor.timeline.tempo = bpmGrid.grid.bpm

        // BPM Grid → beat-synced video effects
        bpmGrid.onBeat = { [weak self] beat, bar in
            guard let self = self else { return }
            for effect in self.bpmGrid.beatSyncedEffects {
                self.bpmGrid.onBeatEffect?(effect)
            }
        }

        // Observe BPM Grid changes
        observeGridBPM()
        // Observe session BPM changes
        observeSessionBPM()
        // Observe color wheel changes
        observeColorWheels()
        // Observe global BPM for loop engine + session
        observeGlobalBPM()
        // Observe global time signature for loop engine
        observeGlobalTimeSignature()
    }

    private func observeGridBPM() {
        withObservationTracking {
            _ = self.bpmGrid.grid.bpm
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let bpm = self.bpmGrid.grid.bpm
                self.videoEditor.timeline.tempo = bpm
                self.globalBPM = bpm
                self.observeGridBPM()
            }
        }
    }

    private func observeSessionBPM() {
        withObservationTracking {
            _ = self.proSession.globalBPM
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.setGlobalBPM(self.proSession.globalBPM)
                self.observeSessionBPM()
            }
        }
    }

    private func observeColorWheels() {
        withObservationTracking {
            _ = self.proColor.colorWheels
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let wheels = self.proColor.colorWheels
                let grade = ColorGradeEffect(
                    exposure: wheels.exposure,
                    contrast: wheels.contrast,
                    saturation: wheels.saturation,
                    temperature: wheels.temperature,
                    tint: wheels.tint
                )
                self.videoEditor.applyLiveGrade(grade)
                self.observeColorWheels()
            }
        }
    }

    private func observeGlobalBPM() {
        withObservationTracking {
            _ = self.globalBPM
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let bpm = self.globalBPM
                self.proSession.globalBPM = bpm
                self.loopEngine.setTempo(bpm)
                self.observeGlobalBPM()
            }
        }
    }

    private func observeGlobalTimeSignature() {
        withObservationTracking {
            _ = self.globalTimeSignature
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let ts = self.globalTimeSignature
                self.loopEngine.setTimeSignature(beats: ts.numerator, noteValue: ts.denominator)
                self.observeGlobalTimeSignature()
            }
        }
    }

    // MARK: - Audio Engine Connection

    /// Connect the AudioEngine for hardware output.
    /// Must be called after both AudioEngine and workspace are initialized.
    func connectAudioEngine(_ engine: AudioEngine) {
        self.audioEngine = engine
        engine.connectMixer(proMixer)

        // Wire mic audio level as bio-coherence proxy
        // When HealthKit is available, this will be replaced with real HRV coherence
        observeAudioLevel(engine.microphoneManager)

        log.info("AudioEngine connected to Creative Workspace (bio-reactive synth wired)", category: .audio)
    }

    private func observeAudioLevel(_ micManager: MicrophoneManager) {
        withObservationTracking {
            _ = micManager.audioLevel
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }

                // Re-register observation first (one-shot pattern)
                self.observeAudioLevel(micManager)

                // Throttle to ~60Hz — skip processing if too soon
                let now = CFAbsoluteTimeGetCurrent()
                guard now - self.lastBioUpdate > 0.016 else { return }
                self.lastBioUpdate = now

                // Get real bio parameters from EchoelBioEngine (HealthKit or fallback)
                let bio = self.bioEngine.audioParameters()

                // Use bio coherence if streaming, otherwise fall back to mic level
                let coherence: Float
                if self.bioEngine.isStreaming && self.bioEngine.dataSource != .fallback {
                    coherence = bio.coherence
                } else {
                    let level = micManager.audioLevel
                    coherence = self.bioCoherence * 0.85 + level * 0.15
                }
                self.bioCoherence = coherence

                // Feed bio-reactive synth with real data
                self.bioSynth.applyBioReactive(
                    coherence: coherence,
                    hrvVariability: bio.hrv,
                    heartRate: bio.heartRate / 200.0, // Normalize HR to 0-1 range
                    breathPhase: bio.breathPhase,
                    breathDepth: bio.breathDepth
                )
                // Feed bio-reactive stage visuals
                #if canImport(UIKit)
                self.stageEngine?.applyBioReactive(
                    coherence: coherence,
                    hrv: bio.hrv,
                    heartRate: bio.heartRate,
                    breathPhase: bio.breathPhase
                )
                #endif
                // Feed bio-reactive visual engine
                #if canImport(Metal)
                self.visEngine?.applyBioReactive(
                    coherence: coherence,
                    hrv: bio.hrv,
                    heartRate: bio.heartRate,
                    breathPhase: bio.breathPhase
                )
                #endif
                // Feed bio-reactive lighting engine (Art-Net/DMX)
                self.luxEngine?.applyBioReactive(
                    coherence: coherence,
                    hrv: bio.hrv,
                    heartRate: bio.heartRate,
                    breathPhase: bio.breathPhase
                )
                // Send bio data via OSC to external apps (Max/MSP, TouchDesigner, etc.)
                self.oscEngine?.sendBioData(
                    heartRate: bio.heartRate,
                    hrv: bio.hrv,
                    breathRate: Float(self.bioEngine.snapshot.breathRate),
                    breathPhase: bio.breathPhase,
                    coherence: coherence,
                    audioRMS: micManager.audioLevel,
                    audioPitch: micManager.currentPitch
                )
            }
        }
    }

    // MARK: - Actions

    /// Handle incoming OSC messages for external control
    private func handleOSCMessage(_ message: OSCMessage) {
        switch message.address {
        // Transport
        case "/echoelmusic/transport/play":
            if !isPlaying { togglePlayback() }
        case "/echoelmusic/transport/stop":
            if isPlaying { togglePlayback() }
        case "/echoelmusic/transport/bpm":
            if case .float(let bpm) = message.arguments.first {
                setGlobalBPM(Double(bpm))
            }
        // Lighting
        case "/echoelmusic/lux/blackout":
            luxEngine?.blackout()
        case "/echoelmusic/lux/master":
            if case .float(let level) = message.arguments.first {
                luxEngine?.masterDimmer = level
            }
        // Cue system
        case "/echoelmusic/cue/go":
            cueSystem?.go()
        case "/echoelmusic/cue/pause":
            cueSystem?.pause()
        case "/echoelmusic/cue/back":
            cueSystem?.back()
        // Sequencer
        case "/echoelmusic/sequencer/start":
            seqEngine?.start()
        case "/echoelmusic/sequencer/stop":
            seqEngine?.stop()
        // Visual mode
        case "/echoelmusic/visual/mode":
            if case .string(let modeName) = message.arguments.first {
                #if canImport(Metal)
                if let mode = VisualMode(rawValue: modeName) {
                    visEngine?.setMode(mode)
                }
                #endif
            }
        // Mixer levels
        case let addr where addr.hasPrefix("/echoelmusic/mixer/channel/"):
            if case .float(let level) = message.arguments.first {
                let parts = addr.split(separator: "/")
                if parts.count >= 4, let ch = Int(parts[3]), ch < proMixer.channels.count {
                    proMixer.channels[ch].volume = level
                }
            }
        default:
            break
        }
    }

    func setGlobalBPM(_ bpm: Double) {
        bpmGrid.setBPM(bpm)
        videoEditor.timeline.tempo = bpm
        globalBPM = bpm
    }

    func setGlobalTimeSignature(_ ts: TimeSignature) {
        bpmGrid.setTimeSignature(ts)
        globalTimeSignature = ts
    }

    func detectAndSyncBPM(from audioURL: URL) async {
        let result = await bpmGrid.detectBeats(from: audioURL)
        if result.confidence > 0.5 {
            globalBPM = result.bpm
            videoEditor.timeline.tempo = result.bpm
        }
    }

    func togglePlayback() {
        if isPlaying {
            isPlaying = false
            stopAudioRenderTimer()
            videoEditor.pause()
            proSession.stop()
            proMixer.isPlaying = false
            loopEngine.stopPlayback()
        } else {
            audioEngine?.start()
            isPlaying = true
            proMixer.isPlaying = true
            proSession.play()
            Task { await videoEditor.play() }
            if !loopEngine.loops.isEmpty {
                loopEngine.startPlayback()
            }
            startAudioRenderTimer()
        }
    }

    func updatePlaybackPosition(_ seconds: Double) {
        bpmGrid.updatePosition(seconds)
        videoEditor.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
    }

    // MARK: - Session ↔ Mixer Sync

    /// Sync session track parameters (volume, pan, mute, solo) to ProMixEngine channels.
    /// Called each render block so the mixer reflects the session view state.
    private func syncSessionToMixer() {
        let mixerAudioChannels = proMixer.channels.enumerated().filter {
            $0.element.type == .audio || $0.element.type == .instrument
        }

        for (sessionIndex, track) in proSession.tracks.enumerated() {
            guard sessionIndex < mixerAudioChannels.count else { break }
            let mixerIndex = mixerAudioChannels[sessionIndex].offset
            proMixer.channels[mixerIndex].volume = track.volume
            proMixer.channels[mixerIndex].pan = track.pan
            proMixer.channels[mixerIndex].mute = track.mute
            proMixer.channels[mixerIndex].solo = track.solo
        }
    }

    // MARK: - Audio Render Loop

    /// Start the audio render timer that pulls audio from ProSessionEngine
    /// and pushes it to AudioEngine for hardware output.
    ///
    /// Render rate: ~93.75 Hz at 48kHz/512 frames — well within 10ms budget.
    private func startAudioRenderTimer() {
        stopAudioRenderTimer()

        let sampleRate = proMixer.sampleRate
        let frameCount = renderFrameCount
        // Timer interval = buffer duration (e.g., 512/48000 ≈ 10.67ms)
        guard sampleRate > 0 else { return }
        let interval = Double(frameCount) / sampleRate

        // Timer fires on main run loop — already on MainActor, no Task wrapper needed
        audioRenderTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.renderAndOutputAudio(frameCount: frameCount)
            }
        }
    }

    private func stopAudioRenderTimer() {
        audioRenderTimer?.invalidate()
        audioRenderTimer = nil
    }

    /// Render one block of audio from the session + bio-synth and send to hardware.
    ///
    /// Per-track routing: Each session track renders independently through its
    /// corresponding ProMixEngine channel (insert effects, sends, bus routing, metering).
    /// Bio-synth audio is mixed into the first available instrument channel.
    ///
    /// Chain: AudioClipScheduler → per-track [Float] → AVAudioPCMBuffer per channel
    ///        → ProMixEngine.processAudioBlock() → master bus → AudioEngine.schedulePlayback()
    private func renderAndOutputAudio(frameCount: Int) {
        guard isPlaying, let audioEngine else { return }

        let sampleRate = proMixer.sampleRate

        // Sync session track parameters → mixer channels (volume, pan, mute, solo)
        syncSessionToMixer()

        // Render per-track audio from session (clips, patterns, MIDI) — NOT pre-mixed
        let trackBuffers = proSession.audioScheduler.renderAllTracks(frameCount: frameCount)

        // Render bio-reactive synth (produces audio when voices are active)
        var bioLeft = [Float](repeating: 0, count: frameCount)
        var bioRight = [Float](repeating: 0, count: frameCount)
        bioSynth.renderStereo(left: &bioLeft, right: &bioRight, frameCount: frameCount)

        let hasBio = bioLeft.contains(where: { $0 != 0 })
        guard !trackBuffers.isEmpty || hasBio else { return }

        // Stereo format for all channel buffers
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 2,
            interleaved: false
        ) else { return }

        // Build per-channel input buffers for ProMixEngine
        // Map session track indices → ProMixEngine audio channel UUIDs
        let mixerAudioChannels = proMixer.channels.filter {
            $0.type == .audio || $0.type == .instrument
        }
        var inputBuffers: [UUID: AVAudioPCMBuffer] = [:]

        for (trackIndex, monoSamples) in trackBuffers {
            guard trackIndex < mixerAudioChannels.count else { continue }
            let channelID = mixerAudioChannels[trackIndex].id

            guard let trackBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else { continue }
            trackBuffer.frameLength = AVAudioFrameCount(frameCount)
            guard let chData = trackBuffer.floatChannelData else { continue }

            // Copy mono track audio into both stereo channels
            // (pan is applied by ProMixEngine's per-channel processing)
            let count = min(monoSamples.count, frameCount)
            monoSamples.withUnsafeBufferPointer { src in
                guard let srcBase = src.baseAddress else { return }
                chData[0].update(from: srcBase, count: count)
                chData[1].update(from: srcBase, count: count)
            }

            inputBuffers[channelID] = trackBuffer
        }

        // Route bio-synth into the first instrument channel, or last audio channel
        if hasBio {
            let bioChannel = proMixer.channels.first(where: { $0.type == .instrument })
                ?? mixerAudioChannels.last
            if let bioChannelID = bioChannel?.id {
                guard let bioBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else { return }
                bioBuffer.frameLength = AVAudioFrameCount(frameCount)
                guard let bioData = bioBuffer.floatChannelData else { return }

                bioLeft.withUnsafeBufferPointer { src in
                    guard let srcBase = src.baseAddress else { return }
                    bioData[0].update(from: srcBase, count: frameCount)
                }
                bioRight.withUnsafeBufferPointer { src in
                    guard let srcBase = src.baseAddress else { return }
                    bioData[1].update(from: srcBase, count: frameCount)
                }

                // If this channel already has session audio, mix bio on top
                if let existing = inputBuffers[bioChannelID],
                   let existingData = existing.floatChannelData,
                   existing.format.channelCount >= 2 {
                    // Copy existing data to temp buffers to avoid vDSP overlapping access
                    var tempL = [Float](repeating: 0, count: frameCount)
                    var tempR = [Float](repeating: 0, count: frameCount)
                    memcpy(&tempL, existingData[0], frameCount * MemoryLayout<Float>.size)
                    memcpy(&tempR, existingData[1], frameCount * MemoryLayout<Float>.size)
                    vDSP_vadd(tempL, 1, bioLeft, 1, existingData[0], 1, vDSP_Length(frameCount))
                    vDSP_vadd(tempR, 1, bioRight, 1, existingData[1], 1, vDSP_Length(frameCount))
                } else {
                    inputBuffers[bioChannelID] = bioBuffer
                }
            }
        }

        // Process all channels through ProMixEngine
        // (per-channel inserts, sends to reverb/delay buses, bus processing, master chain)
        let processedBuffer = proMixer.processAudioBlock(
            inputBuffers: inputBuffers,
            frameCount: frameCount
        )

        // Send to hardware output
        audioEngine.schedulePlayback(buffer: processedBuffer)
    }
}
#endif
