// CameraPPGEngine.swift
// Echoelmusic - Camera-Based Photoplethysmography (PPG)
//
// Measures heart rate and R-R intervals using the iPhone camera + flash,
// similar to HRV4Training. User places finger over the rear camera lens
// while the torch illuminates blood flow changes.
//
// How it works:
// 1. Torch illuminates finger → red light passes through tissue
// 2. Camera captures video at 30 FPS
// 3. Red channel average brightness fluctuates with each heartbeat
// 4. Band-pass filter extracts cardiac signal (0.5-4 Hz = 30-240 BPM)
// 5. Peak detection finds R-R intervals
// 6. R-R intervals feed into existing UnifiedHealthKitEngine coherence calculation
//
// Reference: Poh, M.D., McDuff, D.J., & Picard, R.W. (2010).
// "Non-contact, automated cardiac pulse measurements using video imaging and blind source separation"
//
// ============================================================================
// DISCLAIMER: NOT A MEDICAL DEVICE
// Camera-based PPG is for WELLNESS and CREATIVE purposes only.
// Accuracy varies with skin tone, ambient light, pressure, and motion.
// NOT suitable for clinical heart rate monitoring.
// ============================================================================

import Foundation
import AVFoundation
import Accelerate
import Combine
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// MARK: - PPG Signal Quality

/// Signal quality assessment for camera PPG
public enum PPGSignalQuality: String, Sendable {
    case excellent   // Strong, clean pulse waveform
    case good        // Usable signal with minor noise
    case fair        // Noisy but peaks detectable
    case poor        // Too noisy for reliable measurement
    case noSignal    // No finger detected or no pulse signal

    public var isUsable: Bool {
        switch self {
        case .excellent, .good, .fair: return true
        case .poor, .noSignal: return false
        }
    }

    public var description: String {
        switch self {
        case .excellent: return "Excellent signal"
        case .good: return "Good signal"
        case .fair: return "Fair signal - hold still"
        case .poor: return "Poor signal - adjust finger"
        case .noSignal: return "Place finger over camera"
        }
    }
}

/// Measurement state
public enum PPGMeasurementState: String, Sendable {
    case idle            // Not measuring
    case preparingCamera // Setting up camera session
    case waitingForFinger // Camera ready, waiting for finger placement
    case calibrating     // Finger detected, collecting initial samples
    case measuring       // Active measurement with valid signal
    case completed       // Session complete
    case error           // Error state
}

// MARK: - Camera PPG Engine

/// Camera-based photoplethysmography engine
/// Extracts heart rate and R-R intervals from finger-on-camera video
@MainActor
public final class CameraPPGEngine: NSObject, ObservableObject {

    // MARK: - Published State

    @Published public private(set) var state: PPGMeasurementState = .idle
    @Published public private(set) var signalQuality: PPGSignalQuality = .noSignal
    @Published public private(set) var heartRate: Double = 0
    @Published public private(set) var rrIntervals: [Double] = []
    @Published public private(set) var currentRRInterval: Double = 0
    @Published public private(set) var measurementDuration: TimeInterval = 0
    @Published public private(set) var errorMessage: String?

    /// Raw PPG waveform for visualization (last ~5 seconds)
    @Published public private(set) var ppgWaveform: [Float] = []

    /// Normalized signal strength (0-1) for UI feedback
    @Published public private(set) var signalStrength: Double = 0

    // MARK: - Configuration

    /// Minimum samples before producing heart rate (3 seconds at 30 FPS)
    private let minimumSamplesForHR = 90

    /// Minimum R-R intervals for coherence calculation
    private let minimumRRForCoherence = 10

    /// Band-pass filter range (Hz) - cardiac signal range
    private let lowCutoffHz: Float = 0.5   // 30 BPM minimum
    private let highCutoffHz: Float = 4.0  // 240 BPM maximum

    /// Finger detection threshold (red channel brightness)
    /// When finger covers camera + torch, red channel is very bright
    private let fingerDetectionThreshold: Float = 100.0

    /// Minimum signal amplitude for valid pulse detection
    private let minimumPulseAmplitude: Float = 0.5

    /// Waveform display buffer size (~5 seconds at 30 FPS)
    private let waveformBufferSize = 150

    // MARK: - Camera

    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let captureQueue = DispatchQueue(label: "com.echoelmusic.camerappg", qos: .userInteractive)

    // MARK: - Signal Processing

    /// Raw red channel values from camera frames
    private var rawRedSignal: [Float] = []

    /// Filtered cardiac signal
    private var filteredSignal: [Float] = []

    /// Detected peak times (in sample indices)
    private var peakIndices: [Int] = []

    /// Sample counter
    private var sampleCount: Int = 0

