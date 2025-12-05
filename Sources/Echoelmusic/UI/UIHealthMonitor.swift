import Foundation
import Combine
import os.log
import QuartzCore

#if os(iOS) || os(tvOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// ═══════════════════════════════════════════════════════════════════════════════
// ECHOELMUSIC UI HEALTH MONITOR
// ═══════════════════════════════════════════════════════════════════════════════
//
// Comprehensive UI Health Monitoring System
//
// Features:
// • Main Thread Watchdog
// • Frame Rate Monitoring
// • Layout Performance Tracking
// • Memory Pressure Detection
// • Render Pipeline Health
// • Hang Detection & Recovery
// • Cross-Platform Metrics
//
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - UI Health Monitor

@MainActor
public final class UIHealthMonitor: ObservableObject {

    // MARK: - Singleton

    public static let shared = UIHealthMonitor()

    // MARK: - Published Metrics

    @Published public var currentFPS: Float = 60
    @Published public var averageFPS: Float = 60
    @Published public var frameDropCount: Int = 0
    @Published public var mainThreadUtilization: Float = 0
    @Published public var renderTime: TimeInterval = 0
    @Published public var layoutTime: TimeInterval = 0
    @Published public var memoryPressureLevel: MemoryPressureLevel = .normal
    @Published public var hangDetected: Bool = false
    @Published public var healthScore: Float = 1.0

    // MARK: - Private State

    private let logger = Logger(subsystem: "com.echoelmusic", category: "UIHealthMonitor")
    private var cancellables = Set<AnyCancellable>()

    // Frame timing
    private var displayLink: CADisplayLink?
    private var lastFrameTime: CFTimeInterval = 0
    private var frameTimes: [CFTimeInterval] = []
    private let maxFrameHistory = 120

    // Watchdog
    private var watchdogTimer: Timer?
    private var lastWatchdogPing: Date = Date()
    private let watchdogThreshold: TimeInterval = 0.5  // 500ms hang threshold

    // Metrics collection
    private var metricsHistory: [UIMetricsSnapshot] = []
    private let maxMetricsHistory = 1000

    // MARK: - Initialization

    private init() {
        setupDisplayLink()
        setupWatchdog()
        setupMemoryWarningObserver()
        logger.info("📊 UI Health Monitor initialized")
    }

    deinit {
        displayLink?.invalidate()
        watchdogTimer?.invalidate()
    }

    // MARK: - Display Link Setup

