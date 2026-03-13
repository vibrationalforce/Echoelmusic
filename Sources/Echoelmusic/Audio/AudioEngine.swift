#if canImport(AVFoundation)
import Foundation
import AVFoundation
import Combine
import Accelerate
import Observation

/// Central audio engine for professional music production
///
/// Coordinates:
/// - Master AVAudioEngine with hardware output (Bluetooth, speakers, headphones)
/// - Audio playback and transport control
/// - Real-time mixing and effects (NodeGraph + ProMixEngine)
/// - Spatial audio with head tracking (HRTF, Ambisonics)
/// - Microphone input (for recording/monitoring)
/// - Bio-parameter mapping (HRV → spatial/effects parameters)
///
/// This class acts as the central hub for all audio processing in Echoelmusic
@MainActor
@Observable
public final class AudioEngine {

    // MARK: - Observed Properties

    /// Whether the audio engine is currently running
    var isRunning: Bool = false

    /// Whether spatial audio is enabled
    var spatialAudioEnabled: Bool = false

    /// Whether input monitoring is enabled (mic recording on play)
    var inputMonitoringEnabled: Bool = false

    /// Live master output level (0.0 - 1.0) for metering
    var masterLevel: Float = 0.0

    /// Live master output level right channel (0.0 - 1.0)
    var masterLevelR: Float = 0.0

    // MARK: - Master Audio Engine (Hardware Output)

    /// The master AVAudioEngine that connects the entire audio graph to hardware output.
    /// This is the ONLY path to speakers/headphones (Bluetooth, wired, onboard).
    /// Graph: playerNode/generators → masterMixer → mainMixerNode → outputNode → hardware
    @ObservationIgnored private let masterEngine = AVAudioEngine()

    /// Master mixer node for summing all audio sources before output
    @ObservationIgnored private let masterMixer = AVAudioMixerNode()

    /// Player node for playing back audio buffers (from ProMixEngine, clips, etc.)
    @ObservationIgnored private let masterPlayerNode = AVAudioPlayerNode()

    /// Master output volume (0.0 - 1.0)
    var masterVolume: Float = 0.85 {
        didSet { masterMixer.outputVolume = masterVolume }
    }

    // MARK: - Audio Components

    /// Microphone manager for voice/breath input
    let microphoneManager: MicrophoneManager

    /// Node graph for effects processing
    private var nodeGraph: NodeGraph?


    // MARK: - Private Properties

    /// Cancellables for Combine subscriptions
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()



    // MARK: - Initialization

    /// Convenience initializer with default MicrophoneManager
    convenience init() {
        self.init(microphoneManager: MicrophoneManager())
    }

    init(microphoneManager: MicrophoneManager) {
        self.microphoneManager = microphoneManager

        // Configure audio session for optimal performance
        do {
            try AudioConfiguration.configureAudioSession()
            AudioConfiguration.registerInterruptionHandlers()
            log.audio(AudioConfiguration.latencyStats())
        } catch {
            log.audio("⚠️  Failed to configure audio session: \(error)", level: .warning)
        }

        // Set real-time audio thread priority
        AudioConfiguration.setAudioThreadPriority()

        // Initialize node graph with default production chain (EQ → Compressor → Reverb)
        nodeGraph = NodeGraph.createProductionChain()

        // Setup master audio engine graph:
        // masterPlayerNode + masterMixer → mainMixerNode → outputNode → hardware
        setupMasterEngine()

        // Wire audio interruption callbacks so engine resumes automatically
        AudioConfiguration.onInterruptionBegan = { [weak self] in
            self?.masterEngine.pause()
            self?.isRunning = false
            log.audio("Audio interrupted — pausing engine")
        }
        AudioConfiguration.onInterruptionResume = { [weak self] in
            log.audio("Audio interruption ended — resuming engine")
            do {
                try self?.masterEngine.start()
                self?.isRunning = true
            } catch {
                log.audio("Failed to resume master engine: \(error)", level: .error)
            }
        }

        log.audio("AudioEngine initialized — master output wired to hardware")
        log.audio("   Node Graph: \(nodeGraph?.nodes.count ?? 0) nodes loaded")
        log.audio("   Master Engine: \(masterEngine.isRunning ? "Running" : "Ready")")
    }

