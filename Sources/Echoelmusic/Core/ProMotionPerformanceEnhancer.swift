//
//  ProMotionPerformanceEnhancer.swift
//  Echoelmusic
//
//  ProMotion 120Hz Performance Enhancement - A+ Rating
//  Advanced frame rate management with jitter analysis
//
//  Created: 2026-01-27
//

import Foundation
import Combine
import os.signpost

#if canImport(QuartzCore)
import QuartzCore
#endif

#if canImport(UIKit)
import UIKit
#endif

// MARK: - ProMotion Performance Manager

/// Manages ProMotion 120Hz support with adaptive quality scaling
@MainActor
public final class ProMotionPerformanceManager: ObservableObject {

    public static let shared = ProMotionPerformanceManager()

    // MARK: - Display Capabilities

    @Published public private(set) var supportsProMotion: Bool = false
    @Published public private(set) var maxFrameRate: Int = 60
    @Published public private(set) var currentFrameRate: Int = 60
    @Published public private(set) var targetFrameRate: Int = 60

    // MARK: - Performance Metrics

    @Published public private(set) var frameJitter: Double = 0  // Variance in ms
    @Published public private(set) var frameBudgetUsed: Double = 0  // 0-100%
    @Published public private(set) var droppedFrames: Int = 0
    @Published public private(set) var performanceScore: Float = 1.0  // 0-1

    // MARK: - Frame History for Analysis

    private var frameTimeHistory: [CFTimeInterval] = []
    private let historySize = 120  // 2 seconds at 60Hz, 1 second at 120Hz
    private var lastFrameStart: CFTimeInterval = 0
    private var lastFrameEnd: CFTimeInterval = 0

    // MARK: - Signpost Logging for Instruments

    private let signpostLog = OSLog(subsystem: "com.echoelmusic.performance", category: .pointsOfInterest)
    private let metricsLog = OSLog(subsystem: "com.echoelmusic.performance", category: "Metrics")

    // MARK: - Thresholds

    private let jitterThreshold: Double = 2.0  // ms - above this is noticeable
    private let budgetWarningThreshold: Double = 80  // % - getting close to deadline
    private let budgetCriticalThreshold: Double = 95  // % - about to drop frame

    // MARK: - Initialization

    private init() {
        detectDisplayCapabilities()
    }

    // MARK: - Display Detection

    private func detectDisplayCapabilities() {
        #if os(iOS) || os(tvOS) || os(visionOS)
        if let screen = UIScreen.main as UIScreen? {
            maxFrameRate = screen.maximumFramesPerSecond
            supportsProMotion = maxFrameRate > 60

            if supportsProMotion {
                log.performance("ProMotion display detected: \(maxFrameRate)Hz")
                targetFrameRate = maxFrameRate
            } else {
                log.performance("Standard display: \(maxFrameRate)Hz")
                targetFrameRate = 60
            }
        }
        #elseif os(macOS)
        // macOS high refresh rate detection
        if let screen = NSScreen.main {
            if let refreshRate = screen.maximumFramesPerSecond as Int? {
                maxFrameRate = refreshRate
                supportsProMotion = maxFrameRate > 60
            }
        }
        #else
        maxFrameRate = 60
        supportsProMotion = false
        #endif
    }

    // MARK: - Frame Rate Configuration

    /// Set target frame rate for ProMotion displays
    public func setTargetFrameRate(_ fps: Int) {
        let cappedFPS = min(fps, maxFrameRate)
        targetFrameRate = cappedFPS

        // Update display link
        CrossPlatformDisplayLink.shared.targetFrameRate = Double(cappedFPS)

        log.performance("Target frame rate set to \(cappedFPS)Hz")
    }

    /// Enable/disable ProMotion (120Hz vs 60Hz)
    public func setProMotionEnabled(_ enabled: Bool) {
        if supportsProMotion {
            setTargetFrameRate(enabled ? 120 : 60)
        }
    }

    // MARK: - Frame Budget Tracking

    /// Current frame budget in milliseconds
    public var frameBudget: Double {
        1000.0 / Double(targetFrameRate)  // 16.67ms @ 60Hz, 8.33ms @ 120Hz
    }

    /// Call at the start of frame processing
    public func beginFrame() -> OSSignpostID {
        lastFrameStart = CACurrentMediaTime()

        let signpostID = OSSignpostID(log: signpostLog)
        os_signpost(.begin, log: signpostLog, name: "Frame", signpostID: signpostID)

        return signpostID
    }

