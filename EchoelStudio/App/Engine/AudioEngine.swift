import AVFoundation
import EchoelCore
import EchoelDSP
import EchoelEngine
import Observation
import os

/// The one owner of the audio graph and the audio session. Nothing else creates an
/// `AVAudioEngine` or changes the session category. The sound itself comes from
/// `EngineCore`, which this class feeds with snapshots of the project.
@MainActor
@Observable
final class AudioEngine {
    private(set) var isRunning = false
    private(set) var isPlaying = false
    private(set) var lastError: String?

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var sourceNode: AVAudioSourceNode?
    @ObservationIgnored private var core: EngineCore?
    @ObservationIgnored private var slots = SlotAssigner(capacity: 32)
    @ObservationIgnored private var generation: UInt64 = 0
    @ObservationIgnored private var project: Project?
    @ObservationIgnored private var samples: [MediaID: SampleBuffer] = [:]
    @ObservationIgnored private var clickEnabled = true
    @ObservationIgnored private let log = Logger(subsystem: "com.echoelmusic.studio", category: "audio")

    func start() {
        guard !isRunning else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            log.info("session: configure playback")
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)

            let output = engine.outputNode.outputFormat(forBus: 0)
            let sampleRate = output.sampleRate > 0 ? output.sampleRate : 48_000
            guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
                throw EngineError.noFormat
            }

            let core = EngineCore(sampleRate: sampleRate)
            core.setClickEnabled(clickEnabled)
            self.core = core
            if let project { publish(project) }

            let node = Self.makeSourceNode(format: format, core: core)
            log.info("graph: attach source node at \(sampleRate, privacy: .public) Hz")
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            sourceNode = node

            log.info("engine: start")
            try engine.start()
            isRunning = true
            lastError = nil
        } catch {
            log.error("engine: start failed — \(error.localizedDescription, privacy: .public)")
            lastError = error.localizedDescription
        }
    }

    /// Hands the current project to the render thread. Call on every project change; it is
    /// cheap (the note events are shared, not copied).
    func update(_ project: Project) {
        self.project = project
        publish(project)
    }

    /// The decoded audio files sampler tracks play. Republishes the current project with them.
    func setSamples(_ samples: [MediaID: SampleBuffer]) {
        self.samples = samples
        if let project { publish(project) }
    }

    func play() {
        guard let core else { return }
        core.play()
        isPlaying = true
    }

    /// Stops and returns to the start.
    func stop() {
        core?.stop()
        isPlaying = false
    }

    func setClickEnabled(_ enabled: Bool) {
        clickEnabled = enabled
        core?.setClickEnabled(enabled)
    }

    /// The playhead in samples. For a small leaf view that polls it, never a view body.
    var positionSample: Int64 { core?.positionSample ?? 0 }

    private func publish(_ project: Project) {
        guard let core else { return }
        slots.update(for: project)
        generation += 1
        core.publish(EngineSnapshot(plan: PlaybackPlan(compiling: project), project: project,
                                    slots: slots.slots, sampleRate: core.sampleRate, generation: generation,
                                    samples: samples))
    }

    /// Built outside the main actor and with an explicitly `@Sendable` block: a closure formed
    /// inside a `@MainActor` method inherits that isolation, and the render thread would trap
    /// on the isolation check before the first sample (the legacy app's builds 2613/2618).
    nonisolated private static func makeSourceNode(format: AVAudioFormat, core: EngineCore) -> AVAudioSourceNode {
        AVAudioSourceNode(format: format) { @Sendable _, _, frameCount, bufferList in
            let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
            let frames = Int(frameCount)
            guard buffers.count >= 2,
                  let left = buffers[0].mData?.assumingMemoryBound(to: Float.self),
                  let right = buffers[1].mData?.assumingMemoryBound(to: Float.self) else {
                for buffer in buffers {
                    if let data = buffer.mData { memset(data, 0, Int(buffer.mDataByteSize)) }
                }
                return noErr
            }
            core.render(frameCount: frames, left: left, right: right)
            return noErr
        }
    }

    enum EngineError: LocalizedError {
        case noFormat
        var errorDescription: String? { "No usable audio format for the output." }
    }
}
