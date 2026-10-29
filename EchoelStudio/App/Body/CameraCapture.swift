import EchoelCore
import Foundation
import Synchronization
import os

/// Frames averaged on the capture queue, handed to the main actor in batches — ported from the
/// earlier app for Echoel Studio 1.0, wave W1 "body". The capture queue only appends here (one
/// lock, no actor hop); the owner's 10 Hz loop drains everything queued since its last tick. The
/// earlier app hopped to the main actor once PER FRAME, and that flood of tiny main-actor tasks
/// starved SwiftUI until an open menu stopped responding while the pulse ran (10.76.48).
///
/// Every start of the camera is an epoch: a frame tagged with an earlier epoch — a callback still
/// in flight when the camera was stopped or restarted — is dropped at the door.
final class RGBSampleQueue: @unchecked Sendable {
    struct Sample: Sendable, Equatable {
        let red: Float
        let green: Float
        let blue: Float
        /// Capture time in seconds of the system uptime clock.
        let time: Double
    }

    /// ~6 s at the 15 fps the session is pinned to; a stalled drain cannot grow this unbounded.
    static let capacity = 90

    private let lock = NSLock()
    private var samples: [Sample] = []
    private var acceptedEpoch: UInt64 = 0

    /// Accept frames of `epoch` from now on; anything queued before is gone.
    func begin(epoch: UInt64) {
        lock.withLock {
            acceptedEpoch = epoch
            samples.removeAll(keepingCapacity: true)
        }
    }

    /// Accept nothing until the next `begin`.
    func end() {
        lock.withLock {
            acceptedEpoch = 0
            samples.removeAll(keepingCapacity: true)
        }
    }

    func push(_ sample: Sample, epoch: UInt64) {
        lock.withLock {
            guard epoch != 0, epoch == acceptedEpoch else { return }
            if samples.count >= Self.capacity {
                samples.removeFirst(samples.count - Self.capacity + 1)
            }
            samples.append(sample)
        }
    }

    /// Everything queued so far, oldest first, and the queue empty.
    func drain() -> [Sample] {
        lock.withLock {
            guard !samples.isEmpty else { return [] }
            let out = samples
            samples.removeAll(keepingCapacity: true)
            return out
        }
    }
}

#if canImport(AVFoundation)
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

/// When the last frame arrived, written on the capture queue, read by the watchdog.
private final class FrameClock: @unchecked Sendable {
    private let milliseconds = Atomic<UInt64>(0)

    func mark(_ uptimeSeconds: Double) {
        guard uptimeSeconds.isFinite, uptimeSeconds >= 0 else { return }
        milliseconds.store(UInt64(uptimeSeconds * 1_000), ordering: .relaxed)
    }

    var lastSeconds: Double {
        Double(milliseconds.load(ordering: .relaxed)) / 1_000
    }
}

