import AVFoundation
import Darwin
import EchoelCore
import EchoelDSP
import EchoelEngine
import EchoelKernels
import Observation
import os

/// The one owner of the audio graph and the audio session. Nothing else creates an
/// `AVAudioEngine` or changes the session category. The sound itself comes from
/// `EngineCore`, which this class feeds with snapshots of the project.
///
/// The input is opened only while a track is armed: the session then records, and a sink node
/// hears the interface. Every graph change writes its line BEFORE the step — to the diagnostic
/// file the musician exports (`DiagnosticLog.app`), then to os_log — so a crash mid-step leaves
/// the step it died in on record (the legacy app's input-node crash family).
@MainActor
@Observable
final class AudioEngine {
    private(set) var isRunning = false
    private(set) var isPlaying = false
    /// The session records and the sink node hears the interface.
    private(set) var isInputOpen = false
    private(set) var lastError: String?
    /// Why the song paused by itself (lost headphones, a new sample rate), until the next Play.
    /// Apart from `lastError`, which every successful start clears.
    private(set) var notice: String?
    /// Output channels of the interface the graph plays on; 2 on the built-in speaker.
    private(set) var outputChannels = 2
    /// Inputs the open input delivers; 0 while it is closed.
    private(set) var inputChannels = 0
    /// Stopped for the background (nothing to play, record or follow); the input it had, to reopen.
    @ObservationIgnored private var suspendedInput: Bool?
    /// The last start failed and no automatic try is left: Play becomes "Restart audio" (R1).
    private(set) var isStalled = false
    /// Audio was started and not given up: a failed start is tried again, not left for good.
    @ObservationIgnored private var wantsAudio = false
    /// The input was asked for (an armed audio track, a track monitoring its input) and not
    /// closed since. Every rebuild opens it again, so a recovery never drops it without a word.
    @ObservationIgnored private var wantsInput = false
    @ObservationIgnored private var isInBackground = false
    @ObservationIgnored private var recovery = AudioRecoveryPolicy()
    @ObservationIgnored private var retryTask: Task<Void, Never>?
    /// Looks at the render count once a second while the song plays (`watchRendering`).
    @ObservationIgnored private var watchdog = RenderWatchdog()
    @ObservationIgnored private var watchTask: Task<Void, Never>?

    /// Replaced, never restarted, after the media services reset (`replaceEngine`).
    @ObservationIgnored private var engine = AVAudioEngine()
    @ObservationIgnored private var sourceNode: AVAudioSourceNode?
    @ObservationIgnored private var sinkNode: AVAudioSinkNode?
    /// The graph's recorder: a new one every time the graph is built, never a take's (`configure`).
    @ObservationIgnored private var recorder: InputRecorder?
    /// The take owns its recorder, its rate and the tempo map its first frame was stamped against:
    /// a rebuild of the graph under it ends it with what it captured (`endTakeBeforeRebuild`), and
    /// its file drains from its own ring.
    @ObservationIgnored private var take: (url: URL, writer: TakeWriter, recorder: InputRecorder,
                                           sampleRate: Double, latency: Int64, tempoMap: TempoMap)?
    @ObservationIgnored private var drainTask: Task<Void, Never>?
    /// Where the take stands between Record, an end from outside, the stop and the closed file.
    /// What a pause, a jump or a rebuild does to it is decided there and tested in the package.
    @ObservationIgnored private var takeLife = TakeLifecycle()
    /// Which reading of the engine's meters shows each track, as of the last snapshot.
    @ObservationIgnored private var meterIndices: [TrackID: Int] = [:]
    @ObservationIgnored private var core: EngineCore?
    @ObservationIgnored private var slots = SlotAssigner(capacity: Track.limit(for: .instrument))
    @ObservationIgnored private var generation: UInt64 = 0
    @ObservationIgnored private var revisions = EventRevisions()
    /// The last compiled plan and what it was compiled from. A change that leaves the source
    /// equal (a fader, a mute, a parameter) keeps the plan instead of compiling the song again.
    @ObservationIgnored private var compiled: (source: PlaybackPlan.Source, plan: PlaybackPlan)?
    /// The song the engine was last given, and the wait before a bridge's song follows it: a
    /// track the engine would cut fades out first (`CutFade`).
    @ObservationIgnored private var heard: Project?
    /// Whether the input was open when the last snapshot was sent: its monitoring reads that.
    @ObservationIgnored private var snapshotSawInput = false
    @ObservationIgnored private var bridgeTask: Task<Void, Never>?
    @ObservationIgnored private var project: Project?
    @ObservationIgnored private var samples: [MediaID: SampleBuffer] = [:]
    @ObservationIgnored private var clickEnabled = true
    @ObservationIgnored private var configurationObserver: NSObjectProtocol?
    @ObservationIgnored private var interruptionObserver: NSObjectProtocol?
    @ObservationIgnored private var resetObserver: NSObjectProtocol?
    @ObservationIgnored private var lostObserver: NSObjectProtocol?
    /// The song was playing when the media services went away. The reset that follows finds it
    /// paused already, and still says how it goes on (review 2026-10-22).
    @ObservationIgnored private var playingWhenServicesLost = false
    @ObservationIgnored private var routeObserver: NSObjectProtocol?
    /// The loaded Audio Unit instruments. Owned here because a unit is only valid at the rate
    /// of the graph this class builds.
    let plugins: PluginHost
    /// Where a controller's notes go; the MIDI input reads it.
    let live = LiveRouter()
    /// Sends the transport's MIDI clock to the outputs picked in the song menu.
    let clock = MIDIClockOutput()
    /// Which session clip each track plays, as the render thread reports it.
    let session = SessionState()
    /// The live body and controller values a song's modulation routes read (W2); the strap writes
    /// its pulse here. Only the live engine reads them — an export passes none.
    let modulation = ModulationInputs()
    @ObservationIgnored private var reportTask: Task<Void, Never>?
    /// The instrument track a controller plays. Nil: the first instrument track.
    private(set) var liveTrack: TrackID?

    func setLiveTrack(_ track: TrackID?) {
        liveTrack = track
        if let project { publish(project) }
    }

    /// A controller's keys play the song's key and scale: a key outside it sounds the nearest
    /// pitch in it. Kept on this device, never in the song — a take stores the notes as they
    /// sounded, so no song depends on the switch, and the format stays as it is.
    private(set) var keysFollowScale = UserDefaults.standard.bool(forKey: AudioEngine.keysFollowScaleKey)

