import AVFoundation
import Observation
import os

/// The one owner of the audio graph and the audio session. Nothing else creates an
/// `AVAudioEngine` or changes the session category.
@MainActor
@Observable
final class AudioEngine {
    private(set) var isRunning = false
    private(set) var isPlaying = false
    private(set) var lastError: String?

    let transport = TransportState()

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var clickNode: AVAudioSourceNode?
    @ObservationIgnored private let log = Logger(subsystem: "com.echoelmusic.studio", category: "audio")

    func start() {
        guard !isRunning else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)

            let output = engine.outputNode.outputFormat(forBus: 0)
            let sampleRate = output.sampleRate > 0 ? output.sampleRate : 48_000
            guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
                throw EngineError.noFormat
            }

            let renderer = ClickRenderer(state: transport, sampleRate: sampleRate)
            let node = Self.makeSourceNode(format: format, renderer: renderer)
            log.info("graph: attach click node at \(sampleRate, privacy: .public) Hz")
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            clickNode = node

            log.info("engine: start")
            try engine.start()
            isRunning = true
            lastError = nil
        } catch {
            log.error("engine: start failed — \(error.localizedDescription, privacy: .public)")
            lastError = error.localizedDescription
        }
    }

    func play() {
        guard isRunning else { return }
        transport.isPlaying.store(true, ordering: .relaxed)
        isPlaying = true
    }

    func stop() {
        transport.isPlaying.store(false, ordering: .relaxed)
        transport.rewindRequested.store(true, ordering: .releasing)
        isPlaying = false
    }

    func setTempo(_ bpm: Double) {
        transport.bpm = bpm
    }

    func setBeatsPerBar(_ beats: Int) {
        transport.beatsPerBar.store(max(1, beats), ordering: .relaxed)
    }

    func setClickEnabled(_ enabled: Bool) {
        transport.clickEnabled.store(enabled, ordering: .relaxed)
    }

    /// Built outside the main actor and with an explicitly `@Sendable` block: a closure formed
    /// inside a `@MainActor` method inherits that isolation, and the render thread would trap
    /// on the isolation check before the first sample (the legacy app's builds 2613/2618).
    nonisolated private static func makeSourceNode(format: AVAudioFormat, renderer: ClickRenderer) -> AVAudioSourceNode {
        AVAudioSourceNode(format: format) { @Sendable _, _, frameCount, bufferList in
            renderer.render(frameCount: frameCount, into: bufferList)
        }
    }

    enum EngineError: LocalizedError {
        case noFormat
        var errorDescription: String? { "No usable audio format for the output." }
    }
}
