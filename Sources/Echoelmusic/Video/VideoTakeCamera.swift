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
// ⚠️ NOT DEVICE-VERIFIED. NEEDS-FOUNDER-VERIFY: Workstation → Add → Record Video, record ten
// seconds, Stop — the take appears on the video track and plays with the song.

#if canImport(AVFoundation)
import AVFoundation
import Foundation

final class VideoTakeCamera: NSObject, @unchecked Sendable {

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

    /// The take's files and whoever waits for them — under `lock`, because the delegate answers
    /// on an AVFoundation queue and the waiter arrives from the card.
    private let lock = NSLock()
    private var expected = 0
    private var finished: [URL] = []
    private var failedCount = 0
    private var outcome: Result<[URL], Failure>?
    private var waiter: CheckedContinuation<Result<[URL], Failure>, Never>?

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
            let wired = wantsBoth ? wireBoth(back: back, backInput: backInput) : wireRear(backInput)
            session.commitConfiguration()
            guard let wired else { return .failure(.configuration) }
            bothWired = wired
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
        // Two full-quality lenses can exceed what the phone sustains: then the rear lens alone.
        if multi.hardwareCost > 1.0 {
            multi.removeConnection(frontTake)
            return false
        }
        return true
    }

    // MARK: - Recording

    /// Start a take — the rear lens into `url`, the front one into `frontURL` when both are
    /// wired. Answers whether recording began.
    func startRecording(to url: URL, frontURL: URL) async -> Bool {
        return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            queue.async { @Sendable [self] in
                guard self.session.isRunning, !self.output.isRecording, !self.frontOutput.isRecording else {
                    continuation.resume(returning: false)
                    return
                }
                let lenses = self.bothWired ? 2 : 1
                self.resetTake(expecting: lenses)
                Self.portrait(self.output)
                self.output.startRecording(to: url, recordingDelegate: self)
                if self.bothWired {
                    Self.portrait(self.frontOutput)
                    self.frontOutput.startRecording(to: frontURL, recordingDelegate: self)
                }
                continuation.resume(returning: true)
            }
        }
    }

    /// Upright, the way the phone is held; the front take unmirrored, as a camera records.
    private static func portrait(_ output: AVCaptureMovieFileOutput) {
        guard let connection = output.connection(with: .video) else { return }
        if connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = false
        }
    }

    /// Stop the take and wait for its files, rear first. A take that already ended on its own
    /// (an interruption, a full disk) answers at once.
    func stopRecording() async -> Result<[URL], Failure> {
        await withCheckedContinuation { (continuation: CheckedContinuation<Result<[URL], Failure>, Never>) in
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
                let anyRecording = self.output.isRecording || self.frontOutput.isRecording
                if self.output.isRecording { self.output.stopRecording() }
                if self.frontOutput.isRecording { self.frontOutput.stopRecording() }
                if !anyRecording { self.settle(.failure(.recording)) }
            }
        }
    }

    /// A synchronous helper, so the lock is never taken in an `async` body (`NSLock` is
    /// `noasync`). A waiter left over from an earlier take is answered, never stranded.
    private func resetTake(expecting lenses: Int) {
        lock.lock()
        let stranded = waiter
        expected = lenses
        finished = []
        failedCount = 0
        outcome = nil
        waiter = nil
        lock.unlock()
        stranded?.resume(returning: .failure(.recording))
    }

    /// One output finished. When every lens of the take has answered, the take settles: the
    /// files that were written (rear first), or a failure when none was.
    fileprivate func fileFinished(_ url: URL?, isFront: Bool) {
        lock.lock()
        if let url {
            if isFront { finished.append(url) } else { finished.insert(url, at: 0) }
        } else {
            failedCount += 1
        }
        let complete = finished.count + failedCount >= expected
        let files = finished
        lock.unlock()
        guard complete else { return }
        settle(files.isEmpty ? .failure(.recording) : .success(files))
    }

    /// Hand a result to the waiter, or keep it for the next `stopRecording`.
    private func settle(_ result: Result<[URL], Failure>) {
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
        fileFinished(written ? outputFileURL : nil, isFront: output === frontOutput)
    }
}
#endif
