import Foundation
import AVFoundation
import Accelerate

/// Generates binaural beats for auditory brainwave entrainment
///
/// Binaural beats work by playing two slightly different frequencies (one per ear),
/// causing the brain to perceive a "beat" at the difference frequency.
/// Research suggests potential effects on brainwave states.
///
/// References:
/// - Oster, G. (1973). "Auditory beats in the brain", Scientific American
/// - Wahbeh et al. (2007). "Binaural Beat Technology in Humans"
/// - Note: Effects vary by individual; not a medical treatment
@MainActor
class BinauralBeatGenerator: ObservableObject {

    // MARK: - Audio Mode

    /// Audio output mode based on device capabilities
    enum AudioMode {
        case binaural     // Stereo - different frequency per ear (requires headphones)
        case isochronic   // Mono - pulsed tone (works on speakers, spatial audio, etc.)
    }

    // MARK: - Brainwave Presets

    /// Brainwave state configurations based on EEG research
    /// Reference: Niedermeyer & da Silva, "Electroencephalography"
    enum BrainwaveState: String, CaseIterable {
        case delta      // 0.5-4 Hz - Deep sleep
        case theta      // 4-8 Hz - Drowsiness, light sleep
        case alpha      // 8-13 Hz - Relaxed wakefulness
        case beta       // 13-30 Hz - Active thinking
        case gamma      // 30-100 Hz - Higher cognitive functions

        /// Beat frequency in Hz for this brainwave state
        var beatFrequency: Float {
            switch self {
            case .delta: return 2.0
            case .theta: return 6.0
            case .alpha: return 10.0
            case .beta: return 20.0
            case .gamma: return 40.0
            }
        }

        /// Human-readable description (based on EEG research)
        var description: String {
            switch self {
            case .delta: return "Deep Sleep (0.5-4 Hz)"
            case .theta: return "Light Sleep/Drowsy (4-8 Hz)"
            case .alpha: return "Relaxed Wakefulness (8-13 Hz)"
            case .beta: return "Active Thinking (13-30 Hz)"
            case .gamma: return "Higher Cognition (30+ Hz)"
            }
        }
    }


    // MARK: - Configuration

    /// Carrier frequency in Hz (the base tone)
    /// Default: 440 Hz (ISO 16 standard pitch, A4)
    /// Note: 432 Hz has no scientific basis for special properties
    private(set) var carrierFrequency: Float = 440.0

    /// Beat frequency in Hz (difference between left and right ear)
    /// This is what entrains the brain to the target brainwave state
    private(set) var beatFrequency: Float = 10.0  // Alpha by default

    /// Amplitude (volume) of the generated tone (0.0 - 1.0)
    private(set) var amplitude: Float = 0.3

    /// Sample rate for audio generation
    private let sampleRate: Double = 44100.0

    /// Current audio mode (automatically detected)
    @Published private(set) var audioMode: AudioMode = .binaural

    // MARK: - Gradual Onset Configuration (Brainwave Safety)

    /// Whether gradual onset/offset is enabled (recommended for safety)
    /// Gradual frequency ramping prevents sudden brainwave state changes
    /// which can cause disorientation or discomfort
    @Published var gradualOnsetEnabled: Bool = true

    /// Duration for gradual onset in seconds (default: 5 minutes = 300 seconds)
    /// Research suggests 3-5 minutes for comfortable brainwave entrainment
    var gradualOnsetDuration: TimeInterval = 300.0

    /// Duration for gradual offset when stopping (default: 2 minutes)
    var gradualOffsetDuration: TimeInterval = 120.0

    /// Starting frequency for gradual onset (Alpha/10 Hz - natural relaxed state)
    /// Most people naturally hover around alpha when eyes closed
    private let onsetStartFrequency: Float = 10.0

    /// Target beat frequency (set when configuring, ramped to during onset)
    private var targetBeatFrequency: Float = 10.0

    /// Time when playback started (for onset ramp calculation)
    private var playbackStartTime: Date?

    /// Whether currently in offset (stopping) phase
    private var isInOffsetPhase: Bool = false

    /// Time when offset phase started
    private var offsetStartTime: Date?

