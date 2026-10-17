import AVFoundation
import EchoelCore
import EchoelDSP
import EchoelEngine
import Observation
import os

/// The one owner of the audio graph and the audio session. Nothing else creates an
/// `AVAudioEngine` or changes the session category. The sound itself comes from
/// `EngineCore`, which this class feeds with snapshots of the project.
///
/// The input is opened only while a track is armed: the session then records, and a sink node
/// hears the interface. Every graph change writes its log line BEFORE the step, so a crash
/// mid-step leaves the step it died in on record (the legacy app's input-node crash family).
@MainActor
@Observable
final class AudioEngine {
    private(set) var isRunning = false
    private(set) var isPlaying = false
    /// The session records and the sink node hears the interface.
    private(set) var isInputOpen = false
    private(set) var lastError: String?

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var sourceNode: AVAudioSourceNode?
    @ObservationIgnored private var sinkNode: AVAudioSinkNode?
    @ObservationIgnored private var recorder: InputRecorder?
    @ObservationIgnored private var take: (url: URL, writer: TakeWriter, latency: Int64)?
    @ObservationIgnored private var drainTask: Task<Void, Never>?
    @ObservationIgnored private var core: EngineCore?
    @ObservationIgnored private var slots = SlotAssigner(capacity: 32)
    @ObservationIgnored private var generation: UInt64 = 0
    @ObservationIgnored private var project: Project?
    @ObservationIgnored private var samples: [MediaID: SampleBuffer] = [:]
    @ObservationIgnored private var clickEnabled = true
    /// The loaded Audio Unit instruments. Owned here because a unit is only valid at the rate
    /// of the graph this class builds.
    let plugins: PluginHost
    @ObservationIgnored private let log = Logger(subsystem: "com.echoelmusic.studio", category: "audio")

    init() {
        plugins = PluginHost()
        plugins.onUnitsChanged = { [weak self] in
            guard let self, let project = self.project else { return }
            self.publish(project)
        }
    }

    func start() {
        guard !isRunning else { return }
        configure(input: false)
    }

    /// Opens the input for recording, asking for microphone permission first. False when it is
    /// denied or the interface cannot be used; playback keeps running either way.
    func openInput() async -> Bool {
        if isInputOpen { return true }
        guard await AVAudioApplication.requestRecordPermission() else {
            lastError = "Echoel may not use the microphone. Allow it in Settings."
            return false
        }
        stop()
        configure(input: true)
        return isInputOpen
    }

    func closeInput() {
        guard isInputOpen else { return }
        stop()
        configure(input: false)
    }