    /// The song loops: while playing, the playhead goes back to bar 1 at the end of the last bar
    /// that holds a clip, so a beat repeats and a part can be layered over it. A MIDI take keeps
    /// recording through the wrap, so each pass lands on the same bars (an overdub in one clip);
    /// an audio take suspends the loop, since one file cannot be placed twice. Kept on this
    /// device, never in the song, like the key lock: the file format stays as it is.
    private(set) var loopsSong = UserDefaults.standard.object(forKey: AudioEngine.loopsSongKey) as? Bool ?? true
    private static let loopsSongKey = "loopsSong"
    /// The range the last published song loops over: from bar 1 to the end of its last bar.
    @ObservationIgnored private var songLoop: Range<Tick>?

    func setLoopsSong(_ on: Bool) {
        loopsSong = on
        UserDefaults.standard.set(on, forKey: Self.loopsSongKey)
        applyLoop()
    }

    private func applyLoop() {
        core?.setLoop(loopsSong && take == nil ? songLoop : nil)
    }

    /// Bar 1 to the end of the last bar a clip or an audio region reaches; at least one bar.
    nonisolated static func loopRange(songEnd: Tick, signature: TimeSignature) -> Range<Tick>? {
        let bar = MusicalTime.ticksPerBar(signature)
        guard bar > 0, songEnd >= 0 else { return nil }
        let bars = Swift.max(1, (songEnd + bar - 1) / bar)
        return 0..<Swift.min(bars * bar, MusicalTime.maximumTick)
    }
    private static let keysFollowScaleKey = "keysFollowScale"

    func setKeysFollowScale(_ on: Bool) {
        keysFollowScale = on
        UserDefaults.standard.set(on, forKey: Self.keysFollowScaleKey)
        if let project { publish(project) }
    }

    /// The armed audio track; with `auto` monitoring it hears its input.
    @ObservationIgnored private var armedTrack: TrackID?

    func setArmedTrack(_ track: TrackID?) {
        armedTrack = track
        if let project { publish(project) }
    }

    /// A monitored input can be heard here without feeding back into itself, and soon enough to
    /// play to: only through wired headphones, an interface or a line output — never the device's
    /// own speaker or earpiece, nor a Bluetooth, AirPlay, HDMI or car speaker, which may stand in
    /// the same room and plays 150 ms to 2 s late — and the device's own microphone only through
    /// wired headphones or an interface (sixth night review, 2026-10-23: a room speaker counted as
    /// safe for it). Seventh night review: a headset's or an interface's microphone went into an
    /// AirPlay speaker once the record session kept that route (`.allowAirPlay`), an echo loop
    /// two seconds long. The port types iOS reports decide, so a headphone adapter into a PA
    /// counts as headphones, and a USB speaker or a USB DAC into monitors as an interface — a
    /// device question, not one this code can answer (eighth night review; FOUNDER_INBOX SM4).
    private var monitoringCannotHowl: Bool {
        let route = AVAudioSession.sharedInstance().currentRoute
        let ownMicrophone = route.inputs.isEmpty || route.inputs.contains { $0.portType == .builtInMic }
        let close: Set<AVAudioSession.Port> = ownMicrophone
            ? [.headphones, .usbAudio]
            : [.headphones, .usbAudio, .lineOut]
        return !route.outputs.isEmpty && route.outputs.allSatisfy { close.contains($0.portType) }
    }

    /// Which input each audio track plays through its strip right now — only where it cannot howl
    /// (`monitoringCannotHowl`), in either mode: headphones pulled with a track set to Always sent
    /// the microphone straight to the speaker, and the song howled (fourth night review,
    /// 2026-10-23). The route change publishes the song again, so monitoring comes back with the
    /// headphones.
    private func monitoring(in project: Project) -> [TrackID: Int] {
        guard isInputOpen, monitoringCannotHowl else { return [:] }
        var result: [TrackID: Int] = [:]
        for track in project.tracks where track.kind == .audio {
            switch track.monitor {
            case .input: result[track.id] = track.input ?? 0
            case .auto: if track.id == armedTrack { result[track.id] = track.input ?? 0 }
            case .off: break
            }
        }
        return result
    }
    @ObservationIgnored private let log = Logger(subsystem: "com.echoelmusic.studio", category: "audio")

    /// Render calls of the current core, for the ladder's rungs (0 without a core).
    private var renderedBuffers: Double { Double(core?.renderCount ?? 0) }

    /// One rung of the lifecycle ladder: the diagnostic file first, with an unbuffered write, then
    /// os_log. Only source text and numbers reach the file, never a name a musician typed.
    private func step(_ event: StaticString, because reason: StaticString? = nil,
                      _ fields: [(StaticString, Double)] = [], level: OSLogType = .info) {
        let line = DiagnosticLog.app.note(event, because: reason, fields)
        log.log(level: level, "\(line, privacy: .public)")
    }

    /// A step that failed: the file gets the error's domain and code, os_log its description too.
    private func failed(_ event: StaticString, _ error: any Error) {
        DiagnosticLog.app.note(event, error: error)
        // The description can name a song or a file, so it stays private even in os_log.
        log.error("\(event.description, privacy: .public) — \(error.localizedDescription, privacy: .private)")
    }

