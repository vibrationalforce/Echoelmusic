import EchoelCore
import Foundation
import Observation
import os
import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins

/// The newest stacked camera picture for the sky view, behind one lock: the capture queue writes
/// it a few times a second, the drawing leaf reads it once a frame — no actor hop either way.
/// Every start is an epoch; a frame of an earlier one is dropped at the door.
final class SkyCameraFrames: @unchecked Sendable {
    struct Latest {
        let image: CGImage?
        /// How strongly the layer shows, 0 … `SkyNightCamera.maximumOpacity`.
        let opacity: Double
        /// The camera's field of view along its sensor's long side, degrees; 0 while unknown.
        let longSideDegrees: Double
    }

    private let lock = NSLock()
    private var latest = Latest(image: nil, opacity: 0, longSideDegrees: 0)
    private var acceptedEpoch: UInt64 = 0

    func begin(epoch: UInt64) {
        lock.withLock {
            acceptedEpoch = epoch
            latest = Latest(image: nil, opacity: 0, longSideDegrees: 0)
        }
    }

    func end() {
        lock.withLock {
            acceptedEpoch = 0
            latest = Latest(image: nil, opacity: 0, longSideDegrees: 0)
        }
    }

    func publish(_ value: Latest, epoch: UInt64) {
        lock.withLock {
            guard epoch != 0, epoch == acceptedEpoch else { return }
            latest = value
        }
    }

    func read() -> Latest {
        lock.withLock { latest }
    }
}

/// The rear camera as a layer behind the drawn sky (sky source S2). The drawn sky is the picture;
/// this only joins it as far as the camera actually sees something, and nobody sets anything:
/// by day the camera's own automatic exposure; in the dark the exposure follows the picture
/// fluidly (`SkyNightCamera.nextExposure`: time before gain, a bounded step every half second and
/// three frames, the frame time moving at most one step) with focus held where autofocus settled; the
/// frames are averaged — aligned by the phone's own turn between them — the
/// noise taken down a little, and the layer fades in only as far as the stacked result carries
/// signal. Very dark: the layer stays away.
///
/// Camera arbitration (one producer): this layer opens the camera only while the app's one
/// `CameraArbitration` (held by `CameraPulseSource`) hands it the camera — a video take and the
/// pulse both come first, and it closes the moment either asks. It never asks for the camera permission itself — it runs only where access was already given,
/// so the sky view never raises a prompt whose text speaks of the pulse.
///
/// Nothing is saved and nothing leaves the device: each frame becomes one small picture in memory,
/// replaced by the next.
@MainActor
@Observable
final class SkyCamera {
    enum Status: Equatable {
        case off
        /// Camera access was never given, or is off; the drawn sky is all.
        case noAccess
        /// A take or the pulse holds the camera.
        case waiting
        case running
        case unavailable
    }

    private(set) var status: Status = .off
    let frames = SkyCameraFrames()
    @ObservationIgnored private var epoch: UInt64 = 0
    @ObservationIgnored private let log = Logger(subsystem: "com.echoelmusic.studio", category: "sky")
    @ObservationIgnored private var capture: SkyCapture?

    /// Follows the arbitration: open while the sky holds the camera (and access was given),
    /// closed otherwise.
    func follow(holdsCamera: Bool, pointing: SharedPointing) {
        guard holdsCamera else {
            stop()
            status = .waiting
            return
        }
        guard status != .running else { return }
        guard CameraCapture.hasUsageDescription, AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            status = .noAccess
            return
        }
        epoch &+= 1
        frames.begin(epoch: epoch)
        let capture = SkyCapture(frames: frames, pointing: pointing, epoch: epoch)
        self.capture = capture
        status = .running
        let run = epoch
        Task { @MainActor [weak self] in
            let started = await capture.start()
            guard let self, run == self.epoch else {
                capture.stop()
                return
            }
            if !started {
                self.log.notice("sky camera could not start")
                self.frames.end()
                self.capture = nil
                self.status = .unavailable
            }
        }
    }

    func stop() {
        epoch &+= 1
        frames.end()
        capture?.stop()
        capture = nil
        if status != .off { status = .off }
    }
}

