// VideoTakeCamera.swift
// Echoel — One World C1 (founder 2026-10-15: "Video capture … Die workstation sollte alles
// können"). The rear camera as a RECORDER: one `AVCaptureSession` with one movie-file output,
// video only, writing a take to a file the Workstation then lands as a part on the video track
// through the same transaction as "Import Video" (`VideoImport.perform`).
//
// ⭐ IT IS NOT THE PULSE CAMERA, AND THE TWO NEVER RUN TOGETHER. `CameraCapture` owns the rear
// lens for rPPG (torch on, fingertip on the glass); one device cannot serve two sessions, so
// opening the card stops the camera pulse and says so — production first (`VideoTakeCard`). Same audio law as
// `CameraCapture`: the session never touches the app's `AVAudioSession` — the "camera kills
// audio" crash — and this file takes NO audio input (sound comes with the microphone landing).
//
// ⭐ OFF-MAIN BY CONSTRUCTION. Configuration, start, stop and the recording calls run on this
// object's own serial queue; the class is not `@MainActor`, so no closure here inherits main-actor
// isolation (2613/2618). The delegate answers on an AVFoundation queue and hands its result to a
// continuation under a lock — never a per-frame hop.
//
// ⭐ M1 — BOTH LENSES (founder 2026-10-15, the YoloBox replacement): with `bothCameras` and a
// phone that supports it (`AVCaptureMultiCamSession.isMultiCamSupported`), ONE multi-cam session
// records the rear AND the front camera into two files at once — two movie-file outputs, each
// wired to its own lens by an explicit connection (Apple, WWDC19 249). The rear lens stays the
// MAIN take (it lands on the shown video track); the front take lands on the next video track.
// A phone that cannot (no multi-cam, or a hardware cost above 1.0) falls back to the rear lens
// alone, and `open()` answers false so the card can say so. The two files start a few milliseconds apart (two
// calls on one queue) — not frame-locked; audio-based alignment is M3.
//
// ⭐ ONE TAKE AT A TIME, BY IDENTITY (review 2026-10-15, ChatGPT/Astra findings 1, 5, 8, 9, 10).
// A take owns the two file URLs it was started with; a delegate answer for any other URL is not
// this take's and is ignored. A new take cannot start while the last one is still FINALISING its
// files (recording stopped, delegate not yet answered) — Apple separates "recording ended" from
// "file finished", and a second Stop in that gap waits instead of failing. The result names each
// lens (`TakeFiles`), so a failed rear take never relabels the front file as the rear one. A file
// AVFoundation reports as unusable is deleted. The multi-cam cost is re-checked AFTER
// `commitConfiguration()` (Apple's AVMultiCamPiP does the same). Each take is turned the way the
// phone is held, through `AVCaptureDevice.RotationCoordinator`, not a fixed 90°.
//
// ⚠️ NOT DEVICE-VERIFIED. NEEDS-FOUNDER-VERIFY: Workstation → Add → Record Video, record ten
// seconds, Stop — the take appears on the video track and plays with the song.

#if canImport(AVFoundation)
import AVFoundation
import Foundation

final class VideoTakeCamera: NSObject, @unchecked Sendable {

    /// What one take wrote, per lens. Either may be nil — a lens that failed, or the front lens of
    /// a single-lens take. Never both: a take with no file is a `.recording` failure.
    struct TakeFiles: Equatable, Sendable {
        let rear: URL?
        let front: URL?
    }

    enum Failure: Error, Equatable, Sendable {
        case denied
        case noCamera
        case configuration
        case recording
    }

