import Foundation
import Combine
import AVFoundation
import Accelerate

// MARK: - Creative Workspace

/// Unified workspace bridging Audio + Video engines into one workflow.
/// BPM Grid syncs audio timing with video timeline.
@MainActor
final class EchoelCreativeWorkspace: ObservableObject {

    static let shared = EchoelCreativeWorkspace()

    // MARK: - Published State

    @Published var isPlaying: Bool = false
    @Published var globalBPM: Double = 120.0
    @Published var globalTimeSignature: TimeSignature = .fourFour

    // MARK: - Engines

    let bpmGrid: BPMGridEditEngine
    let videoEditor: VideoEditingEngine
    let proMixer: ProMixEngine
    let proSession: ProSessionEngine
    let proColor: ProColorGrading
    let loopEngine: LoopEngine

    /// Bio-reactive DDSP synth for live performance
    let bioSynth: EchoelDDSP

    /// Current bio-coherence level (0-1) — driven by mic or HealthKit
    @Published var bioCoherence: Float = 0.5

    /// Connected AudioEngine for hardware output (set via connectAudioEngine)
    private weak var audioEngine: AudioEngine?

    /// Timer that drives audio rendering during playback
    private var audioRenderTimer: Timer?

    /// Audio render buffer size in frames
    private let renderFrameCount: Int = 512

    private var cancellables = Set<AnyCancellable>()

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

        setupBridges()
        log.info("Creative Workspace initialized (DAW + Video + Bio-Reactive Synth)", category: .system)
    }

    // MARK: - Bridges

    private func setupBridges() {
        // BPM Grid → Video Timeline sync
        bpmGrid.$grid
            .map(\.bpm)
            .removeDuplicates()
            .sink { [weak self] bpm in
                self?.videoEditor.timeline.tempo = bpm
                self?.globalBPM = bpm
            }
            .store(in: &cancellables)

        // BPM Grid → beat-synced video effects
        bpmGrid.onBeat = { [weak self] beat, bar in
            guard let self = self else { return }
            for effect in self.bpmGrid.beatSyncedEffects {
                self.bpmGrid.onBeatEffect?(effect)
            }
        }

        videoEditor.timeline.tempo = bpmGrid.grid.bpm

        // Global BPM → Session Engine
        $globalBPM
            .removeDuplicates()
            .sink { [weak self] bpm in
                self?.proSession.globalBPM = bpm
            }
            .store(in: &cancellables)

        // Session BPM → Global
        proSession.$globalBPM
            .removeDuplicates()
            .sink { [weak self] bpm in
                self?.setGlobalBPM(bpm)
            }
            .store(in: &cancellables)

        // Pro Color → Video Editor
        proColor.$colorWheels
            .removeDuplicates()
            .sink { [weak self] wheels in
                guard let self else { return }
                let grade = ColorGradeEffect(
                    exposure: wheels.exposure,
                    contrast: wheels.contrast,
                    saturation: wheels.saturation,
                    temperature: wheels.temperature,
                    tint: wheels.tint
                )
                self.videoEditor.applyLiveGrade(grade)
            }
            .store(in: &cancellables)

        // BPM → Loop Engine
        $globalBPM
            .removeDuplicates()
            .sink { [weak self] bpm in
                self?.loopEngine.setTempo(bpm)
            }
            .store(in: &cancellables)

        $globalTimeSignature
            .removeDuplicates()
            .sink { [weak self] ts in
                self?.loopEngine.setTimeSignature(beats: ts.numerator, noteValue: ts.denominator)
            }
            .store(in: &cancellables)
    }

    // MARK: - Audio Engine Connection

    /// Connect the AudioEngine for hardware output.
    /// Must be called after both AudioEngine and workspace are initialized.
    func connectAudioEngine(_ engine: AudioEngine) {
        self.audioEngine = engine
        engine.connectMixer(proMixer)

        // Wire mic audio level as bio-coherence proxy
        // When HealthKit is available, this will be replaced with real HRV coherence
        engine.microphoneManager.$audioLevel
            .throttle(for: .milliseconds(50), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] level in
                guard let self else { return }
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
            }
            .store(in: &cancellables)

        log.info("AudioEngine connected to Creative Workspace (bio-reactive synth wired)", category: .audio)
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
