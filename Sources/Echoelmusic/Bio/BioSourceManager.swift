#if canImport(AVFoundation)
import Foundation
import AVFoundation
import Observation

/// Fuses multiple bio sources (Apple Watch, Camera rPPG, Oura Ring)
/// into a single BioSnapshot with confidence-weighted merging.
///
/// Priority: Apple Watch > Camera rPPG > Oura (daily) > Fallback
@MainActor @Observable
final class BioSourceManager {

    // MARK: - Output

    /// Best available bio snapshot (merged from all active sources)
    var snapshot: BioSnapshot = BioSnapshot()

    /// Which source is currently primary
    var primarySource: BioDataSource = .fallback

    /// Confidence in current data (0 = simulated, 1 = real-time wearable)
    var confidence: Double = 0.0

    // MARK: - Sources

    private let bioEngine = EchoelBioEngine.shared
    private var cameraAnalyzer: CameraAnalyzer?
    private let ouraClient = OuraRingClient.shared

    /// Whether camera pulse detection is active
    var isCameraActive: Bool = false

    // MARK: - Lifecycle

    func startStreaming() {
        bioEngine.startStreaming()
        updatePrimarySource()
    }

    func stopStreaming() {
        bioEngine.stopStreaming()
        stopCamera()
    }

    /// Start camera-based pulse detection (finger on lens + torch)
    func startCamera() {
        guard cameraAnalyzer == nil else { return }
        let analyzer = CameraAnalyzer()
        analyzer.startCapture()
        cameraAnalyzer = analyzer
        isCameraActive = true
        enableTorch(true)
        log.log(.info, category: .biofeedback, "Camera rPPG started with torch")
    }

    func stopCamera() {
        enableTorch(false)
        cameraAnalyzer?.stopCapture()
        cameraAnalyzer = nil
        isCameraActive = false
    }

    /// Enable/disable camera torch for rPPG pulse illumination
    private func enableTorch(_ on: Bool) {
        #if canImport(AVFoundation) && !os(macOS)
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            if on { try device.setTorchModeOn(level: 0.5) } // Half brightness
            device.unlockForConfiguration()
        } catch {
            log.log(.warning, category: .biofeedback, "Torch control failed: \(error.localizedDescription)")
        }
        #endif
    }

    // MARK: - Fusion

    /// Call at 60Hz from SoundscapeEngine update loop
    func update() {
        updatePrimarySource()

        // Start with HealthKit data (Apple Watch)
        var merged = bioEngine.snapshot

        // Layer camera rPPG data if available and HealthKit isn't streaming real data
        if let camera = cameraAnalyzer, camera.isFingerDetected {
            let cameraHR = camera.heartRate
            let cameraHRV = camera.hrvRMSSD

            if bioEngine.dataSource == .fallback {
                // No Apple Watch — camera is primary
                if cameraHR > 0 {
                    merged.heartRate = cameraHR
                    merged.source = .camera
                }
                if cameraHRV > 0 {
                    merged.hrvNormalized = (cameraHRV / 100.0).clamped(to: 0...1)
                }
            }
            // If Apple Watch IS connected, camera data is ignored (Watch is more accurate)
        }

        // Layer Oura daily data (sleep/readiness affects coherence baseline)
        if ouraClient.authState == .authenticated {
            let oura = ouraClient.snapshot
            // Oura readiness adjusts coherence baseline
            if oura.readinessScore > 0 {
                let readinessBoost = Double(oura.readinessScore) / 100.0 * 0.1
                merged.coherence = (merged.coherence + readinessBoost).clamped(to: 0...1)
            }
            // Oura resting HR as reference (not real-time)
            if oura.restingHR > 0 && bioEngine.dataSource == .fallback && cameraAnalyzer == nil {
                merged.heartRate = Double(oura.restingHR)
                merged.source = .ouraRing
            }
        }

        // Calculate confidence
        switch merged.source {
        case .healthKit, .appleWatch, .chestStrap:
            confidence = 1.0
        case .camera:
            confidence = cameraAnalyzer?.bpmConfidence ?? 0.5
        case .ouraRing:
            confidence = 0.3 // Daily aggregate, not real-time
        case .fallback:
            confidence = 0.0
        default:
            confidence = 0.5
        }

        snapshot = merged
        primarySource = merged.source
    }

    private func updatePrimarySource() {
        if bioEngine.dataSource != .fallback {
            primarySource = bioEngine.dataSource
        } else if isCameraActive, let cam = cameraAnalyzer, cam.isFingerDetected {
            primarySource = .camera
        } else if ouraClient.authState == .authenticated {
            primarySource = .ouraRing
        } else {
            primarySource = .fallback
        }
    }
}

// MARK: - CameraAnalyzer Convenience

private extension CameraAnalyzer {
    var heartRate: Double { estimatedBPM }
    var hrvRMSSD: Double { rmssd }
    func startCapture() { startPulseDetection() }
    func stopCapture() { stopPulseDetection() }
}
#endif
