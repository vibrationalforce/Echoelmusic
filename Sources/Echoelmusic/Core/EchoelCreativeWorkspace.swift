#if canImport(AVFoundation)
import Foundation
import AVFoundation
import Accelerate
import Observation

// MARK: - Creative Workspace

/// Unified workspace bridging Audio + Video engines into one workflow.
/// BPM Grid syncs audio timing with video timeline.
@MainActor
@Observable
final class EchoelCreativeWorkspace {

    static let shared = EchoelCreativeWorkspace()

    // MARK: - Published State

    var isPlaying: Bool = false
    var globalBPM: Double = 120.0
    var globalTimeSignature: TimeSignature = .fourFour

    // MARK: - Engines

    let bpmGrid: BPMGridEditEngine
    let videoEditor: VideoEditingEngine
    let proMixer: ProMixEngine
    let proSession: ProSessionEngine
    let proColor: ProColorGrading
    let loopEngine: LoopEngine

    /// Bio-reactive DDSP synth for live performance
    let bioSynth: EchoelDDSP

    /// Ableton Link client for tempo sync with external devices
    let linkClient: AbletonLinkClient

    /// Adaptive audio quality engine — adjusts buffer/sample rate based on system load
    let adaptiveAudio: AdaptiveAudioEngine

    /// Current bio-coherence level (0-1) — driven by mic or HealthKit
    var bioCoherence: Float = 0.5

    /// Connected AudioEngine for hardware output (set via connectAudioEngine)
    private weak var audioEngine: AudioEngine?

    /// Timestamp for throttling bio-level observation (~60Hz max)
    private var lastBioUpdate: CFAbsoluteTime = 0

    /// Timer that drives audio rendering during playback
    private var audioRenderTimer: Timer?

    /// Audio render buffer size in frames
    private let renderFrameCount: Int = 512


    // MARK: - Init

    private init() {
        self.bpmGrid = BPMGridEditEngine(bpm: 120, timeSignature: .fourFour)
        self.videoEditor = VideoEditingEngine()
        self.proMixer = ProMixEngine.defaultSession()
        self.proSession = ProSessionEngine.defaultSession()
        self.proColor = ProColorGrading()
        self.loopEngine = LoopEngine()
        self.loopEngine.setTempo(120.0)
        self.bioSynth = EchoelDDSP(harmonicCount: 32, sampleRate: 48000)
        self.linkClient = AbletonLinkClient()
        self.adaptiveAudio = AdaptiveAudioEngine()

        setupBridges()
        log.info("Creative Workspace initialized (DAW + Video + Bio-Reactive Synth)", category: .system)
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

                // Throttle to ~60Hz — halves MainActor Task dispatches
                let now = CFAbsoluteTimeGetCurrent()
                guard now - self.lastBioUpdate > 0.016 else {
                    self.observeAudioLevel(micManager)
                    return
                }
                self.lastBioUpdate = now

                let level = micManager.audioLevel
                // Smooth the level into a coherence-like signal (0-1)
                let smoothed = self.bioCoherence * 0.85 + level * 0.15
                self.bioCoherence = smoothed
                // Feed bio-reactive synth
                self.bioSynth.applyBioReactive(
                    coherence: smoothed,
                    hrvVariability: 0.5,
                    heartRate: 0.5,
                    breathPhase: 0.5
                )
                self.observeAudioLevel(micManager)
            }
        }
    }

    // MARK: - Actions

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
            videoEditor.pause()
            proSession.stop()
            proMixer.isPlaying = false
            loopEngine.stopPlayback()
            stopAudioRenderTimer()
        } else {
            audioEngine?.start()
            Task { await videoEditor.play() }
            proSession.play()
            proMixer.isPlaying = true
            if !loopEngine.loops.isEmpty {
                loopEngine.startPlayback()
            }
            startAudioRenderTimer()
        }
        isPlaying.toggle()
    }

    func updatePlaybackPosition(_ seconds: Double) {
        bpmGrid.updatePosition(seconds)
        videoEditor.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
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
        let interval = Double(frameCount) / sampleRate

        audioRenderTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.renderAndOutputAudio(frameCount: frameCount)
            }
        }
    }

    private func stopAudioRenderTimer() {
        audioRenderTimer?.invalidate()
        audioRenderTimer = nil
    }

    /// Render one block of audio from the session and send to hardware.
    /// Chain: ProSessionEngine.renderAudio() → AVAudioPCMBuffer → AudioEngine.schedulePlayback()
    private func renderAndOutputAudio(frameCount: Int) {
        guard isPlaying, let audioEngine else { return }

        // Render from session (clips, patterns, MIDI)
        guard let stereo = proSession.renderAudio(frameCount: frameCount) else { return }
        guard !stereo.left.isEmpty else { return }

        // Create AVAudioPCMBuffer from rendered Float arrays
        let sampleRate = proMixer.sampleRate
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 2,
            interleaved: false
        ) else { return }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else { return }
        buffer.frameLength = AVAudioFrameCount(frameCount)

        guard let channelData = buffer.floatChannelData else { return }

        // Copy rendered audio into buffer
        let count = min(stereo.left.count, frameCount)
        stereo.left.withUnsafeBufferPointer { src in
            guard let srcBase = src.baseAddress else { return }
            channelData[0].update(from: srcBase, count: count)
        }
        stereo.right.withUnsafeBufferPointer { src in
            guard let srcBase = src.baseAddress else { return }
            channelData[1].update(from: srcBase, count: count)
        }

        // Send to hardware output
        audioEngine.schedulePlayback(buffer: buffer)
    }
}
#endif