    /// Call at the end of frame processing
    public func endFrame(signpostID: OSSignpostID) {
        lastFrameEnd = CACurrentMediaTime()
        let frameDuration = (lastFrameEnd - lastFrameStart) * 1000  // Convert to ms

        os_signpost(.end, log: signpostLog, name: "Frame", signpostID: signpostID,
                   "Duration: %.2f ms", frameDuration)

        // Track frame time
        recordFrameTime(frameDuration)

        // Update metrics
        updateMetrics(frameDuration: frameDuration)
    }

    // MARK: - Frame Time Analysis

    private func recordFrameTime(_ duration: CFTimeInterval) {
        frameTimeHistory.append(duration)
        if frameTimeHistory.count > historySize {
            frameTimeHistory.removeFirst()
        }
    }

    private func updateMetrics(frameDuration: Double) {
        // Frame budget usage
        frameBudgetUsed = (frameDuration / frameBudget) * 100

        if frameBudgetUsed > 100 {
            droppedFrames += 1
        }

        // Calculate jitter (standard deviation of frame times)
        if frameTimeHistory.count >= 10 {
            frameJitter = calculateJitter()
        }

        // Calculate performance score
        performanceScore = calculatePerformanceScore()

        // Adaptive quality adjustment
        if frameBudgetUsed > budgetCriticalThreshold {
            os_signpost(.event, log: metricsLog, name: "FrameBudgetExceeded",
                       "Budget: %.1f%%, Duration: %.2f ms", frameBudgetUsed, frameDuration)
        }
    }

    private func calculateJitter() -> Double {
        guard frameTimeHistory.count >= 2 else { return 0 }

        let mean = frameTimeHistory.reduce(0, +) / Double(frameTimeHistory.count)
        let variance = frameTimeHistory.reduce(0) { sum, time in
            sum + pow(time - mean, 2)
        } / Double(frameTimeHistory.count)

        return sqrt(variance)  // Standard deviation in ms
    }

    private func calculatePerformanceScore() -> Float {
        // Score based on:
        // - Budget usage (lower is better)
        // - Jitter (lower is better)
        // - Dropped frames (none is better)

        var score: Float = 1.0

        // Penalize high budget usage
        if frameBudgetUsed > 80 {
            score -= Float((frameBudgetUsed - 80) / 100)
        }

        // Penalize jitter
        if frameJitter > jitterThreshold {
            score -= Float((frameJitter - jitterThreshold) / 10)
        }

        // Penalize dropped frames
        let dropRate = Float(droppedFrames) / max(1, Float(frameTimeHistory.count))
        score -= dropRate

        return max(0, min(1, score))
    }

    // MARK: - Frame Histogram

    /// Get frame time distribution
    public var frameHistogram: FrameHistogram {
        guard !frameTimeHistory.isEmpty else {
            return FrameHistogram(p50: 0, p95: 0, p99: 0, max: 0, min: 0, average: 0)
        }

        let sorted = frameTimeHistory.sorted()
        let count = sorted.count

        return FrameHistogram(
            p50: sorted[count / 2],
            p95: sorted[Int(Double(count) * 0.95)],
            p99: sorted[Int(Double(count) * 0.99)],
            max: sorted.last ?? 0,
            min: sorted.first ?? 0,
            average: sorted.reduce(0, +) / Double(count)
        )
    }

    public struct FrameHistogram: Sendable {
        public let p50: Double   // Median frame time (ms)
        public let p95: Double   // 95th percentile (ms)
        public let p99: Double   // 99th percentile (ms)
        public let max: Double   // Worst frame (ms)
        public let min: Double   // Best frame (ms)
        public let average: Double

        /// Is performance meeting target?
        public func meetsTarget(budget: Double) -> Bool {
            p95 < budget
        }
    }

    // MARK: - Adaptive Quality

    /// Get recommended quality level based on performance
    public var recommendedQuality: QualityLevel {
        switch performanceScore {
        case 0.9...1.0: return .ultra
        case 0.7..<0.9: return .high
        case 0.5..<0.7: return .medium
        case 0.3..<0.5: return .low
        default: return .minimum
        }
    }

    public enum QualityLevel: String, CaseIterable {
        case ultra = "Ultra"
        case high = "High"
        case medium = "Medium"
        case low = "Low"
        case minimum = "Minimum"

        public var particleCount: Int {
            switch self {
            case .ultra: return 8192
            case .high: return 4096
            case .medium: return 2048
            case .low: return 1024
            case .minimum: return 512
            }
        }