    /// Beat frequency when offset started (to ramp from)
    private var offsetStartFrequency: Float = 10.0

    /// Current effective beat frequency (after ramping applied)
    @Published private(set) var effectiveBeatFrequency: Float = 10.0

    /// Progress of gradual onset (0.0 = just started, 1.0 = fully ramped)
    @Published private(set) var onsetProgress: Float = 0.0


    // MARK: - Audio Components

    /// Audio engine for playback
    private let audioEngine = AVAudioEngine()

    /// Player node for left channel
    private let leftPlayerNode = AVAudioPlayerNode()

    /// Player node for right channel
    private let rightPlayerNode = AVAudioPlayerNode()

    /// Audio format (stereo, 44.1 kHz)
    private lazy var audioFormat: AVAudioFormat = {
        AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
    }()

    /// Buffer size for generation (larger = less CPU, more latency)
    private let bufferSize: AVAudioFrameCount = 4096

    /// Whether the generator is currently playing
    private(set) var isPlaying: Bool = false

    /// Timer for continuous buffer generation
    private var bufferTimer: Timer?


    // MARK: - Initialization

    init() {
        setupAudioEngine()
    }

    deinit {
        stop()
    }


    // MARK: - Public Methods

    /// Configure the binaural beat parameters
    /// - Parameters:
    ///   - carrier: Base frequency in Hz (typically 200-500 Hz, default 432 Hz)
    ///   - beat: Beat frequency in Hz (0.5-40 Hz for different brainwave states)
    ///   - amplitude: Volume (0.0-1.0, default 0.3)
    func configure(carrier: Float, beat: Float, amplitude: Float) {
        self.carrierFrequency = carrier
        self.targetBeatFrequency = beat
        self.beatFrequency = beat
        self.amplitude = min(max(amplitude, 0.0), 1.0)  // Clamp to 0-1
    }

    /// Configure using a brainwave preset
    /// - Parameter state: Predefined brainwave state (delta, theta, alpha, beta, gamma)
    func configure(state: BrainwaveState) {
        self.targetBeatFrequency = state.beatFrequency
        self.beatFrequency = state.beatFrequency
        // Keep current carrier frequency and amplitude
        print("🧠 Configured for \(state.rawValue) state: \(state.description)")
    }

    /// Set beat frequency dynamically based on HRV coherence
    /// Maps coherence (0-100) to optimal brainwave states:
    /// - Low coherence (0-40) → Alpha (10 Hz) for relaxation
    /// - Medium coherence (40-60) → Alpha-Beta transition (15 Hz)
    /// - High coherence (60-100) → Beta (20 Hz) for peak focus
    ///
    /// - Parameter coherence: HRV coherence score (0-100)
    func setBeatFrequencyFromHRV(coherence: Double) {
        var newTarget: Float
        if coherence < 40 {
            // Low coherence: promote relaxation
            newTarget = 10.0  // Alpha
        } else if coherence < 60 {
            // Medium coherence: transition to focus
            newTarget = 15.0  // Alpha-Beta blend
        } else {
            // High coherence: maintain focus
            newTarget = 20.0  // Beta
        }

        // Smooth transition for HRV-driven changes (avoid sudden jumps)
        if gradualOnsetEnabled && isPlaying {
            // Gradual transition over 30 seconds for HRV-driven changes
            targetBeatFrequency = newTarget
            // The effective frequency will be updated by updateEffectiveFrequency()
        } else {
            targetBeatFrequency = newTarget
            beatFrequency = newTarget
        }
        print("💓 HRV coherence \(Int(coherence)) → target \(newTarget) Hz beat")
    }

    /// Configure gradual onset/offset parameters
    /// - Parameters:
    ///   - enabled: Whether to enable gradual ramping
    ///   - onsetDuration: Time to ramp from start frequency to target (seconds)
    ///   - offsetDuration: Time to ramp down when stopping (seconds)
    func configureGradualOnset(enabled: Bool, onsetDuration: TimeInterval = 300, offsetDuration: TimeInterval = 120) {
        self.gradualOnsetEnabled = enabled
        self.gradualOnsetDuration = max(30, min(600, onsetDuration))  // 30s - 10min
        self.gradualOffsetDuration = max(15, min(300, offsetDuration))  // 15s - 5min
        print("🌅 Gradual onset: \(enabled ? "ON" : "OFF"), onset: \(Int(onsetDuration))s, offset: \(Int(offsetDuration))s")
    }

