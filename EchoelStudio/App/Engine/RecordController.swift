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

    init(engine: AudioEngine, documents: DocumentController, store: ProjectStore) {
        self.engine = engine
        self.documents = documents
        self.store = store
    }

    /// Arms `track`, or disarms it when it is the armed one.
    func toggleArm(_ track: TrackID) async {
        if isRecording { await stopRecording() }
        if armedTrack == track {
            armedTrack = nil
            engine.setArmedTrack(nil)
            if !monitorsAlways { engine.closeInput() }
            return
        }
        guard await engine.openInput() else { return }
        armedTrack = track
        engine.setArmedTrack(track)
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
        guard !isRecording, let track = armedTrack, let file = documents.newTakeTarget() else { return }
        do {
            try engine.beginTake(url: file.url, channel: store.project.track(track)?.input ?? 0)
        } catch {
            return
        }
        target = (track, file)
        isRecording = true
        if !engine.isPlaying { engine.play() }
    }

    func stopRecording() async {
        guard isRecording else { return }
        isRecording = false
        let pending = target
        target = nil
        // The map at the stop, before anything else can change it: the one the take played against.
        let tempoMap = engine.playedTempoMap(of: store.project)
        guard let take = await engine.endTake(), let pending else { return }
        await documents.commitTake(take, target: pending.file, onto: pending.track, tempoMap: tempoMap)
    }

    /// The transport's Stop: ends a take first, so the take never outlives the song playing.
    func stopTransport() async {
        await stopRecording()
        engine.stop()
    }

    /// A deleted track cannot stay armed.
    func trackRemoved(from project: Project) async {
        guard let armed = armedTrack, project.track(armed) == nil else { return }
        await toggleArm(armed)
    }
}
