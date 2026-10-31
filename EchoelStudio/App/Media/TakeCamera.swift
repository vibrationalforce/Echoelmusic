import AVFoundation
import Foundation
import os

/// The rear camera writing a video take (wave W7, C4): one capture session with a movie output and
/// no microphone — the take's sound is the song's mix, never the room. Its own serial queue does
/// every session call; the two recording callbacks come back stamped with the take's generation,
/// so the owner drops one that arrives after a newer take began. Holds the camera only while open.
final class TakeCamera: NSObject, @unchecked Sendable, AVCaptureFileOutputRecordingDelegate {
    enum Event: Sendable {
        /// The file is being written: the first frame is in.
        case started(generation: UInt64)
        /// The file is closed; `usable` says whether it holds the take.
        case finished(generation: UInt64, url: URL, usable: Bool)
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
    private let log = Logger(subsystem: "com.echoelmusic.studio", category: "video")

    init(onEvent: @escaping @Sendable (Event) -> Void) {
        self.onEvent = onEvent
        super.init()
    }

    /// Configures the rear camera for 1080p and starts the session, off the main thread.
    func open() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [self] in
                do {
                    try configure()
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
        // The app stands upright: the take does too.
        if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
    }

    /// Starts writing `url` for the take numbered `generation`.
    func record(to url: URL, generation: UInt64) {
        queue.async { [self] in
            lock.withLock { current = generation }
            guard session.isRunning, !output.isRecording else {
                onEvent(.finished(generation: generation, url: url, usable: false))
                return
            }
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
            if output.isRecording { output.stopRecording() }
            session.stopRunning()
        }
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
    }
}
