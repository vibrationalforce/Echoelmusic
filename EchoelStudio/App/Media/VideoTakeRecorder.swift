import AVFoundation
import EchoelCore
import Foundation
import Observation
import os

/// A video take of the performance (wave W7, C4): the back or the front camera films while the
/// song plays, and the take lands on a video track where its first frame was heard — the start
/// tick is stored, so the picture sits on the song's timeline exactly as it was played. One camera, one producer
/// (`CameraArbitration`): a take suspends the camera pulse and gives the camera back when it ends.
/// The take records no sound; the song's mix is its sound. The camera's life — and what a call,
/// Siri or a camera error does to a take — is `VideoTakeLifecycle`: a take cut short lands with
/// what was filmed, and says so. The lens changes only while the picture shows, never during a
/// take; either lens is the one camera the arbitration hands out.
@MainActor
@Observable
final class VideoTakeRecorder {
    enum State: Equatable {
        case closed
        case opening
        /// The camera shows its picture; Record starts a take.
        case ready
        case recording
        /// The file is being closed.
        case finishing
        /// The last take is on the song; `cutShort` when iOS or an error ended it, not Stop.
        case landed(cutShort: Bool)
        /// iOS holds the camera (a call, Siri, another app); the picture comes back when it ends.
        case interrupted
        /// The camera stopped with an error.
        case failed
        case denied
        case unavailable(String)
    }

    /// Why the camera did not open at all.
    private enum Refusal: Equatable {
        case denied
        case unavailable(String)
    }

    private(set) var life = VideoTakeLifecycle()
    private var refusal: Refusal?

    var state: State {
        switch refusal {
        case .denied: return .denied
        case .unavailable(let reason): return .unavailable(reason)
        case nil: break
        }
        switch life.phase {
        case .closed: return .closed
        case .opening: return .opening
        case .ready: return .ready
        case .recording: return .recording
        case .finishing: return .finishing
        case .landed: return .landed(cutShort: life.cutShort)
        case .interrupted: return .interrupted
        case .failed: return .failed
        }
    }

    /// The lens the next take films through.
    private(set) var lens: TakeOrientation.Lens = .back

    /// Record may start a take now — and the lens may change.
    var canRecord: Bool { refusal == nil && life.canRecord }

    @ObservationIgnored private var camera: TakeCamera?
    @ObservationIgnored private var pulse: CameraPulseSource?
    @ObservationIgnored private var take: (generation: UInt64, target: DocumentController.TakeTarget, track: TrackID?)?
    @ObservationIgnored private var startTick: Tick?
    /// Closed while the take's file was still being written: the camera goes once it has landed.
    @ObservationIgnored private var closesAfterTake = false
    @ObservationIgnored private weak var engine: AudioEngine?
    @ObservationIgnored private weak var store: ProjectStore?
    @ObservationIgnored private weak var documents: DocumentController?
    @ObservationIgnored private let log = Logger(subsystem: "com.echoelmusic.studio", category: "video")

    /// The capture session the preview shows, while the camera is open.
    var session: AVCaptureSession? { camera?.session }

    /// Takes the camera — from the pulse if it holds it — and shows its picture.
    func open(pulse: CameraPulseSource, engine: AudioEngine, store: ProjectStore, documents: DocumentController) {
        guard life.phase == .closed else { return }
        refusal = nil
        guard CameraCapture.hasUsageDescription else {
            refusal = .unavailable("This build carries no camera permission text; the camera stays closed.")
            return
        }
        self.pulse = pulse
        self.engine = engine
        self.store = store
        self.documents = documents
        // The one arbitration lives with the camera's owner (take > pulse > sky).
        guard let holder = pulse.beginTake() else { return }
        guard let generation = life.open() else {
            giveBack()
            return
        }
        Task { @MainActor [weak self] in
            let granted = await CameraCapture.requestAccess()
            guard let self, self.isCurrent(holder: holder, generation: generation) else { return }
            guard granted else {
                self.life.close()
                self.refusal = .denied
                self.giveBack()
                return
            }
            let camera = TakeCamera(lens: self.lens, generation: generation) { @Sendable [weak self] event in
                Task { @MainActor [weak self] in self?.cameraEvent(event) }
            }
            self.camera = camera
            do {
                try await camera.open()
            } catch {
                guard self.isCurrent(holder: holder, generation: generation) else { return }
                self.log.warning("take camera could not open: \(String(describing: error), privacy: .public)")
                camera.close()
                self.camera = nil
                self.life.close()
                self.refusal = .unavailable("The camera could not be opened. Another app may be using it: close it and try again.")
                self.giveBack()
                return
            }
            guard self.isCurrent(holder: holder, generation: generation) else {
                camera.close()
                return
            }
            self.life.handle(.opened, stamped: generation)
        }
    }