    private func setupDisplayLink() {
        #if os(iOS) || os(tvOS)
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkFired))
        displayLink?.add(to: .main, forMode: .common)
        #elseif os(macOS)
        // macOS uses CVDisplayLink or timer-based approach
        Timer.scheduledTimer(withTimeInterval: 1.0/120.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.frameUpdate()
            }
        }
        #endif
    }

    #if os(iOS) || os(tvOS)
    @objc private func displayLinkFired(_ link: CADisplayLink) {
        frameUpdate()
    }
    #endif

    private func frameUpdate() {
        let currentTime = CACurrentMediaTime()

        if lastFrameTime > 0 {
            let frameDuration = currentTime - lastFrameTime
            frameTimes.append(frameDuration)

            // Keep only recent frames
            if frameTimes.count > maxFrameHistory {
                frameTimes.removeFirst()
            }

            // Calculate FPS
            currentFPS = Float(1.0 / frameDuration)

            // Check for frame drops (below 30 FPS)
            if frameDuration > 1.0/30.0 {
                frameDropCount += 1
            }

            // Calculate average FPS
            let avgDuration = frameTimes.reduce(0, +) / Double(frameTimes.count)
            averageFPS = Float(1.0 / avgDuration)

            // Update render time estimation
            renderTime = frameDuration
        }

        lastFrameTime = currentTime

        // Ping watchdog
        lastWatchdogPing = Date()

        // Update health score
        calculateHealthScore()
    }

    // MARK: - Watchdog Setup

    private func setupWatchdog() {
        // Run watchdog on background thread
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            self?.watchdogTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.checkWatchdog()
            }
            RunLoop.current.run()
        }
    }

    private func checkWatchdog() {
        let elapsed = Date().timeIntervalSince(lastWatchdogPing)

        if elapsed > watchdogThreshold {
            Task { @MainActor in
                self.hangDetected = true
                self.logger.warning("⚠️ Main thread hang detected: \(String(format: "%.2f", elapsed * 1000))ms")
                self.reportHang(duration: elapsed)
            }
        } else if hangDetected {
            Task { @MainActor in
                self.hangDetected = false
                self.logger.info("✅ Main thread recovered")
            }
        }
    }

    private func reportHang(duration: TimeInterval) {
        // Capture stack trace for debugging
        let snapshot = UIMetricsSnapshot(
            timestamp: Date(),
            fps: currentFPS,
            frameDrops: frameDropCount,
            hangDuration: duration,
            memoryPressure: memoryPressureLevel,
            healthScore: healthScore
        )

        metricsHistory.append(snapshot)

        // Trim history
        if metricsHistory.count > maxMetricsHistory {
            metricsHistory.removeFirst(metricsHistory.count - maxMetricsHistory)
        }

        // Notify self-healing engine
        NotificationCenter.default.post(
            name: .uiHangDetected,
            object: HangInfo(duration: duration, snapshot: snapshot)
        )
    }

    // MARK: - Memory Pressure

    private func setupMemoryWarningObserver() {
        #if os(iOS) || os(tvOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        #endif

        // Periodic memory check
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkMemoryPressure()
            }
        }
    }

    @objc private func handleMemoryWarning() {
        memoryPressureLevel = .critical
        logger.warning("🚨 Memory warning received")

        NotificationCenter.default.post(
            name: .uiMemoryPressure,
            object: memoryPressureLevel
        )
    }

    private func checkMemoryPressure() {
        let usedMemory = getUsedMemory()
        let totalMemory = Float(ProcessInfo.processInfo.physicalMemory)
        let usageRatio = usedMemory / totalMemory

        if usageRatio > 0.85 {
            memoryPressureLevel = .critical
        } else if usageRatio > 0.7 {
            memoryPressureLevel = .warning
        } else if usageRatio > 0.5 {
            memoryPressureLevel = .elevated
        } else {
            memoryPressureLevel = .normal
        }
    }

    private func getUsedMemory() -> Float {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        return result == KERN_SUCCESS ? Float(info.resident_size) : 0
    }

    // MARK: - Health Score Calculation

    private func calculateHealthScore() {
        var score: Float = 1.0

        // FPS impact (60 FPS = 1.0, 30 FPS = 0.5, <30 = lower)
        let fpsScore = min(averageFPS / 60.0, 1.0)
        score *= fpsScore

        // Frame drops impact
        let dropRate = Float(frameDropCount) / Float(max(frameTimes.count, 1))
        score *= (1.0 - min(dropRate, 0.5))

        // Memory pressure impact
        switch memoryPressureLevel {
        case .normal: break
        case .elevated: score *= 0.9
        case .warning: score *= 0.7
        case .critical: score *= 0.4
        }

        // Hang impact
        if hangDetected {
            score *= 0.3
        }

        healthScore = score
    }

    // MARK: - Layout Monitoring

    public func startLayoutMeasurement() -> CFTimeInterval {
        return CACurrentMediaTime()
    }

    public func endLayoutMeasurement(startTime: CFTimeInterval) {
        layoutTime = CACurrentMediaTime() - startTime

        if layoutTime > 0.016 {  // > 16ms
            logger.warning("⚠️ Slow layout: \(String(format: "%.2f", layoutTime * 1000))ms")
        }
    }

    // MARK: - Metrics Access

    public func getRecentMetrics(count: Int = 100) -> [UIMetricsSnapshot] {
        return Array(metricsHistory.suffix(count))
    }

    public func getMetricsSummary() -> UIMetricsSummary {
        let recentSnapshots = getRecentMetrics(count: 60)  // Last minute

        guard !recentSnapshots.isEmpty else {
            return UIMetricsSummary()
        }

        let avgFPS = recentSnapshots.map { $0.fps }.reduce(0, +) / Float(recentSnapshots.count)
        let totalDrops = recentSnapshots.map { $0.frameDrops }.reduce(0, +)
        let hangs = recentSnapshots.filter { $0.hangDuration > 0 }.count
        let avgHealth = recentSnapshots.map { $0.healthScore }.reduce(0, +) / Float(recentSnapshots.count)

        return UIMetricsSummary(
            averageFPS: avgFPS,
            totalFrameDrops: totalDrops,
            hangCount: hangs,
            averageHealthScore: avgHealth,
            worstMemoryPressure: recentSnapshots.map { $0.memoryPressure }.max() ?? .normal
        )
    }

    // MARK: - Reset

    public func resetMetrics() {
        frameDropCount = 0
        frameTimes.removeAll()
        metricsHistory.removeAll()
        hangDetected = false
        healthScore = 1.0
    }
}

// MARK: - Data Types

public enum MemoryPressureLevel: Int, Comparable {
    case normal = 0
    case elevated = 1
    case warning = 2
    case critical = 3