    /// Actual camera frame rate (measured)
    private var measuredFPS: Double = 30.0
    private var lastFrameTime: CFAbsoluteTime = 0
    private var frameTimeAccumulator: Double = 0
    private var frameTimeCount: Int = 0

    /// Measurement start time
    private var measurementStartTime: Date?

    /// Timer for measurement duration updates
    private var durationTimer: Timer?

    /// Callback to feed R-R intervals into coherence engine
    public var onRRIntervalDetected: ((Double) -> Void)?

    /// Callback when heart rate updates
    public var onHeartRateUpdate: ((Double) -> Void)?

    // MARK: - IIR Filter State (Butterworth band-pass)

    /// Second-order IIR filter coefficients for band-pass
    /// Designed for ~30 FPS sample rate, 0.5-4 Hz passband
    private var filterState: (x1: Float, x2: Float, y1: Float, y2: Float) = (0, 0, 0, 0)

    // MARK: - Adaptive Threshold for Peak Detection

    private var adaptiveThreshold: Float = 0
    private var lastPeakIndex: Int = -1

    /// Minimum distance between peaks in samples (prevents double detection)
    /// At 30 FPS: 9 samples = 300ms = 200 BPM maximum
    private var minimumPeakDistance: Int { max(Int(measuredFPS * 0.3), 6) }

    // MARK: - Initialization

    public override init() {
        super.init()
    }

    // MARK: - Public API

    /// Start camera PPG measurement
    public func startMeasurement() {
        guard state == .idle || state == .completed || state == .error else { return }

        resetState()
        state = .preparingCamera

        Task {
            do {
                try await setupCamera()
                state = .waitingForFinger
            } catch {
                state = .error
                errorMessage = error.localizedDescription
                log.biofeedback("Camera PPG setup failed: \(error)")
            }
        }
    }

    /// Stop measurement and cleanup
    public func stopMeasurement() {
        teardownCamera()
        durationTimer?.invalidate()
        durationTimer = nil
        state = .completed
        log.biofeedback("Camera PPG stopped. Duration: \(Int(measurementDuration))s, RR intervals: \(rrIntervals.count)")
    }

    // MARK: - Camera Setup

    private func setupCamera() async throws {
        // Request camera permission
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            guard granted else {
                throw PPGError.cameraPermissionDenied
            }
        } else if status == .denied || status == .restricted {
            throw PPGError.cameraPermissionDenied
        }

