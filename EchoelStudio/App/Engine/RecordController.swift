import EchoelCore
import Observation

/// Arming and recording. One audio track is armed at a time; arming opens the input,
/// disarming closes it. Record starts a take on the armed track (and the song, if it is not
/// playing); stopping turns the take into a region in one undo step. Arm state belongs to the
/// session, not to the song, so it is not saved.
@MainActor
@Observable
final class RecordController {
    private(set) var armedTrack: TrackID?
    private(set) var isRecording = false

    @ObservationIgnored private let engine: AudioEngine
    @ObservationIgnored private let documents: DocumentController
    @ObservationIgnored private let store: ProjectStore
    @ObservationIgnored private var target: (track: TrackID, file: DocumentController.TakeTarget)?
    /// The instrument track a MIDI take records onto, while one does.
    @ObservationIgnored private var midiTrack: TrackID?
    /// The song `inputFollowsSong` last saw, so it can tell an opened song from an edit.
    @ObservationIgnored private var seenGeneration: Int?

    init(engine: AudioEngine, documents: DocumentController, store: ProjectStore) {
        self.engine = engine
        self.documents = documents
        self.store = store
        // A call, lost headphones or a followed clock's Stop pause the song: a take ends with it
        // and keeps what it captured, instead of resuming out of time after the pause (R10). A
        // MIDI take ends right here, against the engine core it was played on: on a rate change
        // a new core replaces that one as soon as this returns.
        engine.onPausedFromOutside = { [weak self] in
            self?.endMIDITake()
            Task {
                await self?.stopRecording()
                await self?.inputOpensAfterOutsidePause()
            }
        }
        // The input fell away under an audio take: the take cannot carry on, so it ends with what
        // it has. A MIDI take needs no input and goes on.
        engine.onInputLost = { [weak self] in
            Task { await self?.stopAudioTake() }
        }
    }

    private func stopAudioTake() async {
        guard midiTrack == nil else { return }
        await stopRecording()
    }

    /// Arms `track`, or disarms it when it is the armed one. An instrument track records what is
    /// played on MIDI and plays it live; it needs no audio input.
    func toggleArm(_ track: TrackID) async {
        if isRecording {
            let asked = armedTrack
            await stopRecording()
            // Another toggle ran while the take was ending (a second deletion, say): this one
            // was asked of an arm state that is gone, and acting on it would re-arm a deleted
            // track and reopen the input.
            guard armedTrack == asked else { return }
        }
        // An armed track that is gone (deleted, or another song opened) counts as audio: its kind
        // cannot be read any more, and closing an input nothing else wants is always right. Read
        // from the project alone, it left the microphone open, and every recovery reopened it.
        let wasAudio = armedTrack.map { store.project.track($0)?.kind ?? .audio } == .audio
        if armedTrack == track {
            armedTrack = nil
            engine.setArmedTrack(nil)
            if wasAudio, !monitorsAlways { engine.closeInput() }
            return
        }
        if store.project.track(track)?.kind == .instrument {
            if wasAudio {
                engine.setArmedTrack(nil)
                if !monitorsAlways { engine.closeInput() }
            }
            armedTrack = track
            engine.setLiveTrack(track)
            return
        }
        guard await engine.openInput() else { return }
        armedTrack = track
        engine.setArmedTrack(track)
    }

    /// Whether Record can start: an armed instrument track, or an armed audio track with the input open.
    var canRecord: Bool {
        guard let armedTrack, let track = store.project.track(armedTrack) else { return false }
        return track.kind == .instrument || engine.isInputOpen
    }

    /// Some audio track hears its input whether armed or not, so the input stays open.
    private var monitorsAlways: Bool {
        store.project.tracks.contains { $0.kind == .audio && $0.monitor == .input }
    }

    /// When an audio track hears its input. `in` opens the input now; leaving the last `in`
    /// closes it again unless a track is armed. Only on this choice — never on any edit, because
    /// opening the input reconfigures the session and stops the song.
    func setMonitor(_ mode: MonitorMode, on track: TrackID) async {
        do { try store.perform(.setMonitor(track, mode)) } catch { return }
        if monitorsAlways {
            _ = await engine.openInput()
        } else if armedTrack == nil, !isRecording {
            engine.closeInput()
        }
    }

    func record() {
        guard !isRecording, let track = armedTrack else { return }
        // Record starts the song. When it cannot run (audio that failed to come back), nothing
        // starts: a take over a stopped transport would be stamped at a frozen playhead, and a
        // MIDI take would outlive the core it was played on. Asked even while playing: a rebuild
        // that failed at the same rate leaves the transport playing over a stopped engine.
        guard engine.canPlay() else { return }
        if store.project.track(track)?.kind == .instrument {
            engine.live.startCapture()
            midiTrack = track
            isRecording = true
            if !engine.isPlaying { engine.play() }
            return
        }
        guard let file = documents.newTakeTarget() else { return }
        do {
            try engine.beginTake(url: file.url, channel: store.project.track(track)?.input ?? 0)
        } catch {
            documents.takeAbandoned(file)
            return
        }
        target = (track, file)
        isRecording = true
        if !engine.isPlaying { engine.play() }
    }

