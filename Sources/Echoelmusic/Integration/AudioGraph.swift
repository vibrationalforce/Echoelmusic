//
//  AudioGraph.swift
//  Echoelmusic
//
//  Audio Graph Integration Manager
//  Connects: Instruments → Effects → Mixer → Master Output
//

import AVFoundation
import Accelerate

// MARK: - Audio Graph Manager

@MainActor
class AudioGraph: ObservableObject {
    static let shared = AudioGraph()

    // Audio engine
    private let engine = AVAudioEngine()

    // Audio format (48kHz, stereo, Float32)
    private lazy var audioFormat: AVAudioFormat = {
        AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)!
    }()

    // Connected systems
    weak var mixer: CompleteMixerSystem?
    weak var effectChain: EffectChain?
    private var instrumentNodes: [UUID: AVAudioSourceNode] = [:]

    // Master output
    private let masterNode = AVAudioMixerNode()

    // State
    @Published var isRunning: Bool = false
    @Published var currentSampleRate: Double = 48000
    @Published var currentBufferSize: AVAudioFrameCount = 256

    private init() {
        setupAudioEngine()
    }

    // MARK: - Setup

    private func setupAudioEngine() {
        // Attach master mixer
        engine.attach(masterNode)

        // Connect master to output
        engine.connect(masterNode, to: engine.mainMixerNode, format: audioFormat)

        // Configure audio session (iOS)
        #if os(iOS)
        configureAudioSession()
        #endif
    }

    #if os(iOS)
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setPreferredSampleRate(48000)
            try session.setPreferredIOBufferDuration(256.0 / 48000.0)  // 256 samples @ 48kHz
            try session.setActive(true)

            currentSampleRate = session.sampleRate
            currentBufferSize = AVAudioFrameCount(session.sampleRate * session.ioBufferDuration)

            print("✅ Audio session configured:")
            print("   Sample rate: \(currentSampleRate) Hz")
            print("   Buffer size: \(currentBufferSize) samples")
            print("   Latency: \(Double(currentBufferSize) / currentSampleRate * 1000.0) ms")

        } catch {
            print("❌ Failed to configure audio session: \(error)")
        }
    }
    #endif

    // MARK: - Start/Stop

    func start() throws {
        guard !isRunning else { return }

        engine.prepare()
        try engine.start()
        isRunning = true

        print("✅ Audio graph started")
    }

    func stop() {
        guard isRunning else { return }

        engine.stop()
        isRunning = false

        print("⏹️ Audio graph stopped")
    }

    // MARK: - Instrument Integration

    /// Register instrument (sampler) as audio source
    func registerInstrument(_ sampler: ProfessionalSampler, id: UUID) {
        // Create AVAudioSourceNode for sampler
        let sourceNode = AVAudioSourceNode(format: audioFormat) { [weak sampler] _, _, frameCount, audioBufferList in
            guard let sampler = sampler else { return kAudioUnitErr_NoConnection }

            // Render sampler audio
            let (leftSamples, rightSamples) = sampler.renderAudio(frameCount: Int(frameCount))

            guard leftSamples.count == frameCount, rightSamples.count == frameCount else {
                return kAudioUnitErr_InvalidParameter
            }

            // Copy to audio buffer list
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard ablPointer.count >= 2 else { return kAudioUnitErr_FormatNotSupported }

            // Left channel
            if let leftBuffer = ablPointer[0].mData {
                let leftDst = leftBuffer.assumingMemoryBound(to: Float.self)
                memcpy(leftDst, leftSamples, Int(frameCount) * MemoryLayout<Float>.stride)
            }

            // Right channel
            if let rightBuffer = ablPointer[1].mData {
                let rightDst = rightBuffer.assumingMemoryBound(to: Float.self)
                memcpy(rightDst, rightSamples, Int(frameCount) * MemoryLayout<Float>.stride)
            }

            return noErr
        }

        // Attach and connect to master
        engine.attach(sourceNode)
        engine.connect(sourceNode, to: masterNode, format: audioFormat)

        instrumentNodes[id] = sourceNode

        print("✅ Registered instrument to audio graph: \(id)")
    }

    func unregisterInstrument(id: UUID) {
        guard let node = instrumentNodes[id] else { return }

        engine.disconnectNodeOutput(node)
        engine.detach(node)
        instrumentNodes.removeValue(forKey: id)

        print("✅ Unregistered instrument from audio graph: \(id)")
    }

    // MARK: - Effect Chain Integration

    /// Install effect chain on master output
    func installEffectChain(_ effectChain: EffectChain) {
        self.effectChain = effectChain

        // Install tap on master node to process effects
        masterNode.installTap(onBus: 0, bufferSize: currentBufferSize, format: audioFormat) { [weak effectChain] buffer, time in
            guard let effectChain = effectChain else { return }

            // Process through effect chain
            let processedBuffer = effectChain.process(buffer: buffer)

            // Copy processed audio back (Note: This is demonstration - actual implementation
            // would need to route through additional nodes)
        }

        print("✅ Effect chain installed on audio graph")
    }

    /// Remove effect chain
    func removeEffectChain() {
        masterNode.removeTap(onBus: 0)
        effectChain = nil

        print("✅ Effect chain removed from audio graph")
    }

    // MARK: - Mixer Integration

    /// Connect mixer system to audio graph
    func connectMixer(_ mixer: CompleteMixerSystem) {
        self.mixer = mixer

        // The mixer would need its own audio callback to process all channels
        // This is a placeholder for the integration architecture

        print("✅ Mixer connected to audio graph")
    }

    // MARK: - Master Volume

    var masterVolume: Float {
        get { masterNode.volume }
        set { masterNode.volume = newValue }
    }

    // MARK: - Monitoring

    /// Get current output level (peak)
    func getCurrentOutputLevel() -> (left: Float, right: Float) {
        // Would need to read from output buffer
        return (0.0, 0.0)
    }

    // MARK: - Buffer Size Control

    func setBufferSize(_ bufferSize: AVAudioFrameCount) {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        let duration = Double(bufferSize) / currentSampleRate

        do {
            try session.setPreferredIOBufferDuration(duration)
            currentBufferSize = bufferSize

            print("✅ Buffer size set to \(bufferSize) samples (\(duration * 1000) ms)")
        } catch {
            print("❌ Failed to set buffer size: \(error)")
        }
        #else
        currentBufferSize = bufferSize
        #endif
    }

    func setBufferSizeForLatency(_ latencyMode: LatencyMode) {
        switch latencyMode {
        case .ultraLow:
            setBufferSize(32)   // <1ms
        case .veryLow:
            setBufferSize(64)   // ~1.3ms
        case .low:
            setBufferSize(128)  // ~2.7ms
        case .balanced:
            setBufferSize(256)  // ~5.3ms
        case .safe:
            setBufferSize(512)  // ~10.7ms
        }
    }

    enum LatencyMode {
        case ultraLow   // Professional recording
        case veryLow    // Low latency monitoring
        case low        // General recording
        case balanced   // Production work
        case safe       // Mixing, mastering
    }
}