        // Get rear camera
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw PPGError.cameraUnavailable
        }

        // Configure camera for PPG
        try camera.lockForConfiguration()

        // Lock frame rate to 30 FPS for consistent sampling
        camera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
        camera.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)

        // Lock exposure and white balance (we want stable brightness readings)
        if camera.isExposureModeSupported(.locked) {
            camera.exposureMode = .locked
        }
        if camera.isWhiteBalanceModeSupported(.locked) {
            camera.whiteBalanceMode = .locked
        }

        // Turn on torch at low power (illumination for PPG)
        if camera.hasTorch {
            camera.torchMode = .on
            try camera.setTorchModeOn(level: 0.5)  // 50% to reduce heat
        }

        camera.unlockForConfiguration()

        // Create capture session
        let session = AVCaptureSession()
        session.sessionPreset = .low  // Low resolution is fine, we only need brightness

        // Add camera input
        let input = try AVCaptureDeviceInput(device: camera)
        guard session.canAddInput(input) else {
            throw PPGError.cameraConfigFailed
        }
        session.addInput(input)

        // Add video output
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: captureQueue)

        guard session.canAddOutput(output) else {
            throw PPGError.cameraConfigFailed
        }
        session.addOutput(output)

        self.captureSession = session
        self.videoOutput = output

        // Start on background thread
        captureQueue.async { [weak self] in
            session.startRunning()
            DispatchQueue.main.async {
                self?.startDurationTimer()
            }
        }

        log.biofeedback("Camera PPG session started (30 FPS, torch on)")
    }

    private func teardownCamera() {
        captureQueue.async { [weak self] in
            self?.captureSession?.stopRunning()

            // Turn off torch
            if let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
               camera.hasTorch {
                try? camera.lockForConfiguration()
                camera.torchMode = .off
                camera.unlockForConfiguration()
            }
        }

        captureSession = nil
        videoOutput = nil
    }

    private func startDurationTimer() {
        measurementStartTime = Date()
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.measurementStartTime else { return }
            self.measurementDuration = Date().timeIntervalSince(start)
        }
    }

    // MARK: - State Reset

    private func resetState() {
        rawRedSignal.removeAll()
        filteredSignal.removeAll()
        peakIndices.removeAll()
        rrIntervals.removeAll()
        ppgWaveform.removeAll()
        sampleCount = 0
        heartRate = 0
        currentRRInterval = 0
        signalQuality = .noSignal
        signalStrength = 0
        measurementDuration = 0
        errorMessage = nil
        filterState = (0, 0, 0, 0)
        adaptiveThreshold = 0
        lastPeakIndex = -1
        lastFrameTime = 0
        frameTimeAccumulator = 0
        frameTimeCount = 0
    }

    // MARK: - Signal Processing

    /// Extract average red channel brightness from pixel buffer
    private func extractRedChannel(from pixelBuffer: CVPixelBuffer) -> Float {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return 0 }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)

        // Sample center region only (where finger is most likely pressed)
        let centerX = width / 2
        let centerY = height / 2
        let regionSize = min(width, height) / 4  // Center quarter

        var redSum: Int = 0
        var pixelCount: Int = 0

        let startY = Swift.max(0, centerY - regionSize)
        let endY = Swift.min(height, centerY + regionSize)
        let startX = Swift.max(0, centerX - regionSize)
        let endX = Swift.min(width, centerX + regionSize)

        // Step by 4 pixels for performance (we don't need every pixel)
        let step = 4
        for y in stride(from: startY, to: endY, by: step) {
            let rowOffset = y * bytesPerRow
            for x in stride(from: startX, to: endX, by: step) {
                let pixelOffset = rowOffset + x * 4
                // BGRA format: index 2 = Red channel
                let red = Int(buffer[pixelOffset + 2])
                redSum += red
                pixelCount += 1
            }
        }

        guard pixelCount > 0 else { return 0 }
        return Float(redSum) / Float(pixelCount)
    }

    /// Apply second-order IIR band-pass filter
    /// Butterworth design for 0.5-4 Hz at ~30 FPS sample rate
    private func bandPassFilter(_ input: Float) -> Float {
        // Coefficients for 2nd order Butterworth band-pass
        // Designed for fs=30 Hz, f_low=0.5 Hz, f_high=4 Hz
        // Using bilinear transform
        let a0: Float = 1.0
        let a1: Float = -1.5610
        let a2: Float = 0.6414
        let b0: Float = 0.1697
        let b1: Float = 0.0
        let b2: Float = -0.1697

        let output = (b0 / a0) * input
            + (b1 / a0) * filterState.x1
            + (b2 / a0) * filterState.x2
            - (a1 / a0) * filterState.y1
            - (a2 / a0) * filterState.y2

        // Shift state
        filterState.x2 = filterState.x1
        filterState.x1 = input
        filterState.y2 = filterState.y1
        filterState.y1 = output

        return output
    }

    /// Process new red channel sample
    private func processSample(_ redValue: Float) {
        sampleCount += 1

        // Store raw signal
        rawRedSignal.append(redValue)

        // Keep last 10 seconds of raw signal (300 samples at 30 FPS)
        if rawRedSignal.count > 300 {
            rawRedSignal.removeFirst()
        }

        // Check if finger is present (high red channel brightness)
        let isFingerPresent = redValue > fingerDetectionThreshold

        if !isFingerPresent {
            if state == .measuring || state == .calibrating {
                signalQuality = .noSignal
                signalStrength = 0
            }
            return
        }

        // Normalize red value (remove DC offset using running mean)
        let recentMean: Float
        if rawRedSignal.count >= 30 {
            let recent = Array(rawRedSignal.suffix(30))
            recentMean = recent.reduce(0, +) / Float(recent.count)
        } else {
            recentMean = redValue
        }
        let normalized = redValue - recentMean

        // Band-pass filter
        let filtered = bandPassFilter(normalized)
        filteredSignal.append(filtered)

        // Keep filtered signal buffer manageable
        if filteredSignal.count > 300 {
            filteredSignal.removeFirst()
            // Adjust peak indices when removing samples
            peakIndices = peakIndices.compactMap { idx in
                let adjusted = idx - 1
                return adjusted >= 0 ? adjusted : nil
            }
            lastPeakIndex = Swift.max(-1, lastPeakIndex - 1)
        }

        // Update waveform for display
        ppgWaveform.append(filtered)
        if ppgWaveform.count > waveformBufferSize {
            ppgWaveform.removeFirst()
        }

        // Update signal quality based on amplitude
        updateSignalQuality()

        // State transitions
        if state == .waitingForFinger {
            state = .calibrating
            log.biofeedback("Finger detected, calibrating PPG signal...")
        }

        if state == .calibrating && filteredSignal.count >= minimumSamplesForHR {
            state = .measuring
            log.biofeedback("PPG calibration complete, measuring...")
        }

        // Peak detection (only when we have enough samples)
        if filteredSignal.count >= 30 {
            detectPeaks()
        }
    }

    /// Adaptive peak detection using dynamic threshold
    private func detectPeaks() {
        let currentIndex = filteredSignal.count - 1
        guard currentIndex >= 2 else { return }

        let current = filteredSignal[currentIndex - 1]  // Check previous sample (need one after)
        let prev = filteredSignal[currentIndex - 2]
        let next = filteredSignal[currentIndex]

        // Update adaptive threshold (exponential moving average of signal amplitude)
        let absSignal = abs(current)
        adaptiveThreshold = adaptiveThreshold * 0.95 + absSignal * 0.05

        // Peak: local maximum above threshold, minimum distance from last peak
        let isPeak = current > prev && current > next
        let aboveThreshold = current > adaptiveThreshold * 0.6
        let minDistanceMet = (currentIndex - 1 - lastPeakIndex) >= minimumPeakDistance || lastPeakIndex == -1

        if isPeak && aboveThreshold && minDistanceMet && current > minimumPulseAmplitude * adaptiveThreshold {
            let peakIndex = currentIndex - 1
            peakIndices.append(peakIndex)

            // Calculate R-R interval from last peak
            if lastPeakIndex >= 0 {
                let intervalSamples = peakIndex - lastPeakIndex
                let intervalMs = Double(intervalSamples) / measuredFPS * 1000.0  // Convert to milliseconds

                // Validate: 250ms (240 BPM) to 2000ms (30 BPM)
                if intervalMs >= 250 && intervalMs <= 2000 {
                    currentRRInterval = intervalMs
                    rrIntervals.append(intervalMs)

                    // Keep last 120 R-R intervals (~2 minutes)
                    if rrIntervals.count > 120 {
                        rrIntervals.removeFirst()
                    }

                    // Calculate instantaneous heart rate
                    heartRate = 60000.0 / intervalMs

                    // Notify listeners
                    onRRIntervalDetected?(intervalMs)
                    onHeartRateUpdate?(heartRate)
                }
            }

            lastPeakIndex = peakIndex
        }
    }

    /// Update signal quality assessment
    private func updateSignalQuality() {
        guard filteredSignal.count >= 30 else {
            signalQuality = .noSignal
            signalStrength = 0
            return
        }

        // Calculate signal-to-noise ratio from recent samples
        let recent = Array(filteredSignal.suffix(60))
        let amplitude = (recent.max() ?? 0) - (recent.min() ?? 0)

        // Calculate variance (noise estimate)
        let mean = recent.reduce(0, +) / Float(recent.count)
        let variance = recent.reduce(0.0 as Float) { $0 + ($1 - mean) * ($1 - mean) } / Float(recent.count)
        let stddev = sqrt(variance)

        let snr = stddev > 0 ? amplitude / (stddev * 2) : 0

        signalStrength = Double(Swift.min(1.0, snr / 5.0))

        if snr > 4.0 {
            signalQuality = .excellent
        } else if snr > 2.5 {
            signalQuality = .good
        } else if snr > 1.5 {
            signalQuality = .fair
        } else if snr > 0.5 {
            signalQuality = .poor
        } else {
            signalQuality = .noSignal
        }
    }

    /// Measure actual camera FPS from frame timestamps
    private func updateFrameRate(_ timestamp: CFAbsoluteTime) {
        if lastFrameTime > 0 {
            let delta = timestamp - lastFrameTime
            if delta > 0 && delta < 1.0 {
                frameTimeAccumulator += delta
                frameTimeCount += 1

                // Update every 30 frames
                if frameTimeCount >= 30 {
                    measuredFPS = Double(frameTimeCount) / frameTimeAccumulator
                    frameTimeAccumulator = 0
                    frameTimeCount = 0
                }
            }
        }
        lastFrameTime = timestamp
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraPPGEngine: AVCaptureVideoDataOutputSampleBufferDelegate {

    nonisolated public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let timestamp = CFAbsoluteTimeGetCurrent()
        let redValue = extractRedChannel(from: pixelBuffer)

        DispatchQueue.main.async { [weak self] in
            self?.updateFrameRate(timestamp)
            self?.processSample(redValue)
        }
    }
}

// MARK: - Errors

enum PPGError: Error, LocalizedError {
    case cameraPermissionDenied
    case cameraUnavailable
    case cameraConfigFailed

    var errorDescription: String? {
        switch self {
        case .cameraPermissionDenied:
            return "Camera permission is required for heart rate measurement. Please enable in Settings."
        case .cameraUnavailable:
            return "Rear camera is not available on this device."
        case .cameraConfigFailed:
            return "Failed to configure camera for PPG measurement."
        }
    }
}
