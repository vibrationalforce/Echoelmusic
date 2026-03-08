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

    /// Bio-reactive polyphonic DDSP synth for live performance
    let bioSynth: EchoelPolyDDSP

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
        self.bioSynth = EchoelPolyDDSP(harmonicCount: 32, sampleRate: 48000)
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

                // Re-register observation first (one-shot pattern)
                self.observeAudioLevel(micManager)

                // Throttle to ~60Hz — skip processing if too soon
                let now = CFAbsoluteTimeGetCurrent()
                guard now - self.lastBioUpdate > 0.016 else { return }
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
                   let existingData = existing.floatChannelData {
                    let exL = existingData[0]
                    let exR = existingData[1]
                    vDSP_vadd(exL, 1, bioLeft, 1, exL, 1, vDSP_Length(frameCount))
                    vDSP_vadd(exR, 1, bioRight, 1, exR, 1, vDSP_Length(frameCount))
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