    /// Start generating and playing binaural/isochronic beats
    /// With gradual onset enabled, frequency ramps from alpha (10 Hz) to target over 5 minutes
    func start() {
        guard !isPlaying else { return }

        do {
            // Configure audio session for playback
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)

            // Detect audio output type and choose optimal mode
            detectAudioMode()

            // Initialize gradual onset
            if gradualOnsetEnabled {
                playbackStartTime = Date()
                isInOffsetPhase = false
                offsetStartTime = nil
                // Start at alpha frequency (natural relaxed state)
                effectiveBeatFrequency = onsetStartFrequency
                onsetProgress = 0.0
                print("🌅 Gradual onset started: \(onsetStartFrequency) Hz → \(targetBeatFrequency) Hz over \(Int(gradualOnsetDuration))s")
            } else {
                effectiveBeatFrequency = targetBeatFrequency
                onsetProgress = 1.0
            }

            // Start the audio engine
            if !audioEngine.isRunning {
                try audioEngine.start()
            }

            // Start player nodes
            leftPlayerNode.play()
            rightPlayerNode.play()

            // Schedule initial buffers
            scheduleBuffers()

            // Start timer for continuous buffer generation AND frequency ramping
            bufferTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.updateEffectiveFrequency()
                    self?.scheduleBuffers()
                }
            }

            isPlaying = true
            let modeStr = audioMode == .binaural ? "Binaural (stereo)" : "Isochronic (mono)"
            let onsetStr = gradualOnsetEnabled ? " (gradual onset)" : ""
            print("▶️ \(modeStr) beats started: \(carrierFrequency) Hz @ \(effectiveBeatFrequency) Hz\(onsetStr)")

        } catch {
            print("❌ Failed to start beats: \(error.localizedDescription)")
        }
    }

    /// Start with immediate skip to target frequency (no gradual onset)
    /// Use for short sessions or when user explicitly wants immediate effect
    func startImmediate() {
        gradualOnsetEnabled = false
        start()
    }

    /// Stop playing binaural beats
    /// With gradual offset enabled, frequency ramps down to alpha before stopping
    func stop() {
        guard isPlaying else { return }

        // If gradual offset is enabled and not already in offset phase, start gradual stop
        if gradualOnsetEnabled && !isInOffsetPhase {
            startGradualOffset()
            return
        }

        // Immediate stop (or after gradual offset complete)
        performImmediateStop()
    }

    /// Stop immediately without gradual offset
    func stopImmediate() {
        isInOffsetPhase = false
        performImmediateStop()
    }

    /// Internal method to perform immediate stop
    private func performImmediateStop() {
        // Stop timer
        bufferTimer?.invalidate()
        bufferTimer = nil

        // Stop player nodes
        leftPlayerNode.stop()
        rightPlayerNode.stop()

        // Stop engine
        audioEngine.stop()

        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false)

        // Reset state
        isPlaying = false
        isInOffsetPhase = false
        playbackStartTime = nil
        offsetStartTime = nil
        onsetProgress = 0.0

        print("⏹️ Binaural beats stopped")
    }

    /// Start gradual offset phase (ramp down to alpha before stopping)
    private func startGradualOffset() {
        isInOffsetPhase = true
        offsetStartTime = Date()
        offsetStartFrequency = effectiveBeatFrequency
        print("🌆 Gradual offset started: \(effectiveBeatFrequency) Hz → \(onsetStartFrequency) Hz over \(Int(gradualOffsetDuration))s")
    }


    // MARK: - Private Methods

    /// Update effective frequency based on gradual onset/offset progress
    /// Called every 0.5 seconds during playback
    private func updateEffectiveFrequency() {
        guard gradualOnsetEnabled else {
            effectiveBeatFrequency = targetBeatFrequency
            onsetProgress = 1.0
            return
        }

        if isInOffsetPhase {
            // Gradual offset: ramp DOWN to alpha
            guard let startTime = offsetStartTime else { return }

            let elapsed = Date().timeIntervalSince(startTime)
            let progress = Float(min(1.0, elapsed / gradualOffsetDuration))

            // Ease-out curve for natural deceleration
            let easedProgress = 1.0 - pow(1.0 - progress, 2)

            // Interpolate from offset start frequency to alpha
            effectiveBeatFrequency = offsetStartFrequency + (onsetStartFrequency - offsetStartFrequency) * easedProgress
            onsetProgress = 1.0 - progress

            // Check if offset complete
            if progress >= 1.0 {
                print("🌆 Gradual offset complete, stopping")
                performImmediateStop()
            }
        } else {
            // Gradual onset: ramp UP to target
            guard let startTime = playbackStartTime else { return }

            let elapsed = Date().timeIntervalSince(startTime)
            let progress = Float(min(1.0, elapsed / gradualOnsetDuration))

            // Ease-in-out curve for natural acceleration/deceleration
            // S-curve: 3t² - 2t³ (smoothstep)
            let easedProgress = progress * progress * (3.0 - 2.0 * progress)

            // Interpolate from alpha to target frequency
            effectiveBeatFrequency = onsetStartFrequency + (targetBeatFrequency - onsetStartFrequency) * easedProgress
            onsetProgress = progress

            if progress >= 1.0 && onsetProgress < 1.0 {
                print("🌅 Gradual onset complete: now at \(targetBeatFrequency) Hz")
            }
        }
    }

    /// Setup audio engine with stereo output
    private func setupAudioEngine() {
        // Attach player nodes to engine
        audioEngine.attach(leftPlayerNode)
        audioEngine.attach(rightPlayerNode)

        // Create mixer node to combine left and right channels
        let mixer = audioEngine.mainMixerNode

        // Connect left player to mixer (left channel)
        audioEngine.connect(leftPlayerNode, to: mixer, format: audioFormat)

        // Connect right player to mixer (right channel)
        audioEngine.connect(rightPlayerNode, to: mixer, format: audioFormat)

        // Prepare engine
        audioEngine.prepare()
    }

    /// Schedule audio buffers for continuous playback
    private func scheduleBuffers() {
        if audioMode == .binaural {
            // Binaural mode: different frequency per ear
            let leftBuffer = generateToneBuffer(frequency: leftEarFrequency)
            let rightBuffer = generateToneBuffer(frequency: rightEarFrequency)

            leftPlayerNode.scheduleBuffer(leftBuffer, completionHandler: nil)
            rightPlayerNode.scheduleBuffer(rightBuffer, completionHandler: nil)
        } else {
            // Isochronic mode: pulsed tone (same on both ears)
            let isoBuffer = generateIsochronicBuffer()

            leftPlayerNode.scheduleBuffer(isoBuffer, completionHandler: nil)
            rightPlayerNode.scheduleBuffer(isoBuffer, completionHandler: nil)
        }
    }

    /// Calculate frequency for left ear
    /// Left ear plays carrier frequency MINUS half the beat frequency
    /// Uses effectiveBeatFrequency for gradual onset/offset support
    private var leftEarFrequency: Float {
        return carrierFrequency - (effectiveBeatFrequency / 2.0)
    }

    /// Calculate frequency for right ear
    /// Right ear plays carrier frequency PLUS half the beat frequency
    /// Uses effectiveBeatFrequency for gradual onset/offset support
    private var rightEarFrequency: Float {
        return carrierFrequency + (effectiveBeatFrequency / 2.0)
    }

    /// Generate a pure sine wave tone buffer at specified frequency
    /// - Parameter frequency: Frequency in Hz
    /// - Returns: Audio buffer containing the sine wave
    private func generateToneBuffer(frequency: Float) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: bufferSize)!
        buffer.frameLength = bufferSize

        guard let channelData = buffer.floatChannelData?[0] else {
            return buffer
        }

        // Generate sine wave: y = A * sin(2π * f * t)
        let angularFrequency = 2.0 * Float.pi * frequency
        let sampleRateFloat = Float(sampleRate)

        for i in 0..<Int(bufferSize) {
            let time = Float(i) / sampleRateFloat
            let phase = angularFrequency * time
            channelData[i] = amplitude * sin(phase)
        }

        return buffer
    }

    /// Apply smooth fade-in envelope to prevent clicks
    /// - Parameter buffer: Audio buffer to apply envelope to
    private func applyFadeIn(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }

        let fadeLength = min(Int(bufferSize) / 10, 441)  // 10ms fade

        for i in 0..<fadeLength {
            let envelope = Float(i) / Float(fadeLength)
            channelData[i] *= envelope
        }
    }

    /// Apply smooth fade-out envelope to prevent clicks
    /// - Parameter buffer: Audio buffer to apply envelope to
    private func applyFadeOut(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }

        let fadeLength = min(Int(bufferSize) / 10, 441)  // 10ms fade
        let startIndex = Int(bufferSize) - fadeLength

        for i in 0..<fadeLength {
            let envelope = 1.0 - (Float(i) / Float(fadeLength))
            channelData[startIndex + i] *= envelope
        }
    }

    /// Generate isochronic tone buffer (pulsed carrier tone at beat frequency)
    /// Works on mono speakers, Bluetooth, spatial audio - no stereo required
    /// Uses effectiveBeatFrequency for gradual onset/offset support
    /// - Returns: Audio buffer containing pulsed tone
    private func generateIsochronicBuffer() -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: bufferSize)!
        buffer.frameLength = bufferSize

        guard let channelData = buffer.floatChannelData?[0] else {
            return buffer
        }

        // Generate carrier tone with amplitude modulation at beat frequency
        let carrierAngularFreq = 2.0 * Float.pi * carrierFrequency
        let pulseAngularFreq = 2.0 * Float.pi * effectiveBeatFrequency  // Use effective frequency
        let sampleRateFloat = Float(sampleRate)

        for i in 0..<Int(bufferSize) {
            let time = Float(i) / sampleRateFloat

            // Carrier sine wave
            let carrier = sin(carrierAngularFreq * time)

            // Pulse envelope (square wave smoothed with sine for clicks reduction)
            // Converts -1...1 sine to 0...1 pulse
            let pulseEnvelope = (sin(pulseAngularFreq * time) + 1.0) / 2.0

            // Modulate carrier with pulse
            channelData[i] = amplitude * carrier * pulseEnvelope
        }

        return buffer
    }

    /// Detect optimal audio mode based on current output route
    /// ONLY headphones → Binaural (requires isolated left/right channels)
    /// Everything else → Isochronic (speakers, Bluetooth, spatial audio, club systems)
    ///
    /// Why: Binaural beats require each ear to receive ONLY its designated frequency.
    /// Regular stereo speakers fail because both speakers reach both ears (crosstalk).
    /// Even in clubs with stereo systems, the sound mixes in the room.
    private func detectAudioMode() {
        let audioSession = AVAudioSession.sharedInstance()
        let currentRoute = audioSession.currentRoute

        // Check output ports - be conservative, only wired/BT headphones get binaural
        var hasIsolatedHeadphones = false
        for output in currentRoute.outputs {
            let portType = output.portType

            // Only wired headphones or Bluetooth headphones (not speakers!)
            if portType == .headphones ||
               portType == .bluetoothHFP ||  // Phone calls (headsets)
               portType == .bluetoothLE {     // AirPods, modern BT headphones
                hasIsolatedHeadphones = true
                break
            }

            // Explicitly exclude cases that can't do binaural:
            // - .builtInSpeaker (phone speaker)
            // - .bluetoothA2DP (could be speaker or headphones - assume speaker for safety)
            // - .airPlay (wireless speakers)
            // - Any other speaker type
        }

        // Set mode based on output
        if hasIsolatedHeadphones {
            audioMode = .binaural
            print("🎧 Isolated headphones detected → Binaural mode (true stereo)")
        } else {
            audioMode = .isochronic
            print("🔊 Speaker/Open-air detected → Isochronic mode (mono pulsed, works anywhere)")
        }
    }
}