/// The capture session and the stack, all on one serial queue.
private final class SkyCapture: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "com.echoelmusic.studio.sky.camera", qos: .userInitiated)
    private let frames: SkyCameraFrames
    private let pointing: SharedPointing
    private let epoch: UInt64
    private let log = Logger(subsystem: "com.echoelmusic.studio", category: "sky")
    // Queue state.
    private var device: AVCaptureDevice?
    private var exposure = SkyNightCamera.Exposure.automatic
    /// When the exposure last changed (system uptime, seconds), and the frames since.
    private var lastExposureStep: TimeInterval = 0
    private var framesSinceExposureStep = 0
    /// Frames in a row whose mean luma was clipped (`SkyNightCamera.clippedLuma`).
    private var clippedFramesInARow = 0
    /// The grace period starts at the first delivered frame, not at configuration.
    private var sawFirstFrame = false
    /// The active format's limits as last read, for the picture's lift.
    private var limits: SkyNightCamera.Limits?
    private var stack: CIImage?
    /// The stack's mean luma, which decides how strongly the layer shows.
    private var stackLuma: Double?
    private var stacked = 0
    private var lastForward: SkyVector?
    private var lastUp: SkyVector?
    private var longSideDegrees = 0.0
    private lazy var context = CIContext(options: [.cacheIntermediates: false])

    /// The picture is reduced to this many pixels on its long side before stacking.
    static let workingLongSide: CGFloat = 960

    init(frames: SkyCameraFrames, pointing: SharedPointing, epoch: UInt64) {
        self.frames = frames
        self.pointing = pointing
        self.epoch = epoch
        super.init()
    }

    func start() async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            queue.async { [self] in
                do {
                    try configure()
                    session.startRunning()
                    continuation.resume(returning: true)
                } catch {
                    log.warning("sky camera: \(String(describing: error), privacy: .public)")
                    continuation.resume(returning: false)
                }
            }
        }
    }

    func stop() {
        queue.async { [self] in
            if session.isRunning { session.stopRunning() }
            restoreAutomaticExposure()
            session.beginConfiguration()
            for input in session.inputs { session.removeInput(input) }
            for output in session.outputs { session.removeOutput(output) }
            session.commitConfiguration()
            stack = nil
            stacked = 0
            stackLuma = nil
        }
    }

    private enum SetupError: Error { case noCamera, refused }

    private func configure() throws {
        // Never touch the app's audio session (the pulse camera's lesson: the default reconfigured
        // it under the running engine).
        session.automaticallyConfiguresApplicationAudioSession = false
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .hd1280x720
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw SetupError.noCamera
        }
        let input = try AVCaptureDeviceInput(device: camera)
        guard session.canAddInput(input) else { throw SetupError.refused }
        session.addInput(input)
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else { throw SetupError.refused }
        session.addOutput(output)
        // Upright in portrait, like the drawn sky.
        if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
        device = camera
        longSideDegrees = Double(camera.activeFormat.videoFieldOfView)
        exposure = .automatic
        lastExposureStep = 0
        framesSinceExposureStep = 0
        clippedFramesInARow = 0
        sawFirstFrame = false
        prepareAutomatic(camera)
    }

    /// By day the camera's own automatics do the work: exposure, white balance and focus.
    private func prepareAutomatic(_ camera: AVCaptureDevice) {
        do {
            try camera.lockForConfiguration()
            defer { camera.unlockForConfiguration() }
            if camera.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                camera.whiteBalanceMode = .continuousAutoWhiteBalance
            }
            if camera.isFocusModeSupported(.continuousAutoFocus) { camera.focusMode = .continuousAutoFocus }
        } catch {
            log.warning("sky camera automatics: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Frames (capture queue)

    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let luma = Self.meanLuma(of: pixels)
        steerExposure(luma: luma)
        let now = pointing.load()
        let frame = reduced(CIImage(cvPixelBuffer: pixels))
        let extent = frame.extent
        // Align the stack with the phone's own turn since the last frame; a big turn starts over.
        if let stack, let lastForward, let lastUp,
           let turn = SkyNightCamera.turn(fromForward: lastForward, up: lastUp, toForward: now.forward, up: now.up),
           longSideDegrees > 1 {
            let pixelsPerDegree = Double(Swift.max(extent.width, extent.height)) / longSideDegrees
            let moved = stack.transformed(by: CGAffineTransform(translationX: -turn.right * pixelsPerDegree,
                                                                y: -turn.up * pixelsPerDegree))
            let weight = SkyNightCamera.newFrameWeight(stacked: stacked)
            stackLuma = SkyNightCamera.stackedLuma(previous: stackLuma, frame: luma, weight: weight)
            let blend = CIFilter.dissolveTransition()
            blend.inputImage = moved.composited(over: frame)
            blend.targetImage = frame
            blend.time = Float(weight)
            self.stack = (blend.outputImage ?? frame).cropped(to: extent)
            stacked += 1
        } else {
            self.stack = frame
            stacked = 1
            stackLuma = luma
        }
        lastForward = now.forward
        lastUp = now.up
        guard let current = self.stack else { return }
        let cleaned = denoised(current, lift: limits.map { SkyNightCamera.nightLift(exposure, limits: $0) } ?? 0)
        guard let image = context.createCGImage(cleaned, from: extent) else { return }
        frames.publish(SkyCameraFrames.Latest(image: image, opacity: SkyNightCamera.layerOpacity(luma: stackLuma ?? luma),
                                              longSideDegrees: longSideDegrees),
                       epoch: epoch)
    }

    private func reduced(_ image: CIImage) -> CIImage {
        let long = Swift.max(image.extent.width, image.extent.height)
        guard long > Self.workingLongSide else { return image }
        let scale = Self.workingLongSide / long
        let small = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        return small.transformed(by: CGAffineTransform(translationX: -small.extent.origin.x, y: -small.extent.origin.y))
    }

    /// A little noise reduction and a gentle lift of the shadows, both growing with the exposure
    /// (`lift` 0 … 1, `SkyNightCamera.nightLift`), so neither jumps when the exposure changes hands.
    private func denoised(_ image: CIImage, lift: Double) -> CIImage {
        let amount = Float(Swift.min(Swift.max(lift, 0), 1))
        let noise = CIFilter.noiseReduction()
        noise.inputImage = image
        noise.noiseLevel = 0.015 + 0.025 * amount
        noise.sharpness = 0.4
        let gamma = CIFilter.gammaAdjust()
        gamma.inputImage = noise.outputImage ?? image
        gamma.power = 1 - 0.25 * amount
        return gamma.outputImage ?? image
    }

    /// Mean luma of a BGRA frame, every sixteenth pixel each way, 0 … 1.
    static func meanLuma(of pixels: CVPixelBuffer) -> Double {
        guard CVPixelBufferGetPixelFormatType(pixels) == kCVPixelFormatType_32BGRA else { return 0 }
        CVPixelBufferLockBaseAddress(pixels, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixels, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(pixels) else { return 0 }
        let width = CVPixelBufferGetWidth(pixels), height = CVPixelBufferGetHeight(pixels)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixels)
        guard width >= 16, height >= 16, bytesPerRow >= width * 4 else { return 0 }
        var total = 0.0
        var count = 0.0
        for y in stride(from: 0, to: height, by: 16) {
            let row = base.advanced(by: y * bytesPerRow)
            for x in stride(from: 0, to: width, by: 16) {
                let pixel = row.advanced(by: x * 4)
                let blue = Double(pixel.load(fromByteOffset: 0, as: UInt8.self))
                let green = Double(pixel.load(fromByteOffset: 1, as: UInt8.self))
                let red = Double(pixel.load(fromByteOffset: 2, as: UInt8.self))
                total += (0.2126 * red + 0.7152 * green + 0.0722 * blue) / 255
                count += 1
            }
        }
        return count > 0 ? total / count : 0
    }

    // MARK: - Exposure (capture queue)

    private func steerExposure(luma: Double) {
        let now = ProcessInfo.processInfo.systemUptime
        if !sawFirstFrame {
            // A grace period from the first frame: the first frames are no reason to take over.
            sawFirstFrame = true
            lastExposureStep = now
        }
        framesSinceExposureStep += 1
        clippedFramesInARow = luma >= SkyNightCamera.clippedLuma ? clippedFramesInARow + 1 : 0
        guard let device, session.isRunning, !session.isInterrupted else { return }
        // Focus holds where autofocus settled, once it has settled: locked while it still hunts,
        // it would stay wrong all night. Checked every frame while the exposure is set by hand.
        if SkyNightCamera.holdsFocus(exposure), device.focusMode != .locked, !device.isAdjustingFocus,
           device.isFocusModeSupported(.locked) {
            do {
                try device.lockForConfiguration()
                device.focusMode = .locked
                device.unlockForConfiguration()
            } catch {
                log.warning("sky camera focus: \(error.localizedDescription, privacy: .public)")
            }
        }
        // The law only steps after half a second and three frames, or after clipped frames: no lock
        // on the frames in between.
        let due = (now - lastExposureStep >= SkyNightCamera.stepSeconds
                   && framesSinceExposureStep >= SkyNightCamera.stepFrames)
            || (exposure.isManual && clippedFramesInARow >= SkyNightCamera.clippedFrames)
        guard due else { return }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            // Read the format inside the lock: every value set below is clamped to the format the
            // camera has at this moment (a value outside it is an exception, not a refusal).
            let format = device.activeFormat
            // The longest exposure the format allows that its slowest frame rate can carry.
            var longest = format.maxExposureDuration
            if let slowest = format.videoSupportedFrameRateRanges.map(\.maxFrameDuration).max(by: { CMTimeCompare($0, $1) < 0 }),
               CMTimeCompare(longest, slowest) > 0 {
                longest = slowest
            }
            let limits = SkyNightCamera.Limits(minDuration: format.minExposureDuration.seconds, maxDuration: longest.seconds,
                                               minISO: Double(format.minISO), maxISO: Double(format.maxISO))
            self.limits = limits
            let next = SkyNightCamera.nextExposure(current: exposure, luma: luma,
                                                   reading: (duration: device.exposureDuration.seconds, iso: Double(device.iso)),
                                                   limits: limits, secondsSinceLastStep: now - lastExposureStep,
                                                   framesSinceLastStep: framesSinceExposureStep,
                                                   clippedFramesInARow: clippedFramesInARow)
            guard next != exposure else { return }
            switch next {
            case let .manual(seconds, iso):
                guard device.isExposureModeSupported(.custom) else { return }
                let duration = CMTimeMaximum(format.minExposureDuration,
                                             CMTimeMinimum(CMTime(seconds: seconds, preferredTimescale: 1_000_000), longest))
                let gain = Swift.min(Swift.max(Float(iso), format.minISO), format.maxISO)
                // A frame lasts at least as long as its exposure, never shorter than the shortest frame.
                device.activeVideoMaxFrameDuration = CMTimeMaximum(duration, device.activeVideoMinFrameDuration)
                device.setExposureModeCustom(duration: duration, iso: gain, completionHandler: nil)
                if !exposure.isManual {
                    log.notice("sky camera: exposure set by hand from \(seconds, privacy: .public) s at ISO \(iso, privacy: .public)")
                }
            case .automatic:
                restoreAutomaticExposure(locked: true)
                log.notice("sky camera: exposure back to automatic")
            }
            // Only what the camera took counts as the new state.
            exposure = next
            lastExposureStep = now
            framesSinceExposureStep = 0
        } catch {
            log.warning("sky camera exposure: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Hand exposure and frame rate back to automatic, for the next user of the camera.
    private func restoreAutomaticExposure(locked: Bool = false) {
        guard let device else { return }
        do {
            if !locked { try device.lockForConfiguration() }
            defer { if !locked { device.unlockForConfiguration() } }
            device.activeVideoMaxFrameDuration = .invalid
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
        } catch {
            log.warning("sky camera exposure reset: \(error.localizedDescription, privacy: .public)")
        }
    }
}