    /// Setup the master AVAudioEngine graph that routes all audio to hardware output.
    /// This is critical — without this, no audio reaches speakers or headphones.
    private func setupMasterEngine() {
        // Attach nodes to engine
        masterEngine.attach(masterMixer)
        masterEngine.attach(masterPlayerNode)

        // Connect: playerNode → masterMixer → mainMixerNode (→ outputNode is automatic)
        let outputFormat = masterEngine.outputNode.outputFormat(forBus: 0)

        // Guard against invalid output format (0 Hz / 0 channels) — happens when
        // AVAudioSession is not yet active (first launch, mic permission pending).
        // Fall back to standard 48kHz stereo to avoid crashing on connect().
        let processingFormat: AVAudioFormat
        if outputFormat.sampleRate > 0 && outputFormat.channelCount > 0,
           let customFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: outputFormat.sampleRate,
                channels: min(outputFormat.channelCount, 2),
                interleaved: false
           ) {
            processingFormat = customFormat
        } else if let fallback48 = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2) {
            log.audio("⚠️ Output format invalid (\(outputFormat.sampleRate)Hz, \(outputFormat.channelCount)ch) — using 48kHz stereo fallback", level: .warning)
            processingFormat = fallback48
        } else if let fallback44 = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2) {
            log.audio("⚠️ All 48kHz formats failed — using 44.1kHz stereo fallback", level: .warning)
            processingFormat = fallback44
        } else {
            log.audio("CRITICAL: Cannot create any audio format — skipping engine setup", level: .error)
            return
        }

        masterEngine.connect(masterPlayerNode, to: masterMixer, format: processingFormat)
        masterEngine.connect(masterMixer, to: masterEngine.mainMixerNode, format: processingFormat)

        // Set initial volume
        masterMixer.outputVolume = masterVolume
        masterEngine.mainMixerNode.outputVolume = 1.0

        // Install metering tap on master mixer for live VU meters
        let meterFormat = masterMixer.outputFormat(forBus: 0)
        if meterFormat.sampleRate > 0 && meterFormat.channelCount > 0 {
            // CRITICAL: Tap callbacks run on the audio thread (RealtimeMessenger.mServiceQueue).
            // Under Swift 6 / iOS 26, Task { @MainActor } created on the audio thread
            // triggers dispatch_assert_queue_fail → EXC_BREAKPOINT.
            // Fix: Use DispatchQueue.main.async — bypasses Swift concurrency entirely.
            nonisolated(unsafe) weak var weakSelf = self
            masterMixer.installTap(onBus: 0, bufferSize: 1024, format: meterFormat) { buffer, _ in
                guard let channelData = buffer.floatChannelData else { return }
                let frameLength = UInt(buffer.frameLength)
                guard frameLength > 0 else { return }

                var rmsL: Float = 0
                vDSP_rmsqv(channelData[0], 1, &rmsL, vDSP_Length(frameLength))

                var rmsR: Float = 0
                if buffer.format.channelCount > 1 {
                    vDSP_rmsqv(channelData[1], 1, &rmsR, vDSP_Length(frameLength))
                } else {
                    rmsR = rmsL
                }

                let scaledL = rmsL.isNaN ? Float(0) : Swift.min(rmsL * 3.0, 1.0)
                let scaledR = rmsR.isNaN ? Float(0) : Swift.min(rmsR * 3.0, 1.0)

                DispatchQueue.main.async {
                    guard let s = weakSelf else { return }
                    let decayCoeff: Float = 0.92
                    s.masterLevel = Swift.max(scaledL, s.masterLevel * decayCoeff)
                    s.masterLevelR = Swift.max(scaledR, s.masterLevelR * decayCoeff)
                }
            }
        }

        // Prepare engine (pre-allocates buffers)
        masterEngine.prepare()
        log.audio("Master AVAudioEngine graph: playerNode → masterMixer → mainMixer → outputNode → hardware")
    }


    // MARK: - Public Methods

    /// Start the audio engine for production playback
    ///
    /// Starts the master AVAudioEngine for hardware output, then activates
    /// sub-engines (spatial, effects). Microphone input is only
    /// started when input monitoring is enabled.
    func start() {
        // Start master audio engine — this is required for ANY audio output
        if !masterEngine.isRunning {
            do {
                try masterEngine.start()
                log.audio("Master AVAudioEngine started — audio output active")
            } catch {
                log.audio("CRITICAL: Failed to start master engine: \(error)", level: .error)
                // Try reconfiguring audio session and retry once
                do {
                    try AudioConfiguration.configureAudioSession()
                    try masterEngine.start()
                    log.audio("Master AVAudioEngine started after session reconfiguration")
                } catch {
                    log.audio("CRITICAL: Master engine start failed after retry: \(error)", level: .error)
                    // Don't set isRunning — engine never started
                    return
                }
            }
        }

        // Start microphone only if input monitoring is needed
        if inputMonitoringEnabled {
            microphoneManager.startRecording()
        }

        isRunning = true
        log.audio("AudioEngine started (production mode) — output: \(currentOutputDescription)")
    }

    /// Human-readable description of the current audio output route
    private var currentOutputDescription: String {
        #if os(macOS)
        return "macOS HAL"
        #else
        let route = AVAudioSession.sharedInstance().currentRoute
        let outputs = route.outputs.map { "\($0.portName) (\($0.portType.rawValue))" }
        return outputs.isEmpty ? "No output" : outputs.joined(separator: ", ")
        #endif
    }

    /// Stop the audio engine
    func stop() {
        // Stop microphone
        microphoneManager.stopRecording()

        // Stop master player node
        masterPlayerNode.stop()

        // Pause master engine (keeps graph intact for quick restart)
        masterEngine.pause()

        // Deactivate audio session to power down audio hardware.
        // notifyOthersOnDeactivation lets other apps resume playback.
        #if canImport(AVFoundation) && !os(macOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif

        isRunning = false
        log.audio("AudioEngine stopped — master engine paused, audio session deactivated")
    }




    // MARK: - Utility Methods

    /// Get human-readable description of current state
    var stateDescription: String {
        isRunning ? "Audio engine running" : "Audio engine stopped"
    }

    /// Current audio level from microphone (0.0 - 1.0)
    var currentLevel: Float {
        microphoneManager.audioLevel
    }

    /// Current detected pitch in Hz from the microphone
    var currentPitch: Float {
        microphoneManager.currentPitch
    }

    // MARK: - Filter & Effect Control

    /// Set filter cutoff frequency
    func setFilterCutoff(_ frequency: Float) {
        nodeGraph?.setParameter(.filterCutoff, value: frequency)
    }

    /// Set filter resonance
    func setFilterResonance(_ resonance: Float) {
        nodeGraph?.setParameter(.filterResonance, value: resonance)
    }

    /// Set reverb wetness (0.0 - 1.0)
    func setReverbWetness(_ wetness: Float) {
        nodeGraph?.setParameter(.reverbWet, value: wetness)
    }

    /// Set reverb size (0.0 - 1.0)
    func setReverbSize(_ size: Float) {
        nodeGraph?.setParameter(.reverbSize, value: size)
    }

    /// Set delay time in seconds
    func setDelayTime(_ time: Float) {
        nodeGraph?.setParameter(.delayTime, value: time)
    }

    /// Set master volume (0.0 - 1.0)
    func setMasterVolume(_ volume: Float) {
        nodeGraph?.setParameter(.masterVolume, value: volume)
    }

    /// Set tempo in BPM
    func setTempo(_ bpm: Float) {
        nodeGraph?.setParameter(.tempo, value: bpm)
    }


    // MARK: - ProMixEngine Integration

    /// Optional reference to ProMixEngine for multi-channel mixing.
    /// When connected, microphone audio is routed through the mixer's
    /// channel strip processing (inserts, sends, buses, master).
    private(set) var proMixEngine: ProMixEngine?

    /// Connects a ProMixEngine instance for multi-channel mixing.
    ///
    /// Once connected, `routeAudioThroughMixer(buffer:channelID:)` can
    /// send audio from any source into a specific mixer channel for
    /// full insert chain, send, bus, and master processing.
    ///
    /// - Parameter mixer: The ProMixEngine to integrate.
    func connectMixer(_ mixer: ProMixEngine) {
        self.proMixEngine = mixer
        mixer.dspKernel.prepare()
        log.audio("ProMixEngine connected to AudioEngine (\(mixer.channels.count) channels)")
    }

    // MARK: - Master Output Playback

    /// Schedule an audio buffer for immediate playback through hardware output.
    /// This is the primary method for getting audio to speakers/headphones.
    ///
    /// - Parameter buffer: PCM audio buffer to play
    func schedulePlayback(buffer: AVAudioPCMBuffer) {
        guard masterEngine.isRunning else {
            log.audio("Cannot schedule playback — master engine not running", level: .warning)
            return
        }
        masterPlayerNode.scheduleBuffer(buffer, completionHandler: nil)
        if !masterPlayerNode.isPlaying {
            masterPlayerNode.play()
        }
    }

    /// Schedule an audio buffer for looped playback through hardware output.
    ///
    /// - Parameters:
    ///   - buffer: PCM audio buffer to loop
    ///   - loopCount: Number of times to loop (0 = infinite)
    func scheduleLoopPlayback(buffer: AVAudioPCMBuffer, loopCount: AVAudioPlayerNodeBufferOptions = .loops) {
        guard masterEngine.isRunning else {
            log.audio("Cannot schedule loop playback — master engine not running", level: .warning)
            return
        }
        masterPlayerNode.scheduleBuffer(buffer, at: nil, options: loopCount, completionHandler: nil)
        if !masterPlayerNode.isPlaying {
            masterPlayerNode.play()
        }
    }

    /// Process audio through ProMixEngine and output to hardware.
    /// Full chain: inputBuffers → ProMixEngine DSP → masterPlayerNode → speakers/headphones
    ///
    /// - Parameters:
    ///   - inputBuffers: Map of channelID → audio buffer
    ///   - frameCount: Number of frames to process
    func processAndOutput(inputBuffers: [UUID: AVAudioPCMBuffer], frameCount: Int) {
        guard let mixer = proMixEngine else { return }
        let outputBuffer = mixer.processAudioBlock(inputBuffers: inputBuffers, frameCount: frameCount)
        schedulePlayback(buffer: outputBuffer)
    }

    /// Routes an audio buffer through a specific ProMixEngine channel.
    ///
    /// The buffer flows through the channel's insert chain, volume/pan,
    /// sends to aux buses, and into the master output.
    ///
    /// - Parameters:
    ///   - buffer: Input audio buffer (stereo PCM).
    ///   - channelID: The mixer channel to route through.
    /// - Returns: The processed master output buffer, or nil if no mixer is connected.
    func routeAudioThroughMixer(buffer: AVAudioPCMBuffer, channelID: UUID) -> AVAudioPCMBuffer? {
        guard let mixer = proMixEngine else { return nil }
        return mixer.processAudioBlock(
            inputBuffers: [channelID: buffer],
            frameCount: Int(buffer.frameLength)
        )
    }

}
#endif
