import AVFoundation
import EchoelCore
import Foundation
import Observation
import os

/// A video take of the performance (wave W7, C4): the rear camera films while the song plays, and
/// the take lands on a video track where its first frame was heard — the start tick is stored, so
/// the picture sits on the song's timeline exactly as it was played. One camera, one producer
/// (`CameraArbitration`): a take suspends the camera pulse and gives the camera back when it ends.
/// The take records no sound; the song's mix is its sound.
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
        case denied
        case unavailable(String)
    }

    private(set) var state: State = .closed

    @ObservationIgnored private var camera: TakeCamera?
    @ObservationIgnored private var arbitration = CameraArbitration()
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
        guard state == .closed || state == .denied || isUnavailable else { return }
        guard CameraCapture.hasUsageDescription else {
            state = .unavailable("This build carries no camera permission text; the camera stays closed.")
            return
        }
        self.pulse = pulse
        self.engine = engine
        self.store = store
        self.documents = documents
        if pulse.isOn { _ = arbitration.choosePulse() }
        guard let steps = arbitration.beginTake() else { return }
        carry(steps)
        state = .opening
        let generation = arbitration.generation
        Task { @MainActor [weak self] in
            let granted = await CameraCapture.requestAccess()
            guard let self, self.arbitration.isCurrent(generation) else { return }
            guard granted else {
                self.state = .denied
                self.giveBack()
                return
            }
            let camera = TakeCamera { @Sendable [weak self] event in
                Task { @MainActor [weak self] in self?.cameraEvent(event) }
            }
            self.camera = camera
            do {
                try await camera.open()
            } catch {
                guard self.arbitration.isCurrent(generation) else { return }
                self.log.warning("take camera could not open: \(String(describing: error), privacy: .public)")
                camera.close()
                self.camera = nil
                self.state = .unavailable("The camera could not be opened — another app may be using it.")
                self.giveBack()
                return
            }
            guard self.arbitration.isCurrent(generation) else {
                camera.close()
                return
            }
            self.state = .ready
        }
    }

    /// Starts the song from where it stands and the take with it, onto `track` — or a new video
    /// track when the song has none to name.
    func record(onto track: TrackID?) {
        guard state == .ready, let camera, let documents, let engine else { return }
        guard let target = documents.newTakeTarget(fileExtension: "mov") else { return }
        take = (arbitration.generation, target, track)
        startTick = nil
        state = .recording
        if !engine.isPlaying { engine.play() }
        camera.record(to: target.url, generation: arbitration.generation)
    }

    /// Ends the take and the song with it; the take lands once its file is closed.
    func stopRecording() {
        guard state == .recording, let camera else { return }
        state = .finishing
        engine?.stop()
        camera.stopRecording()
    }

    /// Releases the camera to the pulse. A take still writing is finished and lands first.
    func close() {
        guard state != .closed else { return }
        if state == .recording { stopRecording() }
        guard state != .finishing else {
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
        state = .closed
    }

    private var isUnavailable: Bool {
        if case .unavailable = state { return true }
        return false
    }

    private func cameraEvent(_ event: TakeCamera.Event) {
        switch event {
        case .started(let generation):
            guard let take, take.generation == generation, let engine, let store else { return }
            // Where the first frame is heard: the take is laid there, not at a bar line.
            let project = store.project
            if let heard = engine.heardPosition(atHostTime: mach_absolute_time()) {
                startTick = Tick(Swift.max(0, heard.tick).rounded())
            } else {
                startTick = engine.playheadTick(in: project)
            }
        case let .finished(generation, url, usable):
            guard let take, take.generation == generation, let documents else { return }
            self.take = nil
            let start = startTick ?? 0
            startTick = nil
            if usable {
                Task { @MainActor [weak self] in
                    await documents.commitVideoTake(url, target: take.target, onto: take.track, at: start)
                    self?.finishedLanding()
                }
            } else {
                documents.takeAbandoned(take.target)
                try? FileManager.default.removeItem(at: url)
                finishedLanding()
            }
        }
    }

    private func finishedLanding() {
        guard state == .finishing else { return }
        if closesAfterTake { release() } else { state = .ready }
    }

    /// Carries out what the arbitration answered.
    private func carry(_ steps: [CameraArbitration.Step]) {
        for step in steps {
            switch step {
            case .suspendPulse:
                pulse?.takeHoldsCamera = true
                pulse?.suspend()
            case .openTake:
                pulse?.takeHoldsCamera = true
            case .resumePulse:
                pulse?.takeHoldsCamera = false
                pulse?.resume()
            case .closeTake:
                pulse?.takeHoldsCamera = false
            case .openPulse, .closePulse:
                break   // the pulse's own menu opens and closes it
            case .openSky, .closeSky:
                break   // until the arbitration is shared, the sky layer is not this recorder's to steer
            }
        }
    }

    /// The take is over: the camera goes back to a pulse that is on.
    private func giveBack() {
        guard let pulse else { return }
        // The musician may have turned the pulse on or off meanwhile.
        if pulse.isOn { _ = arbitration.choosePulse() } else { _ = arbitration.dropPulse() }
        carry(arbitration.endTake())
    }
}
