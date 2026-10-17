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
    /// Output channels of the interface the graph plays on; 2 on the built-in speaker.
    private(set) var outputChannels = 2
    /// Inputs the open input delivers; 0 while it is closed.
    private(set) var inputChannels = 0

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var sourceNode: AVAudioSourceNode?
    @ObservationIgnored private var sinkNode: AVAudioSinkNode?
    @ObservationIgnored private var recorder: InputRecorder?
    @ObservationIgnored private var take: (url: URL, writer: TakeWriter, latency: Int64)?
    @ObservationIgnored private var drainTask: Task<Void, Never>?
    @ObservationIgnored private var core: EngineCore?
    @ObservationIgnored private var slots = SlotAssigner(capacity: 32)
    @ObservationIgnored private var generation: UInt64 = 0
    @ObservationIgnored private var revisions = EventRevisions()
    @ObservationIgnored private var project: Project?
    @ObservationIgnored private var samples: [MediaID: SampleBuffer] = [:]
    @ObservationIgnored private var clickEnabled = true
    @ObservationIgnored private var configurationObserver: NSObjectProtocol?
    @ObservationIgnored private var interruptionObserver: NSObjectProtocol?
    @ObservationIgnored private var resetObserver: NSObjectProtocol?
    /// The loaded Audio Unit instruments. Owned here because a unit is only valid at the rate
    /// of the graph this class builds.
    let plugins: PluginHost
    /// Where a controller's notes go; the MIDI input reads it.
    let live = LiveRouter()
    /// Sends the transport's MIDI clock to the outputs picked in the song menu.
    let clock = MIDIClockOutput()
    /// Which session clip each track plays, as the render thread reports it.
    let session = SessionState()
    @ObservationIgnored private var reportTask: Task<Void, Never>?
    /// The instrument track a controller plays. Nil: the first instrument track.
    private(set) var liveTrack: TrackID?

    func setLiveTrack(_ track: TrackID?) {
        liveTrack = track
        if let project { publish(project) }
    }
    @ObservationIgnored private let log = Logger(subsystem: "com.echoelmusic.studio", category: "audio")

    init() {
        plugins = PluginHost()
        plugins.onUnitsChanged = { [weak self] in
            guard let self, let project = self.project else { return }
            self.publish(project)
        }
        // Plugging an interface in or out stops the engine and may change its channels and rate.
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.hardwareChanged() }
        }
        // A call or Siri takes the audio away; when it ends the graph comes back by itself.
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            guard raw.flatMap(AVAudioSession.InterruptionType.init(rawValue:)) == .ended else { return }
            MainActor.assumeIsolated { self?.resume(after: "interruption ended") }
        }
        resetObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.resume(after: "media services reset") }
        }
    }

    private func resume(after reason: String) {
        guard isRunning else { return }
        log.info("engine: \(reason, privacy: .public), rebuilding")
        configure(input: isInputOpen)
    }

    /// Rebuilds the graph for the interface now attached, unless it already matches and runs.
    private func hardwareChanged() {
        guard isRunning else { return }
        let output = engine.outputNode.outputFormat(forBus: 0)
        let channels = Self.usableChannels(output.channelCount)
        log.info("engine: configuration change, \(output.channelCount, privacy: .public) ch at \(output.sampleRate, privacy: .public) Hz")
        if engine.isRunning, channels == outputChannels, output.sampleRate == core?.sampleRate { return }
        configure(input: isInputOpen)
    }

    /// Channels the graph renders: at least the stereo pair, at most what a track can name.
    nonisolated private static func usableChannels(_ count: AVAudioChannelCount) -> Int {
        Swift.min(Swift.max(Int(count), 2), Track.outputChannelLimit)
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
            // Every output the interface has, so a track can play on 3/4, 5/6 …
            let available = session.maximumOutputNumberOfChannels
            if available > 2, session.outputNumberOfChannels != available {
                log.info("session: prefer \(available, privacy: .public) output channels")
                try? session.setPreferredOutputNumberOfChannels(available)
            }
            // Every input too, so a track can record from input 3 of a mixer or interface.
            if input, session.maximumInputNumberOfChannels > 1,
               session.inputNumberOfChannels != session.maximumInputNumberOfChannels {
                log.info("session: prefer \(session.maximumInputNumberOfChannels, privacy: .public) input channels")
                try? session.setPreferredInputNumberOfChannels(session.maximumInputNumberOfChannels)
            }

            let output = engine.outputNode.outputFormat(forBus: 0)
            let sampleRate = output.sampleRate > 0 ? output.sampleRate : 48_000
            let channels = Self.usableChannels(output.channelCount)
            let format: AVAudioFormat?
            if channels > 2 {
                let layout = AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_DiscreteInOrder | UInt32(channels))
                format = layout.map { AVAudioFormat(standardFormatWithSampleRate: sampleRate, channelLayout: $0) }
            } else {
                format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)
            }
            guard let format else { throw EngineError.noFormat }

            // A new output rate needs a new core; the same rate keeps the playhead and the voices.
            let current: EngineCore
            if let existing = core, existing.sampleRate == sampleRate {
                current = existing
            } else {
                current = EngineCore(sampleRate: sampleRate)
                current.setClickEnabled(clickEnabled)
                current.setLaunchQuantum(self.session.quantum)
                self.session.reset()
                core = current
                slots = SlotAssigner(capacity: current.slotCapacity)
                isPlaying = false
                if let project { publish(project) }
            }

            let node = Self.makeSourceNode(format: format, core: current)
            log.info("graph: attach source node at \(sampleRate, privacy: .public) Hz, \(channels, privacy: .public) ch")
            engine.attach(node)
            sourceNode = node
            if channels > 2 {
                // Straight to the interface: the main mixer would fold the discrete channels to its own layout.
                log.info("graph: connect source → output")
                engine.connect(node, to: engine.outputNode, format: format)
            } else {
                log.info("graph: connect source → main mixer")
                engine.connect(node, to: engine.mainMixerNode, format: format)
                // A multichannel graph before this one took the mixer off the output.
                engine.connect(engine.mainMixerNode, to: engine.outputNode, format: nil)
            }
            if outputChannels != channels {
                outputChannels = channels
                if let project { publish(project) }
            }

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

            clock.attach(current, sampleRate: sampleRate, latency: session.outputLatency)
            if reportTask == nil { pollLaunchReports() }
            log.info("engine: start")
            try engine.start()
            isRunning = true
            isInputOpen = input
            inputChannels = input ? Int(engine.inputNode.inputFormat(forBus: 0).channelCount) : 0
            lastError = nil
        } catch {
            log.error("engine: configure failed — \(error.localizedDescription, privacy: .public)")
            lastError = error.localizedDescription
            // An input that cannot open must not take playback down with it.
            if input { configure(input: false) }
        }
    }

    /// Starts writing the input to `url` from the next input block.
    /// `channel` is the input to record, 0-based; one the input lacks records the first.
    func beginTake(url: URL, channel: Int) throws {
        guard take == nil, let recorder, let core else { throw EngineError.inputClosed }
        let writer = try TakeWriter(url: url, sampleRate: core.sampleRate, ring: recorder.ring)
        let session = AVAudioSession.sharedInstance()
        let latency = Int64(((session.inputLatency + session.outputLatency) * core.sampleRate).rounded())
        take = (url, writer, Swift.max(0, latency))
        recorder.arm(channel: channel)
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

    /// Stops where it is (an external clock's Stop; Continue goes on from here).
    func pause() {
        core?.pause()
        isPlaying = false
    }

    func seek(toTick tick: Tick) {
        guard let core, let project else { return }
        core.seek(toSample: TimeConversion(tempoMap: project.tempoMap, sampleRate: core.sampleRate).sample(at: tick))
    }

    /// Stops and returns to the start.
    func stop() {
        core?.stop()
        isPlaying = false
    }

    // MARK: - Session

    /// Plays the clip on its track from the next bar, starting the transport if it is stopped.
    func launch(_ clip: ClipID, on track: TrackID) {
        guard let core, let slot = slots.slots[track] else { return }
        core.launch(slot: slot, .launch(clip))
        if !isPlaying { play() }
    }

    func stopClip(on track: TrackID) {
        guard let core, let slot = slots.slots[track] else { return }
        core.launch(slot: slot, .stop)
    }

    /// Every track with a clip in the scene plays it; the others stop.
    func launch(_ scene: SceneID, in project: Project) {
        guard let core else { return }
        for track in project.tracks where track.kind == .instrument {
            guard let slot = slots.slots[track.id] else { continue }
            if let clip = track.clipInSlot(scene) {
                core.launch(slot: slot, .launch(clip))
            } else if session.playing[track.id] != nil {
                core.launch(slot: slot, .stop)
            }
        }
        if !isPlaying { play() }
    }

    func stopAllClips() {
        guard let core else { return }
        for track in session.playing.keys { if let slot = slots.slots[track] { core.launch(slot: slot, .stop) } }
    }

    /// Every track the session took over plays its arrangement again.
    func backToArrangement() {
        guard let core else { return }
        for track in session.detached { if let slot = slots.slots[track] { core.launch(slot: slot, .backToArrangement) } }
    }

    /// Bar, beat, or none: how long a launch waits.
    func setLaunchQuantum(_ ticks: Tick?) {
        session.quantum = ticks
        core?.setLaunchQuantum(ticks)
    }

    /// Reads the render thread's launch reports a few times a second; writes only on change.
    private func pollLaunchReports() {
        reportTask?.cancel()
        reportTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.drainLaunchReports()
                try? await Task.sleep(for: .milliseconds(30))
            }
        }
    }

    private func drainLaunchReports() {
        guard let core else { return }
        var owner: [Int: TrackID] = [:]
        var reports: [LaunchReport] = []
        while let report = core.launchReports.pop() { reports.append(report) }
        guard !reports.isEmpty else { return }
        for (track, slot) in slots.slots { owner[slot] = track }
        for report in reports {
            guard let track = owner[report.slot] else { continue }
            session.apply(report, to: track)
        }
    }

    func setClickEnabled(_ enabled: Bool) {
        clickEnabled = enabled
        core?.setClickEnabled(enabled)
    }

    /// The playhead in samples. For a small leaf view that polls it, never a view body.
    var positionSample: Int64 { core?.positionSample ?? 0 }

    /// The playhead as a song position. For actions, never a view body.
    func playheadTick(in project: Project) -> Tick {
        guard let core else { return 0 }
        return TimeConversion(tempoMap: project.tempoMap, sampleRate: core.sampleRate).tick(atSample: core.positionSample)
    }

    private func publish(_ project: Project) {
        guard let core else { return }
        slots.update(for: project)
        live.set(core: core, slot: liveSlot(in: project))
        plugins.sync(project, sampleRate: core.sampleRate)
        generation += 1
        let plan = PlaybackPlan(compiling: project)
        core.publish(EngineSnapshot(plan: plan, project: project,
                                    slots: slots.slots, sampleRate: core.sampleRate, generation: generation,
                                    samples: samples, units: plugins.units, effects: plugins.chains,
                                    outputChannels: outputChannels, revisions: revisions.update(for: plan)))
    }

    /// The track that plays live: the chosen one while it exists, else the first instrument track.
    func liveTrackID(in project: Project) -> TrackID? {
        if let liveTrack, project.track(liveTrack)?.kind == .instrument { return liveTrack }
        return project.tracks.first { $0.kind == .instrument }?.id
    }

    private func liveSlot(in project: Project) -> Int? {
        liveTrackID(in: project).flatMap { slots.slots[$0] }
    }

    /// Built outside the main actor and with an explicitly `@Sendable` block: a closure formed
    /// inside a `@MainActor` method inherits that isolation, and the render thread would trap
    /// on the isolation check before the first sample (the legacy app's builds 2613/2618).
    nonisolated private static func makeSourceNode(format: AVAudioFormat, core: EngineCore) -> AVAudioSourceNode {
        let pointers = ChannelPointers()
        return AVAudioSourceNode(format: format) { @Sendable _, timestamp, frameCount, bufferList in
            let hostTime = timestamp.pointee.mFlags.contains(.hostTimeValid) ? timestamp.pointee.mHostTime : 0
            let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
            let frames = Int(frameCount)
            let count = Swift.min(buffers.count, ChannelPointers.capacity)
            var complete = count >= 2
            for c in 0..<count {
                guard let data = buffers[c].mData?.assumingMemoryBound(to: Float.self) else {
                    complete = false
                    break
                }
                pointers.base[c] = data
            }
            guard complete else {
                for buffer in buffers {
                    if let data = buffer.mData { memset(data, 0, Int(buffer.mDataByteSize)) }
                }
                return noErr
            }
            for c in count..<buffers.count {
                if let data = buffers[c].mData { memset(data, 0, Int(buffers[c].mDataByteSize)) }
            }
            if count == 2 {
                core.render(frameCount: frames, left: pointers.base[0], right: pointers.base[1], hostTime: hostTime)
            } else {
                core.render(frameCount: frames, channels: pointers.base, channelCount: count, hostTime: hostTime)
            }
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

/// Channel pointers for one render callback, allocated once with the source node so the render
/// thread allocates nothing. Only that node's render block touches it.
private final class ChannelPointers: @unchecked Sendable {
    static let capacity = Track.outputChannelLimit
    let base = UnsafeMutablePointer<UnsafeMutablePointer<Float>>.allocate(capacity: capacity)

    deinit { base.deallocate() }
}