    func stopRecording() async {
        guard isRecording else { return }
        if midiTrack != nil {
            endMIDITake()
            return
        }
        isRecording = false
        let pending = target
        target = nil
        // The map at the stop, before anything else can change it: the one the take played against.
        let tempoMap = engine.playedTempoMap(of: store.project)
        guard let take = await engine.endTake(), let pending else {
            // Nothing to commit, so this take no longer holds the package (a rename waits while
            // a take runs).
            if let pending { documents.takeAbandoned(pending.file) }
            return
        }
        await documents.commitTake(take, target: pending.file, onto: pending.track, tempoMap: tempoMap)
    }

    /// Ends a running MIDI take at once and commits it. Synchronous, so it reads the rate and the
    /// position of the core the take was played on.
    private func endMIDITake() {
        guard isRecording, let track = midiTrack else { return }
        isRecording = false
        midiTrack = nil
        commitMIDI(engine.live.stopCapture(), onto: track)
    }

    /// The notes of a MIDI take as one new clip on `track`, placed on the bar it began in —
    /// one undo step. Each note sits where it was heard: the output latency is taken off.
    private func commitMIDI(_ events: [LiveRouter.Captured], onto track: TrackID) {
        guard let rate = engine.sampleRate, store.project.track(track) != nil else { return }
        let time = TimeConversion(tempoMap: engine.playedTempoMap(of: store.project), sampleRate: rate)
        let latency = engine.outputLatencySamples
        func tick(_ sample: Int64) -> Tick { time.tick(atSample: Swift.max(0, sample - latency)) }
        var take = MIDITake()
        for event in events {
            let at = tick(event.sample)
            switch event.status & 0xF0 {
            case 0x90 where event.data2 > 0: take.noteOn(pitch: Int(event.data1), velocity: Int(event.data2), at: at)
            case 0x80, 0x90: take.noteOff(pitch: Int(event.data1), at: at)
            case 0xE0: take.control(.pitchBend, value: Int(event.data1 & 0x7F) | Int(event.data2 & 0x7F) << 7, at: at)
            case 0xB0: take.control(.controller(number: Int(event.data1)), value: Int(event.data2), at: at)
            default: break
            }
        }
        let bar = MusicalTime.ticksPerBar(store.project.timeSignature)
        guard let clip = take.clip(endingAt: tick(engine.positionSample), bar: bar) else { return }
        let id = ClipID()
        let number = (store.project.track(track)?.clips.filter { $0.name.hasPrefix("Take ") }.count ?? 0) + 1
        try? store.perform([.createClip(track: track, id: id, name: "Take \(number)", length: clip.length),
                            .addNotes(id, clip.notes),
                            .setControls(id, clip.controls),
                            .placeClip(track: track, id: PlacementID(), clip: id, start: clip.start)],
                           title: "Record MIDI")
    }

    /// The transport's Stop: ends a take first, so the take never outlives the song playing.
    func stopTransport() async {
        await stopRecording()
        engine.stop()
        await inputFollowsSong()
    }

    /// The input is open while something wants it: an armed audio track, a take, a track that
    /// monitors always. A song opened, an undo or a deleted track can change that without going
    /// through `setMonitor`: the microphone stayed live for a song that uses none, and a song
    /// that monitors always opened deaf (audit 2026-10-23). Run on every song change. Never while
    /// playing: opening or closing reconfigures the session and stops the song, so it waits for
    /// Stop. It opens only for an opened song, never on an ordinary edit (`setMonitor`).
    /// A pause from outside — a followed clock's Stop, a call, lost headphones, a rate change — is a
    /// stop too: a song that monitors always and was opened while playing opens its input here, as
    /// it does at the transport's Stop (second night review, 2026-10-23: only the on-screen Stop
    /// did). It only ever opens, never closes: the same callback runs while an arm opens the input,
    /// before the arm is recorded.
    private func inputOpensAfterOutsidePause() async {
        guard !engine.isPlaying, !isRecording, monitorsAlways, store.documentGeneration != seenGeneration else { return }
        seenGeneration = store.documentGeneration
        if !engine.isInputOpen { _ = await engine.openInput() }
    }

    func inputFollowsSong() async {
        guard !engine.isPlaying, !isRecording else { return }
        // Read only past the wait: a song opened while playing is still news at Stop, or a song
        // that monitors always stays deaf after it (review 2026-10-23).
        let opened = store.documentGeneration != seenGeneration
        seenGeneration = store.documentGeneration
        if monitorsAlways {
            if opened, !engine.isInputOpen { _ = await engine.openInput() }
            return
        }
        guard engine.isInputOpen else { return }
        if let armed = armedTrack, store.project.track(armed)?.kind == .audio { return }
        engine.closeInput()
    }

    /// Before another song replaces this one: a running take ends and lands in the song it was
    /// recorded for, and one still being committed lands too. Without this the take ended against
    /// the next song and was lost (audit 2026-10-23).
    func finishTakes() async {
        await stopRecording()
        await documents.takesSettled()
    }

    /// A deleted track cannot stay armed.
    func trackRemoved(from project: Project) async {
        guard let armed = armedTrack, project.track(armed) == nil else { return }
        await toggleArm(armed)
    }
}