/// The capture output's delegate, one per session start, carrying that start's epoch: it averages
/// the centre of every frame on the capture queue and pushes the three numbers. Nothing of the
/// frame survives this call — no pixel buffer leaves the queue, nothing is written anywhere.
private final class FrameSink: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let epoch: UInt64
    let queue: RGBSampleQueue
    let clock: FrameClock

    init(epoch: UInt64, queue: RGBSampleQueue, clock: FrameClock) {
        self.epoch = epoch
        self.queue = queue
        self.clock = clock
        super.init()
    }

    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                                   from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let uptime = ProcessInfo.processInfo.systemUptime
        clock.mark(uptime)
        guard let average = Self.centreAverage(of: pixelBuffer) else { return }
        queue.push(RGBSampleQueue.Sample(red: average.red, green: average.green, blue: average.blue, time: uptime),
                   epoch: epoch)
    }

    /// The mean of the centre half of a BGRA frame, every eighth pixel, each channel 0 … 1.
    static func centreAverage(of pixelBuffer: CVPixelBuffer) -> (red: Float, green: Float, blue: Float)? {
        guard CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_32BGRA else { return nil }
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        guard width >= 8, height >= 8, bytesPerRow >= width * 4 else { return nil }
        let regionX = width / 4
        let regionY = height / 4
        let regionWidth = width / 2
        let regionHeight = height / 2
        var totalRed: Float = 0
        var totalGreen: Float = 0
        var totalBlue: Float = 0
        var count: Float = 0
        for y in stride(from: regionY, to: regionY + regionHeight, by: 8) {
            let row = base.advanced(by: y * bytesPerRow)
            for x in stride(from: regionX, to: regionX + regionWidth, by: 8) {
                let pixel = row.advanced(by: x * 4)
                totalBlue += Float(pixel.load(fromByteOffset: 0, as: UInt8.self))
                totalGreen += Float(pixel.load(fromByteOffset: 1, as: UInt8.self))
                totalRed += Float(pixel.load(fromByteOffset: 2, as: UInt8.self))
                count += 1
            }
        }
        guard count > 0 else { return nil }
        return (totalRed / count / 255, totalGreen / count / 255, totalBlue / count / 255)
    }
}

/// The ONE owner of the rear camera for the pulse (camera-arbitration skill): the capture session,
/// the steady torch, the exposure lock, a watchdog for a stalled pipe and the OS interruptions.
/// Ported from the earlier app's `CameraCapture`, reduced to what the device sessions proved
/// necessary. Everything about the session happens on `sessionQueue`; the owner talks to it
/// through the methods below and hears back through `onEvent`, which fires on that queue.
///
/// Never touches the app's audio session (`automaticallyConfiguresApplicationAudioSession =
/// false`): with the default, starting the camera reconfigured the shared audio session under the
/// running audio engine and crashed the render thread. The torch is lit once and stays lit; its
/// level follows the thermal state only (0.45 → 0.28 → 0.18 as the phone warms), never a rhythm.
final class CameraCapture: @unchecked Sendable {
    enum StartError: Error, Equatable {
        case noCamera
        case configurationFailed
    }

    enum Event: Sendable, Equatable {
        /// iOS holds the camera (a call, Control Centre, another app, the background): no frames
        /// until `resumed`, and restarts would only burn heat.
        case interrupted
        /// Frames flow again after an interruption; exposure is auto again.
        case resumed
        /// A stall or a runtime error made the capture rebuild its session; exposure is auto again.
        case restarted
        /// The session failed for good this take.
        case failed(String)
    }

    /// Where the frames' averages land; the owner drains it.
    let samples = RGBSampleQueue()

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.echoelmusic.studio.camera.session")
    private let captureQueue = DispatchQueue(label: "com.echoelmusic.studio.camera.frames", qos: .userInitiated)
    private let frameClock = FrameClock()
    /// 1 while the torch is wanted but gives no light; a byte, read from the main actor.
    private let torchUnavailable = Atomic<UInt8>(0)
    private let onEvent: @Sendable (Event) -> Void
    private let log = Logger(subsystem: "com.echoelmusic.studio", category: "camera")
    // Session-queue state.
    private var epoch: UInt64 = 0
    private var sink: FrameSink?
    private var observers: [NSObjectProtocol] = []
    private var watchdog: DispatchSourceTimer?
    private var torchWanted = false
    private var shouldRun = false
    private var interrupted = false
    private var lastRestartUptime: Double = 0
    private var restarts = 0

    /// Frames stall this long with the session up → rebuild it (device logs: silent ~50–70 s
    /// freezes without any error).
    static let stallSeconds: Double = 4
    /// Rebuilds are at least this far apart, and at most this many in a row before the take fails.
    static let restartCooldownSeconds: Double = 6
    static let maxRestarts = 6

    init(onEvent: @escaping @Sendable (Event) -> Void) {
        self.onEvent = onEvent
    }

