import Foundation
import AVFoundation
import Accelerate
#if canImport(CoreImage)
import CoreImage
import Observation
#endif

/// Analyzes camera frames for:
/// 1. Average brightness/color → filter modulation parameters
/// 2. Pulse estimation from face color changes → BPM suggestion
///
/// Resource-efficient: processes every Nth frame, uses vDSP for fast averaging
@MainActor
final @Observable
final class CameraAnalyzer {

    // MARK: - Published Output

    /// Average frame brightness (0–1), usable for filter modulation
    var brightness: Float = 0.5
    /// Average red channel (0–1), used for pulse detection
    var redChannel: Float = 0.5
    /// Average hue (0–360)
    var dominantHue: Float = 180
    /// Estimated BPM from pulse detection (0 = not detected)
    var estimatedBPM: Double = 0
    /// Confidence of BPM estimate (0–1)
    var bpmConfidence: Double = 0
    /// Whether pulse detection is active
    var isPulseDetecting: Bool = false

    // MARK: - Filter Modulation Output

    /// Normalized modulation value (0–1) from camera analysis
    var filterModulation: Float = 0.5
    /// Modulation mode
    var modulationMode: ModulationMode = .brightness

    enum ModulationMode: String, CaseIterable {
        case brightness = "Brightness"
        case color = "Color"
        case motion = "Motion"
    }

    // MARK: - Internal State

    private var frameSkipCounter = 0
    private let analyzeEveryNthFrame = 6 // Process every 6th frame (~5 FPS at 30FPS input)
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    // Pulse detection
    private var redHistory: [Float] = []
    private let pulseWindowSize = 150 // ~5 seconds at 30fps/6 = 5fps
    private var peakTimes: [TimeInterval] = []
    private var lastAnalysisTime: TimeInterval = 0

    // Motion detection
    private var previousBrightness: Float = 0.5

    // MARK: - Frame Analysis

    /// Call from CameraManager's onFrameCaptured callback
    /// Designed to be lightweight — skips most frames
    func analyzeFrame(_ sampleBuffer: CMSampleBuffer) {
        frameSkipCounter += 1
        guard frameSkipCounter >= analyzeEveryNthFrame else { return }
        frameSkipCounter = 0

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        analyzePixelBuffer(pixelBuffer)
    }

    /// Analyze a CVPixelBuffer (can also be called with Metal texture backing)
    func analyzePixelBuffer(_ pixelBuffer: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        // Sample center region only (30% of frame) for efficiency + face focus
        let regionX = width / 3
        let regionY = height / 3
        let regionW = width / 3
        let regionH = height / 3

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)

        // Only handle BGRA format (most common camera output)
        guard pixelFormat == kCVPixelFormatType_32BGRA else { return }

        var totalR: Float = 0
        var totalG: Float = 0
        var totalB: Float = 0
        var sampleCount: Float = 0

        // Subsample every 4th pixel for speed
        let step = 4
        for y in stride(from: regionY, to: regionY + regionH, by: step) {
            let rowStart = baseAddress.advanced(by: y * bytesPerRow)
            for x in stride(from: regionX, to: regionX + regionW, by: step) {
                let pixel = rowStart.advanced(by: x * 4)
                let b = Float(pixel.load(fromByteOffset: 0, as: UInt8.self)) / 255.0
                let g = Float(pixel.load(fromByteOffset: 1, as: UInt8.self)) / 255.0
                let r = Float(pixel.load(fromByteOffset: 2, as: UInt8.self)) / 255.0
                totalR += r
                totalG += g
                totalB += b
                sampleCount += 1
            }
        }

        guard sampleCount > 0 else { return }

        let avgR = totalR / sampleCount
        let avgG = totalG / sampleCount
        let avgB = totalB / sampleCount
        let avgBrightness = (avgR + avgG + avgB) / 3.0

        // Smooth updates to avoid jitter
        let smoothing: Float = 0.3
        brightness = brightness * (1 - smoothing) + avgBrightness * smoothing
        redChannel = redChannel * (1 - smoothing) + avgR * smoothing

        previousBrightness = brightness

        // Update filter modulation
        switch modulationMode {
        case .brightness:
            filterModulation = brightness
        case .color:
            // Map dominant color to 0-1 range
            let maxChannel = max(avgR, avgG, avgB)
            let minChannel = min(avgR, avgG, avgB)
            filterModulation = maxChannel - minChannel // saturation
        case .motion:
            // Difference from previous frame
            let delta = abs(avgBrightness - previousBrightness)
            filterModulation = min(delta * 10, 1.0) // amplify small changes
        }

        // Pulse detection
        if isPulseDetecting {
            updatePulseDetection(avgR: avgR)
        }
    }

    // MARK: - Pulse Detection (BPM from face color)

    /// Toggle pulse detection on/off
    func togglePulseDetection() {
        isPulseDetecting.toggle()
        if isPulseDetecting {
            redHistory.removeAll()
            peakTimes.removeAll()
            estimatedBPM = 0
            bpmConfidence = 0
        }
    }

    private func updatePulseDetection(avgR: Float) {
        let now = ProcessInfo.processInfo.systemUptime

        redHistory.append(avgR)
        if redHistory.count > pulseWindowSize {
            redHistory.removeFirst()
        }

        // Need at least 2 seconds of data
        guard redHistory.count >= 30 else { return }

        // Simple peak detection on red channel signal
        // Heart pulse causes subtle red intensity changes in face
        let windowSize = 5
        guard redHistory.count > windowSize * 2 else { return }

        let i = redHistory.count - windowSize - 1
        let current = redHistory[i]

        // Check if current is a local maximum
        let before = redHistory[(i - windowSize)..<i]
        let after = redHistory[(i + 1)...(i + windowSize)]

        let isMax = before.allSatisfy { $0 < current } && after.allSatisfy { $0 < current }

        if isMax {
            peakTimes.append(now)

            // Keep only recent peaks (last 10 seconds)
            let tenSecondsAgo = now - 10
            peakTimes = peakTimes.filter { $0 > tenSecondsAgo }

            // Calculate BPM from peak intervals
            if peakTimes.count >= 3 {
                var intervals: [TimeInterval] = []
                for j in 1..<peakTimes.count {
                    intervals.append(peakTimes[j] - peakTimes[j - 1])
                }

                let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
                guard avgInterval > 0.3 && avgInterval < 2.0 else { return } // 30-200 BPM range

                let bpm = 60.0 / avgInterval

                // Only report if consistent
                let variance = intervals.map { ($0 - avgInterval) * ($0 - avgInterval) }.reduce(0, +) / Double(intervals.count)
                let stdDev = sqrt(variance)
                let confidence = max(0, 1.0 - (stdDev / avgInterval))

                if confidence > 0.3 {
                    estimatedBPM = estimatedBPM * 0.7 + bpm * 0.3 // smooth
                    bpmConfidence = confidence
                }
            }
        }

        lastAnalysisTime = now
    }

    // MARK: - Cleanup

    func reset() {
        redHistory.removeAll()
        peakTimes.removeAll()
        estimatedBPM = 0
        bpmConfidence = 0
        brightness = 0.5
        redChannel = 0.5
        filterModulation = 0.5
        isPulseDetecting = false
    }
}
