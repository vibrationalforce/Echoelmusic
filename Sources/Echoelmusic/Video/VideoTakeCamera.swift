// VideoTakeCamera.swift
// Echoel — One World C1 (founder 2026-10-15: "Video capture … Die workstation sollte alles
// können"). The rear camera as a RECORDER: one `AVCaptureSession` with one movie-file output,
// video only, writing a take to a file the Workstation then lands as a part on the video track
// through the same transaction as "Import Video" (`VideoImport.perform`).
//
// ⭐ IT IS NOT THE PULSE CAMERA, AND THE TWO NEVER RUN TOGETHER. `CameraCapture` owns the rear
// lens for rPPG (torch on, fingertip on the glass); one device cannot serve two sessions, so the
// card refuses to open while the camera pulse runs (`VideoTakeCard`). Same audio law as
// `CameraCapture`: the session never touches the app's `AVAudioSession` — the "camera kills
// audio" crash — and this file takes NO audio input (sound comes with the microphone landing).
//
// ⭐ OFF-MAIN BY CONSTRUCTION. Configuration, start, stop and the recording calls run on this
// object's own serial queue; the class is not `@MainActor`, so no closure here inherits main-actor
// isolation (2613/2618). The delegate answers on an AVFoundation queue and hands its result to a
// continuation under a lock — never a per-frame hop.
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

    /// The session the preview layer shows. Read on main only to hand it to the layer.
    let session = AVCaptureSession()
    private let output = AVCaptureMovieFileOutput()
    private let queue = DispatchQueue(label: "com.echoelmusic.videotake.session")
    /// Queue-only.
    private var configured = false

    /// The take's outcome and whoever waits for it — both under `lock`, because the delegate
    /// answers on an AVFoundation queue and the waiter arrives from the card.
    private let lock = NSLock()
    private var outcome: Result<URL, Failure>?
    private var waiter: CheckedContinuation<Result<URL, Failure>, Never>?

    // MARK: - Open / close

    /// Ask for the camera, configure once, run. Never throws; the card shows the failure.
    func open() async -> Result<Void, Failure> {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            guard await AVCaptureDevice.requestAccess(for: .video) else { return .failure(.denied) }
        } else if status != .authorized {
            return .failure(.denied)
        }
        return await withCheckedContinuation { (continuation: CheckedContinuation<Result<Void, Failure>, Never>) in
            queue.async { @Sendable [self] in
                continuation.resume(returning: self.configureAndRun())
            }
        }
    }

    /// Stop any take and the session. Safe to call more than once.
    func close() {
        queue.async { @Sendable [self] in
            if self.output.isRecording { self.output.stopRecording() }
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    private func configureAndRun() -> Result<Void, Failure> {
        if !configured {
            // Before `beginConfiguration`, as in `CameraCapture`: the session must never touch
            // the app's audio session.
            session.automaticallyConfiguresApplicationAudioSession = false
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device) else { return .failure(.noCamera) }
            session.beginConfiguration()
            if session.canSetSessionPreset(.high) { session.sessionPreset = .high }
            guard session.canAddInput(input), session.canAddOutput(output) else {
                session.commitConfiguration()
                return .failure(.configuration)
            }
            session.addInput(input)
            session.addOutput(output)
            session.commitConfiguration()
            configured = true
        }
        if !session.isRunning { session.startRunning() }
        return session.isRunning ? .success(()) : .failure(.configuration)
    }

    // MARK: - Recording

    /// Start a take into `url`. Answers whether recording began.
    func startRecording(to url: URL) async -> Bool {
        resetTake()
        return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            queue.async { @Sendable [self] in
                guard self.session.isRunning, !self.output.isRecording else {
                    continuation.resume(returning: false)
                    return
                }
                if let connection = self.output.connection(with: .video),
                   connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90   // portrait, the way the phone is held
                }
                self.output.startRecording(to: url, recordingDelegate: self)
                continuation.resume(returning: true)
            }
        }
    }

    /// Stop the take and wait for the file. A take that already ended on its own (an
    /// interruption, a full disk) answers at once.
    func stopRecording() async -> Result<URL, Failure> {
        await withCheckedContinuation { (continuation: CheckedContinuation<Result<URL, Failure>, Never>) in
            lock.lock()
            if let done = outcome {
                outcome = nil
                lock.unlock()
                continuation.resume(returning: done)
                return
            }
            waiter = continuation
            lock.unlock()
            queue.async { @Sendable [self] in
                if self.output.isRecording {
                    self.output.stopRecording()
                } else {
                    self.deliver(.failure(.recording))
                }
            }
        }
    }

    /// A synchronous helper, so the lock is never taken in an `async` body (`NSLock` is
    /// `noasync`).
    private func resetTake() {
        lock.lock()
        outcome = nil
        waiter = nil
        lock.unlock()
    }

    /// Hand a result to the waiter, or keep it for the next `stopRecording`.
    private func deliver(_ result: Result<URL, Failure>) {
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
        deliver(written ? .success(outputFileURL) : .failure(.recording))
    }
}
#endif