    /// Starts the song from where it stands and the take with it, onto `track` — or a new video
    /// track when the song has none to name.
    func record(onto track: TrackID?) {
        guard canRecord, let camera, let documents, let engine else { return }
        guard let target = documents.newTakeTarget(fileExtension: "mov") else { return }
        guard life.record() else { return }
        take = (life.generation, target, track)
        startTick = nil
        if !engine.isPlaying { engine.play() }
        camera.record(to: target.url, generation: life.generation)
    }

    /// Turns to the other lens. Refused while a take is filmed or saved, and while iOS holds the
    /// camera; the camera stays with this take (the pulse stays suspended), only its lens changes.
    func flipLens() {
        guard canRecord, let camera else { return }
        let before = lens
        let next: TakeOrientation.Lens = before == .back ? .front : .back
        guard life.changeLens() else { return }
        let generation = life.generation
        lens = next
        Task { @MainActor [weak self] in
            let switched = await camera.switchLens(to: next, generation: generation)
            guard let self, self.life.isCurrent(generation) else { return }
            if !switched {
                self.log.warning("take camera could not change its lens")
                self.lens = before
            }
            self.life.handle(.opened, stamped: generation)
        }
    }

    /// Ends the take and the song with it; the take lands once its file is closed.
    func stopRecording() {
        guard life.phase == .recording, let camera else { return }
        life.stop()
        engine?.stop()
        camera.stopRecording()
    }

    /// Releases the camera to the pulse. A take still writing is finished and lands first.
    func close() {
        guard life.phase != .closed || refusal != nil else { return }
        if life.phase == .recording { stopRecording() }
        guard life.phase != .finishing else {
            closesAfterTake = true
            return
        }
        release()
    }

    private func release() {
        closesAfterTake = false
        camera?.close()
        camera = nil
        giveBack()
        life.close()
        refusal = nil
    }

    /// The arbitration still hands this take the camera, and the camera is still the one opened.
    private func isCurrent(holder: UInt64, generation: UInt64) -> Bool {
        pulse?.isCameraCurrent(holder) == true && life.isCurrent(generation)
    }

    /// Two seconds in host-clock units. No camera reports its first frame that late, so a frame
    /// time further back than this is a failed conversion and the report's own time is used.
    private static let longestCaptureLead: UInt64 = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        let numer = UInt64(Swift.max(info.numer, 1))
        let denom = UInt64(Swift.max(info.denom, 1))
        return 2_000_000_000 * denom / numer
    }()

    private func cameraEvent(_ event: TakeCamera.Event) {
        switch event {
        case let .started(generation, reportedHostTime, frameHostTime):
            guard life.handle(.started, stamped: generation), let take, take.generation == generation,
                  let engine, let store else { return }
            // Where the first frame is heard: the take is laid there, not at a bar line. The
            // frame's own capture time where the camera gives it; else when iOS reported the start,
            // stamped on the camera's side before any hop to this actor.
            let project = store.project
            let start = VideoTakeLifecycle.startHostTime(frame: frameHostTime, reported: reportedHostTime,
                                                         longestLead: Self.longestCaptureLead)
            if let heard = engine.heardPosition(atHostTime: start) {
                startTick = Tick(Swift.max(0, heard.tick).rounded())
            } else {
                startTick = engine.playheadTick(in: project)
            }
        case let .finished(generation, url, usable):
            guard let take, take.generation == generation, life.isCurrent(generation), let documents else { return }
            self.take = nil
            let start = startTick ?? 0
            startTick = nil
            if usable {
                Task { @MainActor [weak self] in
                    // "On the song" only when it is: a take that cannot be read, that the song
                    // refuses or whose song was closed meanwhile is said as such.
                    let placed = await documents.commitVideoTake(url, target: take.target, onto: take.track, at: start)
                    self?.finishedLanding(generation: generation, as: .afterCommit(placed: placed))
                }
            } else {
                documents.takeAbandoned(take.target)
                try? FileManager.default.removeItem(at: url)
                finishedLanding(generation: generation, as: .fileClosed(usable: false))
            }
        case .interrupted(let generation):
            endsTheTake(.interruptionBegan, stamped: generation)
        case .resumed(let generation):
            life.handle(.interruptionEnded, stamped: generation)
        case .failed(let generation):
            endsTheTake(.runtimeError, stamped: generation)
        }
    }

    /// An interruption or an error: a running take is cut short — its file closes and it lands —
    /// and the song stops with it, as Stop would.
    private func endsTheTake(_ event: VideoTakeLifecycle.Event, stamped generation: UInt64) {
        let wasRecording = life.phase == .recording
        guard life.handle(event, stamped: generation), wasRecording, life.phase == .finishing else { return }
        engine?.stop()
        camera?.stopRecording()
    }

    /// The take's file is closed and, when usable, on the song — or `notPlaced`: the camera films
    /// the next one, or goes, when it was closed meanwhile.
    private func finishedLanding(generation: UInt64, as outcome: VideoTakeLifecycle.Event) {
        life.handle(outcome, stamped: generation)
        if closesAfterTake { release() }
    }

    /// The take is over: the camera goes back to a pulse that is on, else to a waiting sky view.
    private func giveBack() {
        pulse?.endTake()
    }
}