    /// One session: a multi-cam session when both lenses were asked for and the phone has them.
    let session: AVCaptureSession
    /// The live picture of the REAR lens, built here (on main, where the card constructs this
    /// object) and connected to the rear lens by the session itself. The card hosts it.
    let previewLayer: AVCaptureVideoPreviewLayer
    /// The rear take — the main one.
    private let output = AVCaptureMovieFileOutput()
    /// The front take, recorded only by a multi-cam session.
    private let frontOutput = AVCaptureMovieFileOutput()
    private let wantsBoth: Bool
    private let queue = DispatchQueue(label: "com.echoelmusic.videotake.session")
    /// Queue-only.
    private var configured = false
    /// Queue-only: the front lens is wired and recording with the rear one.
    private var bothWired = false
    /// Queue-only: the front connection, kept so a post-commit cost check can remove it.
    private var frontConnection: AVCaptureConnection?
    /// Queue-only: the upright angle for each lens, as the phone is held.
    private var rearRotation: AVCaptureDevice.RotationCoordinator?
    private var frontRotation: AVCaptureDevice.RotationCoordinator?

    /// The take and whoever waits for it — under `lock`, because the delegate answers on an
    /// AVFoundation queue and the waiter arrives from the card.
    private let lock = NSLock()
    /// The files of the take in flight (rear, front), until each one has answered. Empty = no take
    /// is finalising.
    private var pendingRear: URL?
    private var pendingFront: URL?
    private var writtenRear: URL?
    private var writtenFront: URL?
    private var outcome: Result<TakeFiles, Failure>?
    private var waiter: CheckedContinuation<Result<TakeFiles, Failure>, Never>?

    /// Whether this phone can record both lenses at once.
    static var bothCamerasSupported: Bool { AVCaptureMultiCamSession.isMultiCamSupported }

    init(bothCameras: Bool) {
        let both = bothCameras && AVCaptureMultiCamSession.isMultiCamSupported
        let made: AVCaptureSession = both ? AVCaptureMultiCamSession() : AVCaptureSession()
        wantsBoth = both
        session = made
        previewLayer = both ? AVCaptureVideoPreviewLayer(sessionWithNoConnection: made)
                            : AVCaptureVideoPreviewLayer(session: made)
        super.init()
        previewLayer.videoGravity = .resizeAspectFill
    }

    // MARK: - Open / close