    public static func < (lhs: MemoryPressureLevel, rhs: MemoryPressureLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

public struct UIMetricsSnapshot {
    public let timestamp: Date
    public let fps: Float
    public let frameDrops: Int
    public let hangDuration: TimeInterval
    public let memoryPressure: MemoryPressureLevel
    public let healthScore: Float
}

public struct UIMetricsSummary {
    public var averageFPS: Float = 60
    public var totalFrameDrops: Int = 0
    public var hangCount: Int = 0
    public var averageHealthScore: Float = 1.0
    public var worstMemoryPressure: MemoryPressureLevel = .normal
}

public struct HangInfo {
    public let duration: TimeInterval
    public let snapshot: UIMetricsSnapshot
}

// MARK: - Render Performance Tracker

/// Tracks individual render operations for performance analysis
public class RenderPerformanceTracker {

    public static let shared = RenderPerformanceTracker()

    private var renderOperations: [RenderOperation] = []
    private let maxOperations = 1000
    private let lock = NSLock()

    private init() {}

    public func beginRender(name: String) -> RenderToken {
        return RenderToken(name: name, startTime: CACurrentMediaTime())
    }

    public func endRender(_ token: RenderToken) {
        let duration = CACurrentMediaTime() - token.startTime

        let operation = RenderOperation(
            name: token.name,
            duration: duration,
            timestamp: Date()
        )

        lock.lock()
        renderOperations.append(operation)
        if renderOperations.count > maxOperations {
            renderOperations.removeFirst()
        }
        lock.unlock()

        // Log slow renders
        if duration > 0.008 {  // > 8ms (half a frame at 60fps)
            let logger = Logger(subsystem: "com.echoelmusic", category: "RenderPerformance")
            logger.warning("⚠️ Slow render '\(token.name)': \(String(format: "%.2f", duration * 1000))ms")
        }
    }

    public func getSlowRenders(threshold: TimeInterval = 0.016) -> [RenderOperation] {
        lock.lock()
        defer { lock.unlock() }
        return renderOperations.filter { $0.duration > threshold }
    }

    public func getAverageRenderTime(for name: String) -> TimeInterval {
        lock.lock()
        defer { lock.unlock() }

        let matching = renderOperations.filter { $0.name == name }
        guard !matching.isEmpty else { return 0 }

        return matching.map { $0.duration }.reduce(0, +) / Double(matching.count)
    }
}

public struct RenderToken {
    let name: String
    let startTime: CFTimeInterval
}

public struct RenderOperation {
    public let name: String
    public let duration: TimeInterval
    public let timestamp: Date
}

// MARK: - Layout Performance Tracker

/// Tracks layout operations for debugging slow layouts
public class LayoutPerformanceTracker {

    public static let shared = LayoutPerformanceTracker()

    private var layoutOperations: [LayoutOperation] = []
    private let maxOperations = 500
    private let lock = NSLock()

    private init() {}

    public func trackLayout(view: String, duration: TimeInterval, constraintCount: Int) {
        let operation = LayoutOperation(
            viewName: view,
            duration: duration,
            constraintCount: constraintCount,
            timestamp: Date()
        )

        lock.lock()
        layoutOperations.append(operation)
        if layoutOperations.count > maxOperations {
            layoutOperations.removeFirst()
        }
        lock.unlock()

        // Log problematic layouts
        if duration > 0.016 || constraintCount > 100 {
            let logger = Logger(subsystem: "com.echoelmusic", category: "LayoutPerformance")
            logger.warning("⚠️ Complex layout '\(view)': \(String(format: "%.2f", duration * 1000))ms, \(constraintCount) constraints")
        }
    }

    public func getProblematicLayouts() -> [LayoutOperation] {
        lock.lock()
        defer { lock.unlock() }
        return layoutOperations.filter { $0.duration > 0.016 || $0.constraintCount > 100 }
    }
}

public struct LayoutOperation {
    public let viewName: String
    public let duration: TimeInterval
    public let constraintCount: Int
    public let timestamp: Date
}

// MARK: - Animation Performance Tracker

/// Tracks animation performance and dropped frames
public class AnimationPerformanceTracker: ObservableObject {

    public static let shared = AnimationPerformanceTracker()

    @Published public var activeAnimations: Int = 0
    @Published public var droppedAnimationFrames: Int = 0

    private var animationTokens: Set<UUID> = []
    private let lock = NSLock()

    private init() {}

    public func beginAnimation() -> UUID {
        let token = UUID()

        lock.lock()
        animationTokens.insert(token)
        activeAnimations = animationTokens.count
        lock.unlock()

        return token
    }

    public func endAnimation(_ token: UUID, droppedFrames: Int = 0) {
        lock.lock()
        animationTokens.remove(token)
        activeAnimations = animationTokens.count
        droppedAnimationFrames += droppedFrames
        lock.unlock()
    }

    public func reset() {
        lock.lock()
        animationTokens.removeAll()
        activeAnimations = 0
        droppedAnimationFrames = 0
        lock.unlock()
    }
}

// MARK: - UI Thread Profiler

/// Profiles main thread activity for debugging
public class UIThreadProfiler {

    public static let shared = UIThreadProfiler()

    private var isEnabled = false
    private var profileData: [ThreadProfileSample] = []
    private let maxSamples = 10000
    private var timer: Timer?

    private init() {}

    public func startProfiling() {
        guard !isEnabled else { return }
        isEnabled = true
        profileData.removeAll()

        // Sample at 100 Hz
        timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] _ in
            self?.sample()
        }
    }