    /// Builds the graph from scratch for playback, or playback plus input.
    private func configure(input: Bool) {
        log.info("engine: stop for configure (input \(input, privacy: .public))")
        engine.stop()
        isRunning = false
        isInputOpen = false
        if let sinkNode {
            log.info("graph: detach sink node")
            engine.detach(sinkNode)
            self.sinkNode = nil
        }
        recorder = nil
        if let sourceNode {
            log.info("graph: detach source node")
            engine.detach(sourceNode)
            self.sourceNode = nil
        }
        do {
            let session = AVAudioSession.sharedInstance()
            if input {
                log.info("session: configure playAndRecord")
                try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
            } else {
                log.info("session: configure playback")
                try session.setCategory(.playback, mode: .default, options: [])
            }
            try session.setActive(true)

            let output = engine.outputNode.outputFormat(forBus: 0)
            let sampleRate = output.sampleRate > 0 ? output.sampleRate : 48_000
            guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
                throw EngineError.noFormat
            }

            // A new output rate needs a new core; the same rate keeps the playhead and the voices.
            let current: EngineCore
            if let existing = core, existing.sampleRate == sampleRate {
                current = existing
            } else {
                current = EngineCore(sampleRate: sampleRate)
                current.setClickEnabled(clickEnabled)
                core = current
                slots = SlotAssigner(capacity: current.slotCapacity)
                isPlaying = false
                if let project { publish(project) }
            }

            let node = Self.makeSourceNode(format: format, core: current)
            log.info("graph: attach source node at \(sampleRate, privacy: .public) Hz")
            engine.attach(node)
            sourceNode = node
            log.info("graph: connect source → main mixer")
            engine.connect(node, to: engine.mainMixerNode, format: format)

            if input {
                // Connect only in the input's own format, and only when it runs at the output rate:
                // a mismatch is refused here instead of raising inside AVAudioEngine.
                let inputFormat = engine.inputNode.inputFormat(forBus: 0)
                guard inputFormat.channelCount > 0, inputFormat.sampleRate == sampleRate else {
                    throw EngineError.inputUnusable(inputFormat.sampleRate, sampleRate)
                }
                let recorder = InputRecorder(core: current, sampleRate: sampleRate)
                let sink = InputRecorder.makeSinkNode(recorder)
                log.info("graph: attach sink node, \(inputFormat.channelCount, privacy: .public) ch")
                engine.attach(sink)
                sinkNode = sink
                self.recorder = recorder
                log.info("graph: connect input → sink")
                engine.connect(engine.inputNode, to: sink, format: inputFormat)
            }

            log.info("engine: start")
            try engine.start()
            isRunning = true
            isInputOpen = input
            lastError = nil
        } catch {
            log.error("engine: configure failed — \(error.localizedDescription, privacy: .public)")
            lastError = error.localizedDescription
            // An input that cannot open must not take playback down with it.
            if input { configure(input: false) }
        }
    }

    /// Starts writing the input to `url` from the next input block.
    func beginTake(url: URL) throws {
        guard take == nil, let recorder, let core else { throw EngineError.inputClosed }
        let writer = try TakeWriter(url: url, sampleRate: core.sampleRate, ring: recorder.ring)
        let session = AVAudioSession.sharedInstance()
        let latency = Int64(((session.inputLatency + session.outputLatency) * core.sampleRate).rounded())
        take = (url, writer, Swift.max(0, latency))
        recorder.arm()
        drainTask = Task.detached(priority: .userInitiated) {
            while !Task.isCancelled {
                try? await writer.drain()
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
        log.info("record: take started")
    }

    /// Stops the take and closes its file. Nil when nothing was captured; the empty file is gone.
    func endTake() async -> RecordedTake? {
        guard let current = take, let recorder, let core else { return nil }
        take = nil
        recorder.disarm()
        drainTask?.cancel()
        await drainTask?.value
        drainTask = nil
        log.info("record: take stopped")
        let frames: Int
        do {
            frames = try await current.writer.finish()
        } catch {
            log.error("record: writing failed — \(error.localizedDescription, privacy: .public)")
            lastError = "The take could not be written."
            return nil
        }
        let firstSample = recorder.startSample
        guard frames > 0, firstSample >= 0 else {
            try? FileManager.default.removeItem(at: current.url)
            return nil
        }
        return RecordedTake(url: current.url, sampleRate: core.sampleRate, startSample: firstSample, latency: current.latency)
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
        plugins.sync(project, sampleRate: core.sampleRate)
        generation += 1
        core.publish(EngineSnapshot(plan: PlaybackPlan(compiling: project), project: project,
                                    slots: slots.slots, sampleRate: core.sampleRate, generation: generation,
                                    samples: samples, units: plugins.units, effects: plugins.chains))
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
        case inputUnusable(Double, Double)
        case inputClosed

        var errorDescription: String? {
            switch self {
            case .noFormat: "No usable audio format for the output."
            case let .inputUnusable(input, output):
                input > 0
                    ? "The input runs at \(Int(input)) Hz and the output at \(Int(output)) Hz; set both to the same rate."
                    : "No audio input is available."
            case .inputClosed: "Arm a track before recording."
            }
        }
    }
}