    /// The camera may be opened only when the build carries the permission text; without it iOS
    /// ends the app at the first access. Checked before any AVFoundation call.
    static var hasUsageDescription: Bool {
        guard let text = Bundle.main.object(forInfoDictionaryKey: "NSCameraUsageDescription") as? String else {
            return false
        }
        return !text.isEmpty
    }

    static func permission() -> BodyChannel.Permission {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: .granted
        case .denied, .restricted: .denied
        case .notDetermined: .unknown
        @unknown default: .unknown
        }
    }

    /// Asks iOS the first time; afterwards the recorded decision answers.
    static func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }

    /// True while the torch is wanted but gives no light: no LED, too hot, or the control failed.
    /// The owner coaches the lamp instead of the finger then.
    var isTorchUnavailable: Bool { torchUnavailable.load(ordering: .relaxed) != 0 }

    // MARK: - Start and stop

    /// Configure and run the session for `epoch` (the owner's start generation). Throws when the
    /// device has no rear camera or refuses the input or output (another app holds it).
    func start(epoch: UInt64) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [self] in
                do {
                    self.epoch = epoch
                    self.interrupted = false
                    self.restarts = 0
                    try self.configureSession()
                    self.installObservers()
                    self.samples.begin(epoch: epoch)
                    self.session.startRunning()
                    self.shouldRun = true
                    self.frameClock.mark(ProcessInfo.processInfo.systemUptime)
                    self.startWatchdog()
                    continuation.resume()
                } catch {
                    self.tearDownSession()
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Stop and release the camera, torch off, exposure back to auto for the next app.
    func stop() {
        sessionQueue.async { [self] in
            self.shouldRun = false
            self.interrupted = false
            self.watchdog?.cancel()
            self.watchdog = nil
            self.removeObservers()
            self.torchWanted = false
            self.applyTorch()
            self.applyExposure(locked: false)
            self.tearDownSession()
            self.samples.end()
            self.torchUnavailable.store(0, ordering: .relaxed)
        }
    }

    private func tearDownSession() {
        if session.isRunning { session.stopRunning() }
        session.beginConfiguration()
        for input in session.inputs { session.removeInput(input) }
        for output in session.outputs { session.removeOutput(output) }
        session.commitConfiguration()
        sink = nil
    }

    private func configureSession() throws {
        session.automaticallyConfiguresApplicationAudioSession = false
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        for input in session.inputs { session.removeInput(input) }
        for output in session.outputs { session.removeOutput(output) }
        session.sessionPreset = .low

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw StartError.noCamera
        }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            // 15 fps: the analyzer's band is 0.7–4 Hz, so 30 fps buys nothing for the pulse and
            // runs the sensor at twice the heat — heat being the cause of the mid-session stalls.
            if let range = device.activeFormat.videoSupportedFrameRateRanges.first {
                let targetFPS = Swift.max(range.minFrameRate, Swift.min(15, range.maxFrameRate))
                let duration = CMTimeMake(value: 1, timescale: Int32(targetFPS))
                device.activeVideoMinFrameDuration = duration
                device.activeVideoMaxFrameDuration = duration
            }
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw StartError.configurationFailed }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        let sink = FrameSink(epoch: epoch, queue: samples, clock: frameClock)
        output.setSampleBufferDelegate(sink, queue: captureQueue)
        self.sink = sink
        guard session.canAddOutput(output) else { throw StartError.configurationFailed }
        session.addOutput(output)
    }

    // MARK: - Torch

    /// Light the fingertip, or stop. Remembered, so a rebuilt session re-arms it: a restart or an
    /// exposure change silently drops the torch, and without light there is no pulse to read.
    func setTorch(_ on: Bool) {
        sessionQueue.async { [self] in
            self.torchWanted = on
            self.applyTorch()
        }
    }

    private func applyTorch() {
        guard let device = (session.inputs.first as? AVCaptureDeviceInput)?.device else { return }
        guard device.hasTorch else {
            torchUnavailable.store(1, ordering: .relaxed)
            return
        }
        // Thermal: iOS refuses the torch on a hot phone. Checked before taking a lock it cannot use.
        if torchWanted, !device.isTorchAvailable {
            torchUnavailable.store(1, ordering: .relaxed)
            return
        }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            if torchWanted {
                let level = Swift.min(Self.thermalTorchLevel(), AVCaptureDevice.maxAvailableTorchLevel)
                try device.setTorchModeOn(level: level)
            } else {
                device.torchMode = .off
            }
            torchUnavailable.store(0, ordering: .relaxed)
        } catch {
            torchUnavailable.store(1, ordering: .relaxed)
            log.warning("torch control failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// The torch level for the thermal state: 0.45 keeps more pulsatile contrast than full power
    /// (too much light saturates the capillary level), and the LED is the biggest controllable
    /// heat source, so it backs off as the phone warms. Steady at any level, never pulsed.
    static func thermalTorchLevel() -> Float {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal, .fair: 0.45
        case .serious: 0.28
        case .critical: 0.18
        @unknown default: 0.45
        }
    }

    // MARK: - Exposure

    /// Freeze exposure (≤ 1/30 s, the current gain) and white balance on the scene as it is — the
    /// owner calls this only once a finger covers the lit lens, so what is frozen is the fingertip
    /// scene, not the dim empty one.
    func lockExposure() {
        sessionQueue.async { [self] in self.applyExposure(locked: true) }
    }

    /// Hand exposure and white balance back to continuous auto.
    func unlockExposure() {
        sessionQueue.async { [self] in self.applyExposure(locked: false) }
    }

    private func applyExposure(locked: Bool) {
        guard let device = (session.inputs.first as? AVCaptureDeviceInput)?.device else { return }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            if locked {
                if device.isExposureModeSupported(.custom) {
                    // A bounded duration, not `.locked`: in a dim scene the auto exposure may have
                    // chosen an integration time longer than the frame period, which collapses
                    // the real frame rate below what the pulse band needs.
                    let format = device.activeFormat
                    var duration = CMTimeMake(value: 1, timescale: 30)
                    if CMTimeCompare(duration, format.maxExposureDuration) > 0 { duration = format.maxExposureDuration }
                    if CMTimeCompare(duration, format.minExposureDuration) < 0 { duration = format.minExposureDuration }
                    let iso = Swift.min(Swift.max(device.iso, format.minISO), format.maxISO)
                    device.setExposureModeCustom(duration: duration, iso: iso, completionHandler: nil)
                } else if device.isExposureModeSupported(.locked) {
                    device.exposureMode = .locked
                }
                // The pulse is read from the red/green ratio; a drifting white balance rescales
                // exactly those two against each other.
                if device.isWhiteBalanceModeSupported(.locked) {
                    device.whiteBalanceMode = .locked
                }
            } else {
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
                if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                    device.whiteBalanceMode = .continuousAutoWhiteBalance
                }
            }
        } catch {
            log.warning("exposure control failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Resilience

    private func installObservers() {
        removeObservers()
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .AVCaptureSessionRuntimeError, object: session, queue: nil) { [weak self] note in
            let reason = (note.userInfo?[AVCaptureSessionErrorKey] as? NSError)?.localizedDescription ?? "unknown error"
            self?.sessionQueue.async { self?.recover(after: reason) }
        })
        observers.append(center.addObserver(forName: .AVCaptureSessionWasInterrupted, object: session, queue: nil) { [weak self] _ in
            self?.sessionQueue.async { self?.markInterrupted() }
        })
        observers.append(center.addObserver(forName: .AVCaptureSessionInterruptionEnded, object: session, queue: nil) { [weak self] _ in
            self?.sessionQueue.async { self?.resumeAfterInterruption() }
        })
        // The LED backs off the moment the phone gets hot and comes back as it cools.
        observers.append(center.addObserver(forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: nil) { [weak self] _ in
            self?.sessionQueue.async { self?.applyTorch() }
        })
        #if canImport(UIKit)
        // A background interruption does not always end with its own notification; the app
        // becoming active again is the other way to learn that the camera may be ours again.
        observers.append(center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { [weak self] _ in
            self?.sessionQueue.async { self?.resumeAfterInterruption() }
        })
        #endif
    }

    private func removeObservers() {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers.removeAll()
    }

    private func markInterrupted() {
        guard shouldRun, !interrupted else { return }
        interrupted = true
        log.notice("camera interrupted by iOS — waiting, not restarting")
        onEvent(.interrupted)
    }

    private func resumeAfterInterruption() {
        guard shouldRun, interrupted else { return }
        interrupted = false
        if !session.isRunning { session.startRunning() }
        frameClock.mark(ProcessInfo.processInfo.systemUptime)
        applyTorch()
        log.notice("camera resumed after interruption")
        onEvent(.resumed)
    }

    private func recover(after reason: String) {
        guard shouldRun, !interrupted else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastRestartUptime > Self.restartCooldownSeconds else { return }
        log.warning("camera runtime error (\(reason, privacy: .public)) — rebuilding the session")
        restartSession(at: now)
    }

    /// Every 2 s: a session that should run but delivers no frames is rebuilt, cooldown-guarded
    /// and bounded; while iOS holds it interrupted nothing is tried.
    private func startWatchdog() {
        watchdog?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: sessionQueue)
        timer.schedule(deadline: .now() + 2, repeating: 2)
        timer.setEventHandler { [weak self] in self?.watch() }
        timer.resume()
        watchdog = timer
    }

    private func watch() {
        guard shouldRun, !interrupted else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let stalled = !session.isRunning || now - frameClock.lastSeconds > Self.stallSeconds
        guard stalled else {
            restarts = 0
            return
        }
        guard now - lastRestartUptime > Self.restartCooldownSeconds else { return }
        guard restarts < Self.maxRestarts else {
            log.error("camera delivers no frames after \(Self.maxRestarts) rebuilds — giving up this take")
            shouldRun = false
            watchdog?.cancel()
            watchdog = nil
            onEvent(.failed("The camera stopped delivering frames. Turn the camera off and on again."))
            return
        }
        restarts += 1
        log.warning("camera stalled — rebuilding the session (attempt \(self.restarts))")
        restartSession(at: now)
    }

    private func restartSession(at now: Double) {
        lastRestartUptime = now
        if session.isRunning { session.stopRunning() }
        do {
            try configureSession()
        } catch {
            log.error("camera could not be rebuilt: \(error.localizedDescription, privacy: .public)")
            shouldRun = false
            watchdog?.cancel()
            watchdog = nil
            onEvent(.failed("The camera could not be restarted. Turn the camera off and on again."))
            return
        }
        session.startRunning()
        frameClock.mark(now)
        applyTorch()
        onEvent(.restarted)
    }
}

#else

/// No AVFoundation on this platform: the camera cannot be opened, and `start` says so.
final class CameraCapture: @unchecked Sendable {
    enum StartError: Error, Equatable {
        case noCamera
        case configurationFailed
    }

    enum Event: Sendable, Equatable {
        case interrupted
        case resumed
        case restarted
        case failed(String)
    }

    let samples = RGBSampleQueue()

    init(onEvent: @escaping @Sendable (Event) -> Void) {}

    static var hasUsageDescription: Bool { false }
    static func permission() -> BodyChannel.Permission { .denied }
    static func requestAccess() async -> Bool { false }
    var isTorchUnavailable: Bool { true }
    func start(epoch: UInt64) async throws { throw StartError.noCamera }
    func stop() {}
    func setTorch(_ on: Bool) {}
    func lockExposure() {}
    func unlockExposure() {}
}

#endif