    public func stopProfiling() -> [ThreadProfileSample] {
        timer?.invalidate()
        timer = nil
        isEnabled = false
        return profileData
    }

    private func sample() {
        let sample = ThreadProfileSample(
            timestamp: Date(),
            isMainThread: Thread.isMainThread,
            threadID: pthread_self(),
            queueLabel: DispatchQueue.currentLabel
        )

        profileData.append(sample)
        if profileData.count > maxSamples {
            profileData.removeFirst()
        }
    }

    public func getMainThreadUsage() -> Float {
        guard !profileData.isEmpty else { return 0 }

        let mainThreadSamples = profileData.filter { $0.isMainThread }.count
        return Float(mainThreadSamples) / Float(profileData.count)
    }
}

public struct ThreadProfileSample {
    public let timestamp: Date
    public let isMainThread: Bool
    public let threadID: pthread_t
    public let queueLabel: String
}

extension DispatchQueue {
    static var currentLabel: String {
        return String(cString: __dispatch_queue_get_label(nil))
    }
}

// MARK: - Notifications

extension Notification.Name {
    public static let uiHangDetected = Notification.Name("uiHangDetected")
    public static let uiMemoryPressure = Notification.Name("uiMemoryPressure")
    public static let uiFPSDropped = Notification.Name("uiFPSDropped")
    public static let uiLayoutSlow = Notification.Name("uiLayoutSlow")
}

// MARK: - SwiftUI Integration

import SwiftUI

/// View modifier for automatic performance tracking
public struct PerformanceTrackedModifier: ViewModifier {
    let name: String
    @State private var renderToken: RenderToken?

    public func body(content: Content) -> some View {
        content
            .onAppear {
                renderToken = RenderPerformanceTracker.shared.beginRender(name: name)
            }
            .onDisappear {
                if let token = renderToken {
                    RenderPerformanceTracker.shared.endRender(token)
                }
            }
    }
}

extension View {
    /// Track performance of this view
    public func trackPerformance(name: String) -> some View {
        modifier(PerformanceTrackedModifier(name: name))
    }
}

/// View for displaying UI health metrics
public struct UIHealthDashboard: View {
    @StateObject private var monitor = UIHealthMonitor.shared

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Health Score
            HStack {
                Text("UI Health")
                    .font(.headline)
                Spacer()
                HealthIndicator(score: monitor.healthScore)
            }

            Divider()

            // FPS
            MetricRow(
                label: "FPS",
                value: String(format: "%.0f", monitor.currentFPS),
                detail: String(format: "avg: %.0f", monitor.averageFPS),
                color: monitor.currentFPS >= 55 ? .green : (monitor.currentFPS >= 30 ? .yellow : .red)
            )

            // Frame Drops
            MetricRow(
                label: "Frame Drops",
                value: "\(monitor.frameDropCount)",
                color: monitor.frameDropCount < 10 ? .green : (monitor.frameDropCount < 50 ? .yellow : .red)
            )

            // Memory
            MetricRow(
                label: "Memory",
                value: monitor.memoryPressureLevel.description,
                color: memoryColor
            )

            // Hang Status
            if monitor.hangDetected {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("Main thread hang detected")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(12)
    }

    private var memoryColor: Color {
        switch monitor.memoryPressureLevel {
        case .normal: return .green
        case .elevated: return .blue
        case .warning: return .yellow
        case .critical: return .red
        }
    }
}

struct HealthIndicator: View {
    let score: Float

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 4)

            Circle()
                .trim(from: 0, to: CGFloat(score))
                .stroke(scoreColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text("\(Int(score * 100))")
                .font(.caption)
                .fontWeight(.bold)
        }
        .frame(width: 40, height: 40)
    }

    private var scoreColor: Color {
        if score >= 0.8 { return .green }
        if score >= 0.5 { return .yellow }
        return .red
    }
}

struct MetricRow: View {
    let label: String
    let value: String
    var detail: String? = nil
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            if let detail = detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

extension MemoryPressureLevel {
    var description: String {
        switch self {
        case .normal: return "Normal"
        case .elevated: return "Elevated"
        case .warning: return "Warning"
        case .critical: return "Critical"
        }
    }
}
