import AVFoundation
import EchoelCore
import Foundation
import os
#if canImport(UIKit)
import UIKit
#endif

/// The rear camera writing a video take (wave W7, C4): one capture session with a movie output and
/// no microphone — the take's sound is the song's mix, never the room. Its own serial queue does
/// every session call; the two recording callbacks come back stamped with the take's generation,
/// so the owner drops one that arrives after a newer take began. Holds the camera only while open.
/// Each take is turned the way the phone is held when it begins (`TakeOrientation`, read from the
/// lens's `AVCaptureDevice.RotationCoordinator`) and keeps that angle until it ends. A call, Siri
/// or another app taking the camera, and a session error, are reported too (`VideoTakeLifecycle`):
/// iOS closes a running take's file itself, and the take lands with what was filmed.
final class TakeCamera: NSObject, @unchecked Sendable, AVCaptureFileOutputRecordingDelegate {
    enum Event: Sendable {
        /// The file is being written: the first frame is in.
        case started(generation: UInt64)
        /// The file is closed; `usable` says whether it holds the take.
        case finished(generation: UInt64, url: URL, usable: Bool)
        /// iOS took the camera (a call, Siri, Control Centre, another app).
        case interrupted(generation: UInt64)
        /// iOS gave the camera back.
        case resumed(generation: UInt64)
        /// The session stopped with an error.
        case failed(generation: UInt64)
    }

    enum OpenError: Error {
        case noCamera
        case configurationFailed
    }

    let session = AVCaptureSession()
    private let output = AVCaptureMovieFileOutput()
    private let queue = DispatchQueue(label: "com.echoelmusic.studio.take-camera")
    private let onEvent: @Sendable (Event) -> Void
    private let lock = NSLock()
    private var current: UInt64 = 0
    /// Queue-only: the lens's rotation coordinator and the angle the next take is written at.
    private var rotation: AVCaptureDevice.RotationCoordinator?
    private var orientation = TakeOrientation()
    /// Queue-only: the observers of the session, while it is open; whether it is meant to run and
    /// whether iOS holds it.
    private var observers: [NSObjectProtocol] = []
    private var shouldRun = false
    private var interrupted = false
    private let log = Logger(subsystem: "com.echoelmusic.studio", category: "video")

    /// `generation` stamps the events of this camera until a take names its own.
    init(generation: UInt64, onEvent: @escaping @Sendable (Event) -> Void) {
        self.current = generation
        self.onEvent = onEvent
        super.init()
    }

    /// Configures the rear camera for 1080p and starts the session, off the main thread.
    func open() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [self] in
                do {
                    try configure()
                    shouldRun = true
                    installObservers()
                    session.startRunning()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func configure() throws {
        guard session.inputs.isEmpty else { return }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw OpenError.noCamera
        }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = session.canSetSessionPreset(.hd1920x1080) ? .hd1920x1080 : .high
        guard let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input),
              session.canAddOutput(output) else {
            throw OpenError.configurationFailed
        }
        session.addInput(input)
        session.addOutput(output)
        rotation = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)
    }

    /// Queue-only: the take is turned the way the phone is held now, and stays so while it runs.
    /// Without a coordinator reading the last angle stands (upright at first).
    private func turnUpright() {
        if let rotation { orientation.captured(angle: Double(rotation.videoRotationAngleForHorizonLevelCapture)) }
        orientation.beginTake()
        guard let connection = output.connection(with: .video) else { return }
        let angle = CGFloat(orientation.angle)
        if connection.isVideoRotationAngleSupported(angle) { connection.videoRotationAngle = angle }
    }

    /// Starts writing `url` for the take numbered `generation`.
    func record(to url: URL, generation: UInt64) {
        queue.async { [self] in
            lock.withLock { current = generation }
            guard session.isRunning, !output.isRecording else {
                onEvent(.finished(generation: generation, url: url, usable: false))
                return
            }
            turnUpright()
            output.startRecording(to: url, recordingDelegate: self)
        }
    }

    /// Ends the take; `finished` follows once the file is closed.
    func stopRecording() {
        queue.async { [self] in
            if output.isRecording { output.stopRecording() }
        }
    }

    /// Releases the camera. A take still writing is closed first and still reports `finished`.
    func close() {
        queue.async { [self] in
            shouldRun = false
            interrupted = false
            removeObservers()
            if output.isRecording { output.stopRecording() }
            session.stopRunning()
        }
    }

    // MARK: - Interruptions (as `CameraCapture` observes them)

    /// Queue-only.
    private func installObservers() {
        removeObservers()
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .AVCaptureSessionRuntimeError, object: session, queue: nil) { @Sendable [weak self] note in
            let reason = (note.userInfo?[AVCaptureSessionErrorKey] as? NSError)?.localizedDescription ?? "unknown error"
            self?.queue.async { self?.reportFailure(reason) }
        })
        observers.append(center.addObserver(forName: .AVCaptureSessionWasInterrupted, object: session, queue: nil) { @Sendable [weak self] _ in
            self?.queue.async { self?.markInterrupted() }
        })
        observers.append(center.addObserver(forName: .AVCaptureSessionInterruptionEnded, object: session, queue: nil) { @Sendable [weak self] _ in
            self?.queue.async { self?.resumeAfterInterruption() }
        })
        #if canImport(UIKit)
        // A background interruption does not always end with its own notification; the app
        // becoming active again is the other way to learn that the camera may be ours again.
        observers.append(center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { @Sendable [weak self] _ in
            self?.queue.async { self?.resumeAfterInterruption() }
        })
        #endif
    }

    /// Queue-only.
    private func removeObservers() {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers.removeAll()
    }

    /// Queue-only.
    private func markInterrupted() {
        guard shouldRun, !interrupted else { return }
        interrupted = true
        log.notice("take camera interrupted by iOS — waiting, not restarting")
        onEvent(.interrupted(generation: lock.withLock { current }))
    }

    /// Queue-only.
    private func resumeAfterInterruption() {
        guard shouldRun, interrupted else { return }
        interrupted = false
        if !session.isRunning { session.startRunning() }
        log.notice("take camera resumed after interruption")
        onEvent(.resumed(generation: lock.withLock { current }))
    }

    /// Queue-only. A running take is closed with what it holds; the camera is not restarted.
    private func reportFailure(_ reason: String) {
        guard shouldRun else { return }
        log.warning("take camera runtime error: \(reason, privacy: .public)")
        if output.isRecording { output.stopRecording() }
        onEvent(.failed(generation: lock.withLock { current }))
    }

    // MARK: - AVCaptureFileOutputRecordingDelegate

    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        onEvent(.started(generation: lock.withLock { current }))
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection], error: Error?) {
        // An error can still leave a whole file (the disk filled up, the session was interrupted):
        // the system says so, and such a take is kept.
        var usable = error == nil
        if let error {
            let finished = (error as NSError).userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool
            usable = finished ?? false
            log.warning("take ended with an error: \(error.localizedDescription, privacy: .public)")
        }
        onEvent(.finished(generation: lock.withLock { current }, url: outputFileURL, usable: usable))
        queue.async { [self] in orientation.endTake() }
    }
}