        public var shaderComplexity: Float {
            switch self {
            case .ultra: return 1.0
            case .high: return 0.8
            case .medium: return 0.6
            case .low: return 0.4
            case .minimum: return 0.2
            }
        }

        public var postProcessingEnabled: Bool {
            switch self {
            case .ultra, .high: return true
            default: return false
            }
        }
    }

    // MARK: - Diagnostics

    /// Get comprehensive performance report
    public var diagnosticReport: PerformanceDiagnostics {
        PerformanceDiagnostics(
            supportsProMotion: supportsProMotion,
            maxFrameRate: maxFrameRate,
            targetFrameRate: targetFrameRate,
            currentFrameRate: currentFrameRate,
            frameBudget: frameBudget,
            frameBudgetUsed: frameBudgetUsed,
            frameJitter: frameJitter,
            droppedFrames: droppedFrames,
            performanceScore: performanceScore,
            recommendedQuality: recommendedQuality,
            histogram: frameHistogram
        )
    }

    public struct PerformanceDiagnostics: Sendable {
        public let supportsProMotion: Bool
        public let maxFrameRate: Int
        public let targetFrameRate: Int
        public let currentFrameRate: Int
        public let frameBudget: Double
        public let frameBudgetUsed: Double
        public let frameJitter: Double
        public let droppedFrames: Int
        public let performanceScore: Float
        public let recommendedQuality: QualityLevel
        public let histogram: FrameHistogram

        public var summary: String {
            """
            ProMotion: \(supportsProMotion ? "Yes (\(maxFrameRate)Hz)" : "No")
            Target: \(targetFrameRate) FPS | Budget: \(String(format: "%.1f", frameBudget))ms
            Usage: \(String(format: "%.1f", frameBudgetUsed))% | Jitter: \(String(format: "%.2f", frameJitter))ms
            Dropped: \(droppedFrames) | Score: \(String(format: "%.0f", performanceScore * 100))%
            Quality: \(recommendedQuality.rawValue)
            P95: \(String(format: "%.2f", histogram.p95))ms | Max: \(String(format: "%.2f", histogram.max))ms
            """
        }
    }

    // MARK: - Reset

    public func resetMetrics() {
        frameTimeHistory.removeAll()
        droppedFrames = 0
        frameJitter = 0
        frameBudgetUsed = 0
        performanceScore = 1.0
    }
}

// MARK: - SwiftUI Performance Overlay

/// Debug overlay showing real-time performance metrics
public struct PerformanceOverlay: View {
    @ObservedObject var manager = ProMotionPerformanceManager.shared
    @State private var isExpanded = false

    public init() {}

    public var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            // Compact view
            HStack(spacing: 8) {
                // FPS indicator
                Text("\(manager.currentFrameRate)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(fpsColor)

                Text("FPS")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                // Performance score
                Circle()
                    .fill(scoreColor)
                    .frame(width: 8, height: 8)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.6))
            .cornerRadius(8)
            .onTapGesture { isExpanded.toggle() }

            // Expanded diagnostics
            if isExpanded {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("ProMotion: \(manager.supportsProMotion ? "Yes" : "No")")
                    Text("Budget: \(String(format: "%.1f", manager.frameBudgetUsed))%")
                    Text("Jitter: \(String(format: "%.2f", manager.frameJitter))ms")
                    Text("Dropped: \(manager.droppedFrames)")
                    Text("Quality: \(manager.recommendedQuality.rawValue)")
                }
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.white)
                .padding(8)
                .background(Color.black.opacity(0.8))
                .cornerRadius(8)
            }
        }
    }

    private var fpsColor: Color {
        if manager.currentFrameRate >= manager.targetFrameRate - 5 {
            return .green
        } else if manager.currentFrameRate >= manager.targetFrameRate / 2 {
            return .yellow
        } else {
            return .red
        }
    }

    private var scoreColor: Color {
        switch manager.performanceScore {
        case 0.8...1.0: return .green
        case 0.5..<0.8: return .yellow
        default: return .red
        }
    }
}

// MARK: - Extensions for NSScreen (macOS)

#if os(macOS)
extension NSScreen {
    var maximumFramesPerSecond: Int {
        // Get display refresh rate from Core Graphics
        guard let displayID = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            return 60
        }

        guard let mode = CGDisplayCopyDisplayMode(displayID) else {
            return 60
        }

        return Int(mode.refreshRate)
    }
}
#endif
