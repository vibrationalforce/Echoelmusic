#if canImport(AVFoundation)
import Foundation
import AVFoundation

/// Minimal AVCaptureSession for rPPG pulse detection.
/// Captures low-resolution video frames and delivers them via callback.
/// The torch illuminates the finger for pulse signal extraction.
final class CameraCapture: NSObject, @unchecked Sendable {

    private let session = AVCaptureSession()
    private let captureQueue = DispatchQueue(label: "com.echoelmusic.camera.capture", qos: .userInitiated)

    /// Called for each captured frame (on captureQueue — NOT main thread)
    nonisolated(unsafe) var onFrame: ((CVPixelBuffer) -> Void)?

    /// Whether the session is running
    var isRunning: Bool { session.isRunning }

    // MARK: - Start

    /// Start camera capture. Requests permission if needed.
    func start() async throws {
        // 1. Check/request camera permission
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            guard granted else {
                throw CameraCaptureError.permissionDenied
            }
        case .denied, .restricted:
            throw CameraCaptureError.permissionDenied
        case .authorized:
            break
        @unknown default:
            break
        }

        // 2. Find back camera (for finger-on-lens rPPG)
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraCaptureError.noCamera
        }

        // 3. Configure device for low-res, high frame rate
        try device.lockForConfiguration()
        // Low resolution sufficient for pulse detection
        if device.supportsSessionPreset(.low) {
            session.sessionPreset = .low
        } else {
            session.sessionPreset = .medium
        }
        // Lock exposure and white balance for consistent signal
        if device.isExposureModeSupported(.locked) {
            device.exposureMode = .locked
        }
        if device.isWhiteBalanceModeSupported(.locked) {
            device.whiteBalanceMode = .locked
        }
        device.unlockForConfiguration()

        // 4. Create input
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            throw CameraCaptureError.configurationFailed
        }
        session.addInput(input)

        // 5. Create video output
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: captureQueue)

        guard session.canAddOutput(output) else {
            throw CameraCaptureError.configurationFailed
        }
        session.addOutput(output)

        // 6. Start session
        session.startRunning()

        log.log(.info, category: .biofeedback, "CameraCapture started (back camera, low-res)")
    }

    // MARK: - Stop

    func stop() {
        session.stopRunning()
        // Remove all inputs/outputs for clean restart
        for input in session.inputs { session.removeInput(input) }
        for output in session.outputs { session.removeOutput(output) }
        log.log(.info, category: .biofeedback, "CameraCapture stopped")
    }
}

// MARK: - Frame Delivery

extension CameraCapture: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        onFrame?(pixelBuffer)
    }
}

// MARK: - Errors

enum CameraCaptureError: Error, LocalizedError {
    case permissionDenied
    case noCamera
    case configurationFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "Camera permission denied"
        case .noCamera: return "No camera available"
        case .configurationFailed: return "Camera configuration failed"
        }
    }
}
#endif