    init() {
        plugins = PluginHost()
        plugins.onUnitsChanged = { [weak self] in
            guard let self, let project = self.project else { return }
            self.publish(project)
        }
        observeConfiguration()
        // A call or Siri takes the audio away. The transport stops where it is, so the song does
        // not carry on by itself when the call ends; the graph comes back, silent, ready to play.
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let type = raw.flatMap(AVAudioSession.InterruptionType.init(rawValue:))
            MainActor.assumeIsolated {
                guard let self else { return }
                switch type {
                case .began:
                    self.step("engine: interruption began", [("buffers", self.renderedBuffers)])
                    self.pauseFromOutside(self.isPlaying ? "Paused: a call, Siri or another app took the audio." : nil)
                case .ended:
                    self.step("engine: interruption ended", [("buffers", self.renderedBuffers)])
                    self.resume(after: "interruption ended")
                default: break
                }
            }
        }
        // Headphones in or out: `auto` monitoring follows, so the speaker never howls. Headphones
        // or an interface gone while playing pause the song instead of moving it to the speaker.
        routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main
        ) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            let lost = raw.flatMap(AVAudioSession.RouteChangeReason.init(rawValue:)) == .oldDeviceUnavailable
            MainActor.assumeIsolated {
                guard let self else { return }
                self.step("route: change", [("reason", Double(raw ?? 0)), ("buffers", self.renderedBuffers)])
                if lost, self.isPlaying {
                    self.step("route: output device gone while playing, pausing")
                    self.pauseFromOutside("Paused: the headphones or the audio interface were disconnected.")
                }
                if let project = self.project { self.publish(project) }
            }
        }
        resetObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                // Only paused, never played on: the musician starts it again (round 4, C6).
                let wasPlaying = self.isPlaying || self.playingWhenServicesLost
                self.playingWhenServicesLost = false
                self.pauseFromOutside(wasPlaying ? "Paused: the audio system restarted. Press Play to go on." : nil)
                self.replaceEngine()
                self.resume(after: "media services reset")
            }
        }
        // The audio system went away; `mediaServicesWereResetNotification` follows when it is back.
        lostObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.mediaServicesWereLostNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.step("engine: media services lost")
                if self.isPlaying { self.playingWhenServicesLost = true }
                self.pauseFromOutside(self.isPlaying ? "Paused: the audio system stopped. Press Play to go on once it is back." : nil)
            }
        }
    }

    /// Plugging an interface in or out stops the engine and may change its channels and rate.
    /// The notification names one engine, so a new engine is observed anew.
    private func observeConfiguration() {
        if let configurationObserver { NotificationCenter.default.removeObserver(configurationObserver) }
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.hardwareChanged() }
        }
    }

    /// After the media services reset, the engine and every node attached to it are dead: Apple's
    /// guidance is to drop them and build new ones, not to start them again. The nodes are
    /// forgotten without a detach (they belong to the dead engine, and detaching them from the new
    /// one would raise). The core and the song stay: they hold no audio object. The recorder goes:
    /// a running take ends at the reset (`endTakeBeforeRebuild`; its file is written out after this
    /// from its own recorder's ring), and a reused recorder would join the input after the reset
    /// onto it, early by the gap. The next `configure` builds the graph on the new engine, now or
    /// on the foreground return.
    private func replaceEngine() {
        endTakeBeforeRebuild()
        step("engine: replace after media services reset")
        engine.stop()
        sourceNode = nil
        sinkNode = nil
        recorder = nil
        isRunning = false
        isInputOpen = false
        inputChannels = 0
        engine = AVAudioEngine()
        observeConfiguration()
    }

    /// Called just before a new output rate replaces the engine core: the plugins are about to
    /// be loaded again at that rate, so the app absorbs their current settings into the song and
    /// returns it (R6).
    @ObservationIgnored var beforeRateChange: (() -> Project?)?

    /// Called when something other than the transport's own Stop pauses the song, or a followed
    /// clock moves its playhead; the record controller ends a running take there, so it never
    /// runs on over a paused song (R10) or across a jump.
    @ObservationIgnored var onPausedFromOutside: (() -> Void)?
    /// The graph came back up after it was down — the launch, a call's end, a reset, a new
    /// interface, the foreground return, a retry or Restart audio: what waited for the audio can
    /// go on now (a song that monitors always opens its input).
    @ObservationIgnored var onAudioBack: (() -> Void)?
    /// Called when Play starts a fresh status line; the document controller drops the last
    /// export's loudness from beside the messages there.
    @ObservationIgnored var onPlay: (() -> Void)?
    /// Counts `pauseFromOutside`, so `canPlay` can tell that its own repair stopped the song.
    @ObservationIgnored private var pausesFromOutside = 0

    /// The song paused by a call, Siri, a media reset, lost headphones, a rebuilt graph or a
    /// followed clock's Stop. `message` goes to the status line until the next Play. A running
    /// take stops capturing before the song pauses (`endTakeFromOutside`).
    func pauseFromOutside(_ message: String?) {
        pausesFromOutside &+= 1
        endTakeFromOutside()
        pause()
        if let message { notice = message }
        onPausedFromOutside?()
        // Playing kept the engine up in the background; paused, it must not stay up silent. After
        // the caller is done: inside configure (a rate change) the graph is still being rebuilt.
        if isInBackground {
            Task { [weak self] in self?.suspendIfIdleInBackground() }
        }
    }

    /// The running take stops capturing input NOW — before the song pauses, the playhead jumps or
    /// the graph is rebuilt — and counts as ended; the record controller writes it out (`endTake`)
    /// when `onPausedFromOutside` reaches it. Input after this moment would join the take at a
    /// playhead that stands still or has jumped, bars from where it was played.
    private func endTakeFromOutside() {
        guard let take else { return }
        take.recorder.disarm()
        takeLife.endedFromOutside()
    }

    /// A graph rebuilt under a running take — a route change, a new sample rate, a media services
    /// reset, Restart audio — ends it first, with what it captured, and pauses the song once: the
    /// take's recorder is never fed again, the new graph gets a recorder of its own, and the file
    /// drains from the take's own ring (review 2026-10-28, 2.1). A take already ending from
    /// outside is disarmed again and announced no second time.
    private func endTakeBeforeRebuild() {
        guard let take else { return }
        take.recorder.disarm()
        guard takeLife.phase == .recording else { return }
        step("record: take ends before rebuild")
        pauseFromOutside("Paused: the audio setup changed, so the take ended. It keeps what it recorded.")
    }

    /// Rebuilds the graph after an interruption or a reset. Also when the last start failed: such
    /// an event can be what lets it succeed. Not in the background — the foreground return heals —
    /// unless the engine stays up there to hear a followed clock's Start.
    private func resume(after reason: StaticString) {
        guard wantsAudio, suspendedInput == nil, mayRebuildNow else { return }
        // An interruption's end can come late, after the foreground return or a Play already
        // brought the graph back: rebuilding a running engine would cut the song for nothing.
        // A reset stopped the engine first, so it always rebuilds.
        guard !(isRunning && engine.isRunning) else {
            step("engine: already running", because: reason)
            return
        }
        step("engine: rebuilding", because: reason)
        recovery.reset()
        configure(input: wantsInput)
        cameBack()
    }

    /// Tells `onAudioBack` when the graph that was down runs again.
    private func cameBack() {
        if isUp { onAudioBack?() }
    }

    /// In the foreground, or in the background while a followed clock keeps the engine running
    /// (`enterBackground` leaves it up for that): a suspended app would never hear the next Start.
    private var mayRebuildNow: Bool {
        !isInBackground || followsExternalClock && (clockSourceConnected || clockSourceGone != nil)
    }

    /// Rebuilds the graph for the interface now attached, unless it already matches and runs.
    private func hardwareChanged() {
        // Not while stopped: configuring can itself post this notification, and a failed start
        // answered here would retry without end. The retry and Restart audio cover that case.
        guard isRunning else { return }
        // Before the output is asked for its format: a crash in that query reads as its own step.
        step("engine: configuration change", [("buffers", renderedBuffers)])
        let output = engine.outputNode.outputFormat(forBus: 0)
        let channels = Self.usableChannels(output.channelCount)
        step("graph: output format", [("ch", Double(output.channelCount)), ("Hz", output.sampleRate)])
        if engine.isRunning, channels == outputChannels, output.sampleRate == core?.sampleRate { return }
        configure(input: wantsInput)
        cameBack()
    }

    /// Channels the graph renders: at least the stereo pair, at most what a track can name.
    nonisolated private static func usableChannels(_ count: AVAudioChannelCount) -> Int {
        Swift.min(Swift.max(Int(count), 2), Track.outputChannelLimit)
    }

    func start() {
        guard !isRunning else { return }
        wantsAudio = true
        configure(input: false)
        cameBack()
    }

    /// The user asks for audio again after the automatic tries ran out.
    func restartAudio() {
        step("engine: restart asked")
        wantsAudio = true
        suspendedInput = nil
        recovery.reset()
        configure(input: wantsInput)
        cameBack()
    }

    /// The graph as it was before the background, or rebuilt when iOS stopped it underneath.
    private func wake(_ reason: StaticString) {
        guard let input = suspendedInput else {
            healIfStopped(reason)
            return
        }
        suspendedInput = nil
        step("engine: resume from background")
        recovery.reset()
        configure(input: input)
        if let project { publish(project) }
        cameBack()
    }

    /// Rebuilds the graph when iOS stopped it without telling (an interruption without `.ended`),
    /// so Play never runs a transport over a stopped engine (R2).
    private func healIfStopped(_ reason: StaticString) {
        guard wantsAudio, suspendedInput == nil, !engine.isRunning else { return }
        step("engine: stopped underneath, rebuilding", because: reason)
        recovery.reset()
        configure(input: wantsInput)
        cameBack()
    }

    /// While the song plays, once a second: a render count that stood still for two seconds means
    /// the source node is no longer called although the engine may say it runs — the transport
    /// would go on over silence. The step is written first, then the graph is rebuilt at the same
    /// rate, which keeps the core, the playhead and the voices (`configure`). On the main actor,
    /// never on the render thread; it reads the count the render thread already publishes. It ends
    /// by itself when the song stops, and the next Play starts it again.
    private func watchRendering() {
        guard watchTask == nil else { return }
        let origin = ContinuousClock.now
        watchTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { return }
                guard self.isPlaying else {
                    _ = self.watchdog.look(count: 0, at: ContinuousClock.now - origin, playing: false)
                    self.watchTask = nil
                    return
                }
                self.lookAtRendering(at: ContinuousClock.now - origin)
            }
        }
    }

    private func lookAtRendering(at now: Duration) {
        guard let core else { return }
        let playing = isPlaying && suspendedInput == nil && wantsAudio
        switch watchdog.look(count: core.renderCount, at: now, playing: playing) {
        case .fine:
            return
        case .heal(let stalled):
            let seconds = Double(stalled.components.seconds) + Double(stalled.components.attoseconds) / 1e18
            step("engine: render stalled, rebuilding", [("s", seconds), ("buffers", renderedBuffers),
                                                         ("running", engine.isRunning ? 1 : 0)], level: .error)
            guard engine.isRunning else {
                healIfStopped("render stalled")
                return
            }
            recovery.reset()
            configure(input: wantsInput)
            cameBack()
        case .gaveUp:
            // Rebuilt and still silent: the song pauses (a take ends with what it has) and Play
            // becomes Restart audio, the one door that rebuilds a graph the engine calls running.
            step("engine: render still stalled after rebuilds", [("buffers", renderedBuffers)], level: .error)
            pauseFromOutside("The audio stopped responding, so the song paused. Tap Restart audio.")
            isStalled = true
        }
    }

    /// The app went to the background. With nothing playing, recording or following a connected
    /// clock the audio stops, so a silent app does not keep the device awake (App Review 2.5.4).
    /// The playhead, the voices and the song stay; `enterForeground` or a play brings it back.
    func enterBackground() {
        isInBackground = true
        suspendIfIdleInBackground()
    }

    /// Stops the audio while in the background with nothing to play, record or follow. Also when
    /// a pause from outside or the end of a take leaves the app that idle after it went there.
    private func suspendIfIdleInBackground() {
        guard isInBackground, isRunning, !isPlaying, take == nil,
              !(followsExternalClock && (clockSourceConnected || clockSourceGone != nil)) else { return }
        step("engine: suspend in background", [("buffers", renderedBuffers)])
        suspendedInput = wantsInput
        engine.stop()
        isRunning = false
        step("session: deactivate")
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Back in the foreground, or asked to play while suspended: the graph as it was. A graph that
    /// stayed up through the background — a followed clock keeps it — did not come back, but what
    /// waited for the app to be in front can go on now: the input opens only there (fifth night
    /// review, 2026-10-23: a song that monitors always stayed deaf for the clock's next run).
    func enterForeground() {
        let stayedUp = isUp
        isInBackground = false
        wake("foreground")
        if stayedUp { cameBack() }
    }

    /// The graph is built and the audio session runs it: opening the input now can succeed. Not
    /// during a call, Siri or a lost audio system, which stop the engine under the app.
    var isUp: Bool { isRunning && engine.isRunning }
    /// The input can be opened now: the audio runs, and the app is in front — iOS does not let an
    /// app start recording from the background, so the foreground return opens it (`onAudioBack`).
    var canOpenInputNow: Bool { isUp && !isInBackground }

    /// Opens the input for recording, asking for microphone permission first. False when it is
    /// denied or the interface cannot be used; playback keeps running either way.
    func openInput() async -> Bool {
        await openInput(keepingPosition: false)
    }

    /// The same, for a song already paused where it is (a pause from outside) with no take
    /// running: the song stays at its position instead of going back to the start, and the pause
    /// is not announced a second time. False, and nothing opened, when the song plays again by
    /// the time the permission answer comes (third night review, 2026-10-23: the input opened
    /// after a call or a followed clock's Stop rewound the song to bar 1).
    func openInputKeepingPosition() async -> Bool {
        await openInput(keepingPosition: true)
    }

    private func openInput(keepingPosition: Bool) async -> Bool {
        if isInputOpen {
            wantsInput = true
            return true
        }
        guard await AVAudioApplication.requestRecordPermission() else {
            lastError = "Echoel may not use the microphone. Allow it in Settings."
            return false
        }
        if keepingPosition {
            // The answer can take a moment: the song may play again, or the input be open by now,
            // or a call or the background may have taken the audio — then it waits for its return
            // (`onAudioBack`) instead of raising the session under them (fourth night review).
            guard !isPlaying, canOpenInputNow || isInputOpen else { return false }
            if isInputOpen {
                wantsInput = true
                return true
            }
            pause()
        } else {
            // Opening the input stops the song: a running take ends here, once it is certain the
            // input opens — its input capture at once, its file through the controller — instead of
            // recording on over a stopped, rewound transport and a rebuilt graph.
            endTakeFromOutside()
            onPausedFromOutside?()
            stop()
        }
        wantsInput = true
        configure(input: true)
        if let project { publish(project) }
        // Refused now: nothing is armed, so nothing asks for it again.
        wantsInput = isInputOpen
        return isInputOpen
    }

    func closeInput() {
        wantsInput = false
        guard isInputOpen else { return }
        stop()
        configure(input: false)
        if let project { publish(project) }
    }

    /// Builds the graph from scratch for playback, or playback plus input. A take recording until
    /// here ends first, with what it captured (`endTakeBeforeRebuild`).
    private func configure(input: Bool) {
        retryTask?.cancel()
        retryTask = nil
        endTakeBeforeRebuild()
        step("engine: stop for configure", [("input", input ? 1 : 0)])
        engine.stop()
        isRunning = false
        isInputOpen = false
        if let sinkNode {
            step("graph: detach sink node")
            engine.detach(sinkNode)
            self.sinkNode = nil
        }
        // Never a recorder from before this build, and never a take's: the graph records through
        // a new recorder every time it is built. A take that ran until here ended above and keeps
        // its own — its file drains from that ring. A recorder that outlived a rebuild would join
        // the input after the gap straight onto the input before it, early by the gap and at the
        // latency of a route the take was not stamped for (review 2026-10-28, 2.1).
        recorder = nil
        if let sourceNode {
            step("graph: detach source node")
            engine.detach(sourceNode)
            self.sourceNode = nil
        }
        do {
            let session = AVAudioSession.sharedInstance()
            if input {
                step("session: configure playAndRecord")
                // AirPlay allowed too: without it, opening the input moved a song playing on an
                // AirPlay speaker back to the device's own speaker (sixth night review, 2026-10-23).
                try session.setCategory(.playAndRecord, mode: .default,
                                        options: [.defaultToSpeaker, .allowBluetoothA2DP, .allowAirPlay])
            } else {
                step("session: configure playback")
                try session.setCategory(.playback, mode: .default, options: [])
            }
            step("session: activate")
            try session.setActive(true)
            // Every output the interface has, so a track can play on 3/4, 5/6 …
            let available = session.maximumOutputNumberOfChannels
            if available > 2, session.outputNumberOfChannels != available {
                step("session: prefer output channels", [("ch", Double(available))])
                try? session.setPreferredOutputNumberOfChannels(available)
            }
            // Every input too, so a track can record from input 3 of a mixer or interface.
            if input, session.maximumInputNumberOfChannels > 1,
               session.inputNumberOfChannels != session.maximumInputNumberOfChannels {
                step("session: prefer input channels", [("ch", Double(session.maximumInputNumberOfChannels))])
                try? session.setPreferredInputNumberOfChannels(session.maximumInputNumberOfChannels)
            }

            // The first touch of the output node on a new engine makes it.
            step("graph: read output format")
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
                // A rate change mid-session (an interface plugged in, another app): the song
                // stops, the playhead stays where it was, and the plugins' settings since the last
                // save reach the song before they are loaded again at the new rate (ultra-audit
                // R6). A take ended at the top of this rebuild, and the song paused with it.
                var resumeTick: Tick?
                if let old = core {
                    if isPlaying {
                        pauseFromOutside("The song stopped: the audio interface changed its sample rate.")
                    }
                    if let fresh = beforeRateChange?() { project = fresh }
                    resumeTick = project.map {
                        TimeConversion(tempoMap: playing($0).tempoMap, sampleRate: old.sampleRate).tick(atSample: old.positionSample)
                    }
                }
                defer { if let resumeTick { seek(toTick: resumeTick) } }
                current = EngineCore(sampleRate: sampleRate)
                current.setClickEnabled(clickEnabled)
                current.setLaunchQuantum(self.session.quantum)
                self.session.reset()
                core = current
                slots = SlotAssigner(capacity: current.slotCapacity)
                heard = nil                  // a new core plays nothing yet, so nothing to fade
                isPlaying = false
                if let project { publish(project) }
            }

            let node = Self.makeSourceNode(format: format, core: current)
            step("graph: attach source node", [("Hz", sampleRate), ("ch", Double(channels))])
            engine.attach(node)
            sourceNode = node
            if channels > 2 {
                // Straight to the interface: the main mixer would fold the discrete channels to its own layout.
                step("graph: connect source → output")
                engine.connect(node, to: engine.outputNode, format: format)
            } else {
                step("graph: connect source → main mixer")
                engine.connect(node, to: engine.mainMixerNode, format: format)
                // A multichannel graph before this one took the mixer off the output.
                step("graph: connect main mixer → output")
                engine.connect(engine.mainMixerNode, to: engine.outputNode, format: nil)
            }
            if outputChannels != channels {
                outputChannels = channels
                if let project { publish(project) }
            }

            if input {
                // Connect only in the input's own format, and only when it runs at the output rate:
                // a mismatch is refused here instead of raising inside AVAudioEngine. The first
                // touch of the input node makes it — where the earlier app's input crashes raised
                // (fifth night review, 2026-10-23: this step had no line of its own).
                step("graph: open input node")
                let inputFormat = engine.inputNode.inputFormat(forBus: 0)
                guard inputFormat.channelCount > 0, inputFormat.sampleRate == sampleRate else {
                    throw EngineError.inputUnusable(inputFormat.sampleRate, sampleRate)
                }
                let recorder = InputRecorder(core: current, sampleRate: sampleRate)
                let sink = InputRecorder.makeSinkNode(recorder)
                step("graph: attach sink node", [("ch", Double(inputFormat.channelCount))])
                engine.attach(sink)
                sinkNode = sink
                self.recorder = recorder
                step("graph: connect input → sink")
                engine.connect(engine.inputNode, to: sink, format: inputFormat)
            }

            clock.attach(current, sampleRate: sampleRate, latency: session.outputLatency)
            if reportTask == nil { pollLaunchReports() }
            step("engine: start")
            try engine.start()
            // The session's own values after the start (Studio asks for no rate and no buffer;
            // Apple QA1631: any such wish is a hint). out_Hz=0 shows an output that reported no
            // rate before the 48 kHz fallback above. `buffers` counts render calls: a later rung
            // that repeats it while the engine is said to run means nothing renders.
            step("engine: started", [("Hz", session.sampleRate), ("out_Hz", output.sampleRate),
                                     ("io_ms", session.ioBufferDuration * 1_000),
                                     ("in_ms", session.inputLatency * 1_000),
                                     ("out_ms", session.outputLatency * 1_000),
                                     ("buffers", Double(current.renderCount))])
            isRunning = true
            isInputOpen = input
            if input { step("graph: read input channels") }
            inputChannels = input ? Int(engine.inputNode.inputFormat(forBus: 0).channelCount) : 0
            lastError = nil
            isStalled = false
            recovery.reset()
            // The last snapshot's monitoring saw another input state: it was sent while the graph
            // was down (a new core above, a reset in the background, a failed try). Nothing else
            // would send the song again until an unrelated change, so a monitored track would
            // stay without its input.
            if isInputOpen != snapshotSawInput, let project { publish(project) }
        } catch {
            failed("engine: configure failed", error)
            lastError = error.localizedDescription
            // An input that cannot open must not take playback down with it, and says so: the
            // successful playback start would otherwise clear the only word about it.
            if input {
                // Our own reasons say what to change (a rate mismatch, no input); the system's do not.
                let reason = (error as? EngineError)?.errorDescription.map { " " + $0 } ?? ""
                // A take that ran into this rebuild ended at its top, and the song paused with it:
                // the line says so, since an error hides the pause notice.
                let wasRecording = take != nil
                configure(input: false)
                guard isRunning else { return }
                lastError = "The audio input could not be opened." + reason
                    + (wasRecording ? " The take ended and keeps what it recorded." : " Playback goes on without it.")
                return
            }
            // Never a log-only catch: a short settle, then again, a few times (R1).
            guard let wait = recovery.failed() else {
                step("engine: automatic tries used up", level: .error)
                isStalled = true
                lastError = "Audio could not start. Tap Restart audio once the call or the other app using audio has ended."
                return
            }
            let seconds = Double(wait.components.seconds) + Double(wait.components.attoseconds) / 1e18
            step("engine: trying again", [("s", seconds)])
            retryTask = Task { [weak self] in
                try? await Task.sleep(for: wait)
                guard !Task.isCancelled, let self, self.wantsAudio, !self.isRunning,
                      self.suspendedInput == nil, self.mayRebuildNow else { return }
                self.configure(input: self.wantsInput)
                self.cameBack()
            }
        }
    }

    /// Starts writing the input to `url` from the next input block.
    /// `channel` is the input to record, 0-based; one the input lacks records the first.
    func beginTake(url: URL, channel: Int) throws {
        // Not while the last take is still being written out: a second writer would drain the same
        // ring, arming would reset the start that take still reads, and its drain task would be lost.
        guard takeLife.canBegin, let recorder, let core else { throw EngineError.inputClosed }
        let writer = try TakeWriter(url: url, sampleRate: core.sampleRate, ring: recorder.ring)
        let session = AVAudioSession.sharedInstance()
        let latency = MusicalTime.integer(((session.inputLatency + session.outputLatency) * core.sampleRate).rounded())
        // The map the take's first frame is stamped against: the one the engine plays now — a
        // followed clock's, not the song's. The take is placed with it, never with the map at the
        // stop, which a drifting clock has moved on by then (`RecordedTake.tempoMap`).
        let tempoMap = project.map { playing($0).tempoMap } ?? TempoMap(bpm: Tempo.defaultBPM)
        take = (url, writer, recorder, core.sampleRate, Swift.max(0, latency), tempoMap)
        takeLife.begin()
        recorder.arm(channel: channel)
        applyLoop()
        drainTask = Task.detached(priority: .userInitiated) {
            while !Task.isCancelled {
                try? await writer.drain()
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
        step("record: take started")
    }

    /// Stops the take and closes its file. Nil when nothing was captured; the empty file is gone.
    func endTake() async -> RecordedTake? {
        // Never the engine's recorder: after a rebuild that is a different one, or none.
        guard let current = take, takeLife.stop() else { return nil }
        take = nil
        applyLoop()
        defer { takeLife.finished() }
        let recorder = current.recorder
        recorder.disarm()
        // The ring holds what was captured, so the drain below needs no running engine.
        suspendIfIdleInBackground()
        drainTask?.cancel()
        await drainTask?.value
        drainTask = nil
        step("record: take stopped")
        let frames: Int
        do {
            frames = try await current.writer.finish()
        } catch {
            failed("record: writing failed", error)
            lastError = "The take could not be written."
            return nil
        }
        if await current.writer.reachedLimit {
            let longest = AudioFileImport.spoken(AudioFileImport.longestSeconds(atRate: current.sampleRate))
            lastError = "The take stopped at \(longest), the longest the song can hold at this sample rate."
        }
        let firstSample = recorder.startSample
        guard frames > 0, firstSample >= 0 else {
            try? FileManager.default.removeItem(at: current.url)
            return nil
        }
        return RecordedTake(url: current.url, sampleRate: current.sampleRate, startSample: firstSample,
                            latency: current.latency, tempoMap: current.tempoMap)
    }

    /// Hands the current project to the render thread. Call on every project change; it is
    /// cheap (the note events are shared, not copied).
    func update(_ project: Project) {
        self.project = project
        publish(project)
    }

    /// While an external MIDI clock is followed, the clock is the tempo: the song's own tempo
    /// changes would run it off the clock, so they are left out of what the engine plays.
    var followsExternalClock = false {
        didSet {
            guard followsExternalClock != oldValue, let project else { return }
            publish(project)
        }
    }

    /// The source of the followed clock is connected. Only then does the engine stay up in the
    /// background to hear its Start: the choice is kept across launches, and a device chosen once
    /// and unplugged since must not keep a silent app awake (round 4, C7).
    /// A source that went away stops the engine only after `clockSourceGrace`: a Bluetooth link
    /// that drops for a moment, or a cable moved, must not end the background wait for its Start
    /// (review 2026-10-22). A suspended app does not hear the source come back.
    var clockSourceConnected = false {
        didSet {
            guard clockSourceConnected != oldValue else { return }
            clockSourceGone?.cancel()
            clockSourceGone = nil
            guard !clockSourceConnected else { return }
            clockSourceGone = Task { [weak self] in
                try? await Task.sleep(for: .seconds(Self.clockSourceGrace))
                guard !Task.isCancelled else { return }
                self?.clockSourceGone = nil
                self?.suspendIfIdleInBackground()
            }
        }
    }
    @ObservationIgnored private var clockSourceGone: Task<Void, Never>?
    private static let clockSourceGrace = 15.0

    /// The followed clock's tempo, once known. It is played, never written into the song: the
    /// song keeps its own tempo and its undo history while another device sets the pace.
    var externalTempo: Double? {
        didSet {
            guard externalTempo != oldValue, followsExternalClock, let project else { return }
            publish(project)
        }
    }

    /// The song as the engine plays it: itself, or the clock's tempo in place of its own while a
    /// clock is followed (`ClockFollower.played`). Every snapshot, seek, placement and automation
    /// point goes through this one function (review 2026-10-28, 2.2).
    private func playing(_ project: Project) -> Project {
        guard followsExternalClock else { return project }
        return ClockFollower.played(project, tempo: externalTempo)
    }

    /// The decoded audio files sampler tracks play. Republishes the current project with them.
    func setSamples(_ samples: [MediaID: SampleBuffer]) {
        self.samples = samples
        if let project { publish(project) }
    }

    /// The pause and plugin notices go: a finished export starts a fresh status line (a Play that
    /// plays does the same, in `play`).
    func clearNotices() {
        notice = nil
        plugins.clearNotice()
    }

    func play() {
        let standing = (notice, plugins.notice)
        // A heal that failed leaves nothing rendering. The transport must not run over it: a
        // retry that succeeds later (the call ended) would start the song by itself.
        guard canPlay(), let core else { return }
        // Only a Play that plays starts a fresh status line; one refused leaves every line that
        // still says why (round 4). What the heal itself raised is newer than the Play, and stays.
        if notice == standing.0 { notice = nil }
        if plugins.notice == standing.1 { plugins.clearNotice() }
        onPlay?()
        playingWhenServicesLost = false
        core.play()
        isPlaying = true
        watchRendering()
    }

    /// Brings the graph back if it was suspended or stopped underneath, and says whether the
    /// transport can run now. Record and a launch ask before they start anything, so neither a
    /// take nor a queued launch waits over audio that is down — also while `isPlaying`, which a
    /// rebuild that failed at the same rate leaves set over a stopped engine.
    /// Not when that repair itself stopped the song (a new sample rate at the rebuild): the stop
    /// also ends a running take a moment later, so a take started now would end at once. The
    /// status line says why; the next press goes ahead (review 2026-10-21).
    func canPlay() -> Bool {
        let pauses = pausesFromOutside
        wake("play")
        return pauses == pausesFromOutside && core != nil && engine.isRunning
    }

    /// Stops where it is (an external clock's Stop; Continue goes on from here).
    func pause() {
        core?.pause()
        isPlaying = false
    }

    func seek(toTick tick: Tick) {
        guard let core, let project else { return }
        core.seek(toSample: TimeConversion(tempoMap: playing(project).tempoMap, sampleRate: core.sampleRate).sample(at: tick))
    }

    /// Where the song is heard at host time `now`, in fractional ticks, and how many samples a
    /// tick lasts there. Taken from the position the render thread published with the host time
    /// of its last buffer, so it does not depend on when in that buffer it is asked, and it is
    /// in the time base that buffer was actually rendered with. Nil while stopped.
    func heardPosition(atHostTime now: UInt64) -> (tick: Double, samplesPerTick: Double)? {
        guard let core, isPlaying, let anchor = core.timelineAnchor() else { return nil }
        let rate = core.sampleRate
        let elapsed = (Double(now) - Double(anchor.hostTime)) * Double(Self.timebase.numer) / Double(Self.timebase.denom) / 1e9
        let samples = elapsed * rate - Double(anchor.frames) - Self.outputLatency * rate
        let tick = anchor.tick + samples / anchor.samplesPerTick
        return tick.isFinite ? (tick, anchor.samplesPerTick) : nil
    }

    private static let timebase: (numer: UInt32, denom: UInt32) = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return (Swift.max(info.numer, 1), Swift.max(info.denom, 1))
    }()

    /// Seconds from the device playing a frame to the speaker.
    private static var outputLatency: Double {
        let latency = AVAudioSession.sharedInstance().outputLatency
        return latency.isFinite ? Swift.min(Swift.max(latency, 0), 0.25) : 0
    }

    /// A followed clock is about to move the playhead (Start, Song Position). An audio take is
    /// placed from the sample it began at, so one running over the jump put everything played
    /// after it bars late or early: it ends here, before the jump, with what it captured (audit
    /// 2026-10-23). A MIDI take ends with it, as at a pause from outside.
    func clockWillMovePlayhead() {
        endTakeFromOutside()
        onPausedFromOutside?()
    }

    /// Moves the playhead by a few milliseconds without a seek (phase correction).
    func nudge(seconds: Double) {
        guard let core, seconds.isFinite else { return }
        core.nudge(bySamples: Int64((seconds * core.sampleRate).rounded()))
    }

    /// Jumps by `ticks` (the measured gap), as a seek: for a phase too far off to nudge.
    func relock(byTicks ticks: Double, samplesPerTick: Double) {
        guard let core, ticks.isFinite, samplesPerTick.isFinite, samplesPerTick > 0 else { return }
        let samples = (ticks * samplesPerTick).rounded()
        guard abs(samples) < 1e12 else { return }
        core.jump(bySamples: Int64(samples))
    }

    /// Stops and returns to the start.
    func stop() {
        core?.stop()
        isPlaying = false
    }

    // MARK: - Session

    /// Plays the clip on its track from the next bar, starting the transport if it is stopped.
    func launch(_ clip: ClipID, on track: TrackID) {
        guard canPlay(), let core, let slot = slots.slots[track] else { return }
        core.launch(slot: slot, .launch(clip))
        if !isPlaying { play() }
    }

    func stopClip(on track: TrackID) {
        guard let core, let slot = slots.slots[track] else { return }
        core.launch(slot: slot, .stop)
    }

    /// Every track with a clip in the scene plays it; the others stop.
    func launch(_ scene: SceneID, in project: Project) {
        guard canPlay(), let core else { return }
        for track in project.tracks where track.kind != .returnTrack {
            guard let slot = slots.slots[track.id] else { continue }
            if let clip = track.clipInSlot(scene) {
                core.launch(slot: slot, .launch(clip))
            } else if session.playing[track.id] != nil || session.queued[track.id] != nil {
                // A clip only queued would otherwise still start at its bar.
                core.launch(slot: slot, .stop)
            }
        }
        if !isPlaying { play() }
    }

    func stopAllClips() {
        guard let core else { return }
        // Queued clips too: one waiting for its bar would otherwise still start (audit 2026-10-23).
        for track in Set(session.playing.keys).union(session.queued.keys) {
            if let slot = slots.slots[track] { core.launch(slot: slot, .stop) }
        }
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

    /// The output rate the engine runs at, once it does.
    var sampleRate: Double? { core?.sampleRate }

    /// Output latency in samples: how long after the engine renders a sample it is heard.
    var outputLatencySamples: Int64 {
        guard let core else { return 0 }
        return Int64((AVAudioSession.sharedInstance().outputLatency * core.sampleRate).rounded())
    }

    /// The playhead in samples. For a small leaf view that polls it, never a view body.
    var positionSample: Int64 { core?.positionSample ?? 0 }

    /// The tempo map the engine plays `project` with: an external clock's tempo while following one.
    func playedTempoMap(of project: Project) -> TempoMap {
        playing(project).tempoMap
    }

    /// The playhead as a song position. For actions, never a view body.
    func playheadTick(in project: Project) -> Tick {
        guard let core else { return 0 }
        // The tempo the engine plays: an external clock's, not the song's, while following one.
        return TimeConversion(tempoMap: playing(project).tempoMap, sampleRate: core.sampleRate).tick(atSample: core.positionSample)
    }

    /// Every song goes through here. A deleted track, or one switched to another instrument,
    /// fades out first: the bridge plays it muted, the song follows `CutFade.duration` later. A
    /// newer song in between replaces both, bridged again if it still cuts.
    private func publish(_ song: Project) {
        bridgeTask?.cancel()
        bridgeTask = nil
        guard core != nil else { return }
        guard let heard, let bridge = CutFade.bridge(from: heard, to: song) else {
            send(song)
            return
        }
        send(bridge)
        bridgeTask = Task { [weak self] in
            try? await Task.sleep(for: CutFade.duration)
            guard !Task.isCancelled, let self else { return }
            self.bridgeTask = nil
            self.send(song)
        }
    }

    /// Every snapshot goes through here, so none can carry the song's tempo changes while an
    /// external clock sets the tempo (they would jump the playhead until the clock relocks).
    private func send(_ song: Project) {
        guard let core else { return }
        heard = song
        let project = playing(song)
        slots.update(for: project)
        session.retain(Set(slots.slots.keys))
        live.set(core: core, slot: liveSlot(in: project), lock: liveLock(in: project))
        plugins.sync(project, sampleRate: core.sampleRate)
        generation += 1
        let source = PlaybackPlan.Source(project)
        snapshotSawInput = isInputOpen
        let plan: PlaybackPlan
        if let previous = compiled, previous.source == source {
            plan = previous.plan
        } else {
            plan = PlaybackPlan(compiling: project)
            compiled = (source, plan)
        }
        let snapshot = EngineSnapshot(plan: plan, project: project,
                                      slots: slots.slots, sampleRate: core.sampleRate, generation: generation,
                                      samples: samples, units: plugins.units,
                                      effects: plugins.chains.mapValues { $0 as [any HostedProcessor] },
                                      outputChannels: outputChannels, revisions: revisions.update(for: plan),
                                      monitoring: monitoring(in: project), masterEffects: plugins.masterChain,
                                      modulation: modulation)
        meterIndices = core.meterIndices(for: snapshot)
        core.publish(snapshot)
        let songEnd = Swift.max(plan.songEnd, snapshot.time.tick(atSample: snapshot.audioEnd))
        songLoop = Self.loopRange(songEnd: songEnd, signature: project.timeSignature)
        applyLoop()
    }

    /// A track's peak meter, or the master's for nil. For a small leaf view that polls it.
    func meterLevel(_ track: TrackID?) -> MeterBank.Level {
        guard let core else { return .silent }
        guard let track else { return core.meters.level(core.masterMeter) }
        guard let index = meterIndices[track] else { return .silent }
        return core.meters.level(index)
    }

    /// The track that plays live: the chosen one while it exists, else the first instrument track.
    func liveTrackID(in project: Project) -> TrackID? {
        if let liveTrack, project.track(liveTrack)?.kind == .instrument { return liveTrack }
        return project.tracks.first { $0.kind == .instrument }?.id
    }

    private func liveSlot(in project: Project) -> Int? {
        liveTrackID(in: project).flatMap { slots.slots[$0] }
    }

    private func liveLock(in project: Project) -> [UInt8]? {
        guard keysFollowScale, let track = liveTrackID(in: project).flatMap(project.track) else { return nil }
        return LiveKeys.lock(for: project.context, device: track.instrument.device)
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
                    ? "The input runs at \(Int(input)) Hz and the output at \(Int(output)) Hz; set both to the same rate, then arm the track or choose Always again (if the track still shows armed, turn it off and on)."
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
