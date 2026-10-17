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
            engine.closeInput()
            return
        }
        guard await engine.openInput() else { return }
        armedTrack = track
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
        guard let take = await engine.endTake(), let pending else { return }
        await documents.commitTake(take, target: pending.file, onto: pending.track)
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