    /// Ask for the camera, configure once, run. Answers whether BOTH lenses are recording
    /// (false = the rear lens alone). Never throws; the card shows the failure.
    func open() async -> Result<Bool, Failure> {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            guard await AVCaptureDevice.requestAccess(for: .video) else { return .failure(.denied) }
        } else if status != .authorized {
            return .failure(.denied)
        }
        return await withCheckedContinuation { (continuation: CheckedContinuation<Result<Bool, Failure>, Never>) in
            queue.async { @Sendable [self] in
                continuation.resume(returning: self.configureAndRun())
            }
        }
    }

    /// Stop any take and the session. Safe to call more than once.
    func close() {
        queue.async { @Sendable [self] in self.shutDown() }
    }

    /// `close()`, answered once the session has stopped — so a new recorder (the lens choice
    /// changed) never asks for a camera this one still holds.
    func closeAndWait() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async { @Sendable [self] in
                self.shutDown()
                continuation.resume()
            }
        }
    }

    /// Queue-only.
    private func shutDown() {
        if output.isRecording { output.stopRecording() }
        if frontOutput.isRecording { frontOutput.stopRecording() }
        if session.isRunning { session.stopRunning() }
    }

    private func configureAndRun() -> Result<Bool, Failure> {
        if !configured {
            // Before `beginConfiguration`, as in `CameraCapture`: the session must never touch
            // the app's audio session.
            session.automaticallyConfiguresApplicationAudioSession = false
            guard let back = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let backInput = try? AVCaptureDeviceInput(device: back) else { return .failure(.noCamera) }
            session.beginConfiguration()
            var wired = wantsBoth ? wireBoth(back: back, backInput: backInput) : wireRear(backInput)
            session.commitConfiguration()
            guard wired != nil else { return .failure(.configuration) }
            // Two full-quality lenses can exceed what the phone sustains. The cost is read AFTER the
            // commit — the configuration it describes is then the one that will run.
            if wired == true, let multi = session as? AVCaptureMultiCamSession, multi.hardwareCost > 1.0,
               let front = frontConnection {
                multi.beginConfiguration()
                multi.removeConnection(front)
                multi.commitConfiguration()
                frontConnection = nil
                wired = false
            }
            bothWired = wired ?? false
            rearRotation = AVCaptureDevice.RotationCoordinator(device: back, previewLayer: nil)
            if bothWired, let front = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
                frontRotation = AVCaptureDevice.RotationCoordinator(device: front, previewLayer: nil)
            }
            configured = true
        }
        if !session.isRunning { session.startRunning() }
        return session.isRunning ? .success(bothWired) : .failure(.configuration)
    }

    /// The single-lens session: implicit connections, as any `AVCaptureSession`.
    private func wireRear(_ backInput: AVCaptureDeviceInput) -> Bool? {
        if session.canSetSessionPreset(.high) { session.sessionPreset = .high }
        guard session.canAddInput(backInput), session.canAddOutput(output) else { return nil }
        session.addInput(backInput)
        session.addOutput(output)
        return false
    }

    /// The multi-cam session: every connection explicit. Answers true when both lenses are
    /// wired, false when only the rear one could be (the phone falls back), nil on failure.
    private func wireBoth(back: AVCaptureDevice, backInput: AVCaptureDeviceInput) -> Bool? {
        guard let multi = session as? AVCaptureMultiCamSession,
              multi.canAddInput(backInput), multi.canAddOutput(output) else { return nil }
        multi.addInputWithNoConnections(backInput)
        multi.addOutputWithNoConnections(output)
        guard let backPort = backInput.ports(for: .video, sourceDeviceType: back.deviceType,
                                             sourceDevicePosition: .back).first else { return nil }
        let backTake = AVCaptureConnection(inputPorts: [backPort], output: output)
        let backPreview = AVCaptureConnection(inputPort: backPort, videoPreviewLayer: previewLayer)
        guard multi.canAddConnection(backTake), multi.canAddConnection(backPreview) else { return nil }
        multi.addConnection(backTake)
        multi.addConnection(backPreview)

        guard let front = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let frontInput = try? AVCaptureDeviceInput(device: front),
              multi.canAddInput(frontInput), multi.canAddOutput(frontOutput) else { return false }
        multi.addInputWithNoConnections(frontInput)
        multi.addOutputWithNoConnections(frontOutput)
        guard let frontPort = frontInput.ports(for: .video, sourceDeviceType: front.deviceType,
                                               sourceDevicePosition: .front).first else { return false }
        let frontTake = AVCaptureConnection(inputPorts: [frontPort], output: frontOutput)
        guard multi.canAddConnection(frontTake) else { return false }
        multi.addConnection(frontTake)
        frontConnection = frontTake
        return true
    }

    // MARK: - Recording

    /// Start a take — the rear lens into `url`, the front one into `frontURL` when both are
    /// wired. Answers whether recording began.
    func startRecording(to url: URL, frontURL: URL) async -> Bool {
        return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            queue.async { @Sendable [self] in
                guard self.session.isRunning, !self.output.isRecording, !self.frontOutput.isRecording,
                      self.beginTake(rear: url, front: self.bothWired ? frontURL : nil) else {
                    continuation.resume(returning: false)   // the last take is still finalising its files
                    return
                }
                Self.upright(self.output, self.rearRotation)
                self.output.startRecording(to: url, recordingDelegate: self)
                if self.bothWired {
                    Self.upright(self.frontOutput, self.frontRotation)
                    self.frontOutput.startRecording(to: frontURL, recordingDelegate: self)
                }
                continuation.resume(returning: true)
            }
        }
    }

    /// Upright, the way the phone is held NOW (each lens has its own angle); the front take
    /// unmirrored, as a camera records. Without a coordinator the phone's default portrait angle.
    private static func upright(_ output: AVCaptureMovieFileOutput, _ rotation: AVCaptureDevice.RotationCoordinator?) {
        guard let connection = output.connection(with: .video) else { return }
        let angle = rotation?.videoRotationAngleForHorizonLevelCapture ?? 90
        if connection.isVideoRotationAngleSupported(angle) { connection.videoRotationAngle = angle }
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = false
        }
    }

    /// Stop the take and wait for its files. A take that already ended on its own (an
    /// interruption, a full disk) answers at once; a take whose files are still finalising (a
    /// second Stop) waits for them instead of failing.
    func stopRecording() async -> Result<TakeFiles, Failure> {
        await withCheckedContinuation { (continuation: CheckedContinuation<Result<TakeFiles, Failure>, Never>) in
            lock.lock()
            if let done = outcome {
                outcome = nil
                lock.unlock()
                continuation.resume(returning: done)
                return
            }
            let earlier = waiter
            waiter = continuation
            lock.unlock()
            earlier?.resume(returning: .failure(.recording))   // a second Stop never strands the first
            queue.async { @Sendable [self] in
                if self.output.isRecording { self.output.stopRecording() }
                if self.frontOutput.isRecording { self.frontOutput.stopRecording() }
                // Nothing recording AND nothing finalising: there is no take to wait for.
                if !self.takeIsPending() { self.settle(.failure(.recording)) }
            }
        }
    }

    /// A synchronous helper, so the lock is never taken in an `async` body (`NSLock` is
    /// `noasync`). Starts a take that owns `rear` (and `front`), or refuses while the last take
    /// is still finalising. A waiter or a result left over from an earlier take is answered,
    /// never stranded and never handed to this one.
    private func beginTake(rear: URL, front: URL?) -> Bool {
        lock.lock()
        guard pendingRear == nil, pendingFront == nil else {
            lock.unlock()
            return false
        }
        let stranded = waiter
        pendingRear = rear
        pendingFront = front
        writtenRear = nil
        writtenFront = nil
        outcome = nil
        waiter = nil
        lock.unlock()
        stranded?.resume(returning: .failure(.recording))
        return true
    }

    /// Whether a take's files are still owed (recording, or finalising after Stop).
    private func takeIsPending() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return pendingRear != nil || pendingFront != nil
    }

    /// One output finished writing `url`. An answer for a URL this take does not own is an
    /// earlier take's and is ignored. When every lens has answered, the take settles with the
    /// files that were written, each under its own lens — or a failure when none was.
    fileprivate func fileFinished(_ url: URL, written: Bool) {
        lock.lock()
        let isRear = url == pendingRear, isFront = url == pendingFront
        guard isRear || isFront else {
            lock.unlock()
            return
        }
        if isRear {
            pendingRear = nil
            if written { writtenRear = url }
        } else {
            pendingFront = nil
            if written { writtenFront = url }
        }
        let complete = pendingRear == nil && pendingFront == nil
        let files = TakeFiles(rear: writtenRear, front: writtenFront)
        lock.unlock()
        // A file AVFoundation calls unusable is not left behind.
        if !written { try? FileManager.default.removeItem(at: url) }
        guard complete else { return }
        settle(files.rear == nil && files.front == nil ? .failure(.recording) : .success(files))
    }

    /// Hand a result to the waiter, or keep it for the next `stopRecording`.
    private func settle(_ result: Result<TakeFiles, Failure>) {
        lock.lock()
        if let waiting = waiter {
            waiter = nil
            lock.unlock()
            waiting.resume(returning: result)
            return
        }
        if outcome == nil { outcome = result }
        lock.unlock()
    }
}

extension VideoTakeCamera: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection], error: Error?) {
        // AVFoundation can report an error on a take that WAS written (a size or duration
        // limit); its own flag says whether the file is usable.
        var written = error == nil
        if let error = error as NSError?,
           let finished = error.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool {
            written = finished
        }
        fileFinished(outputFileURL, written: written)
    }
}
#endif