// MARK: - Audio Engine Extension

extension AudioGraph {

    /// Get all connected audio nodes
    var connectedNodes: [AVAudioNode] {
        return Array(instrumentNodes.values)
    }

    /// Get audio engine for advanced usage
    var audioEngine: AVAudioEngine {
        return engine
    }

    /// Reset audio graph (disconnect all, then reconnect)
    func reset() throws {
        print("🔄 Resetting audio graph...")

        // Stop if running
        let wasRunning = isRunning
        if wasRunning {
            stop()
        }

        // Disconnect all instruments
        for (id, node) in instrumentNodes {
            engine.disconnectNodeOutput(node)
            engine.detach(node)
        }
        instrumentNodes.removeAll()

        // Remove effects
        masterNode.removeTap(onBus: 0)

        // Restart if was running
        if wasRunning {
            try start()
        }

        print("✅ Audio graph reset complete")
    }

    /// Get current CPU load percentage
    func getCPULoad() -> Float {
        // AVAudioEngine doesn't expose CPU load directly
        // This would need platform-specific implementation
        return 0.0
    }
}

// MARK: - Convenience Extensions

extension AudioGraph {

    /// Quick setup for recording
    func setupForRecording() throws {
        setBufferSizeForLatency(.low)
        try start()
    }

    /// Quick setup for mixing
    func setupForMixing() throws {
        setBufferSizeForLatency(.balanced)
        try start()
    }

    /// Quick setup for live performance
    func setupForLivePerformance() throws {
        setBufferSizeForLatency(.ultraLow)
        try start()
    }
}

// MARK: - Error Handling

extension AudioGraph {
    enum AudioGraphError: LocalizedError {
        case engineNotStarted
        case invalidFormat
        case instrumentNotFound(UUID)
        case connectionFailed

        var errorDescription: String? {
            switch self {
            case .engineNotStarted:
                return "Audio engine not started"
            case .invalidFormat:
                return "Invalid audio format"
            case .instrumentNotFound(let id):
                return "Instrument not found: \(id)"
            case .connectionFailed:
                return "Failed to connect audio nodes"
            }
        }
    }
}
