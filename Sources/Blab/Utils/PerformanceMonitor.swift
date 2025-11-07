import Foundation
import UIKit
import MetalKit

/// Performance monitoring utility for BLAB
/// Tracks FPS, CPU usage, memory, and render times
@MainActor
class PerformanceMonitor: ObservableObject {

    // MARK: - Published Metrics

    /// Current frames per second
    @Published var currentFPS: Double = 60.0

    /// Average FPS over last 5 seconds
    @Published var averageFPS: Double = 60.0

    /// Current CPU usage (0-1)
    @Published var cpuUsage: Double = 0.0

    /// Current memory usage in MB
    @Published var memoryUsageMB: Double = 0.0

    /// Audio processing latency in ms
    @Published var audioLatencyMS: Double = 0.0

    /// Metal render time in ms
    @Published var renderTimeMS: Double = 0.0

    /// Whether performance monitoring is enabled
    @Published var isMonitoring: Bool = false

    // MARK: - Private Properties

    private var lastFrameTime: CFAbsoluteTime = 0.0
    private var frameCount: Int = 0
    private var fpsBuffer: [Double] = []
    private let fpsBufferSize = 300  // 5 seconds @ 60 FPS

    private var displayLink: CADisplayLink?
    private var startTime: CFAbsoluteTime = 0.0

    // MARK: - Display Refresh Rate Detection

    /// Detected display refresh rate (60 or 120 Hz)
    var displayRefreshRate: Int {
        if #available(iOS 15.0, *) {
            return Int(UIScreen.main.maximumFramesPerSecond)
        } else {
            return 60
        }
    }

    /// Whether ProMotion is available
    var isProMotionAvailable: Bool {
        return displayRefreshRate > 60
    }

    // MARK: - Initialization

    init() {
        // Detection only, don't start monitoring
    }

    // MARK: - Monitoring Control

    /// Start performance monitoring
    func startMonitoring() {
        guard !isMonitoring else { return }

        isMonitoring = true
        startTime = CFAbsoluteTimeGetCurrent()
        lastFrameTime = startTime

        // Create display link for frame timing
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkCallback))

        if #available(iOS 15.0, *) {
            // Use ProMotion refresh rate if available
            displayLink?.preferredFrameRateRange = CAFrameRateRange(
                minimum: 60.0,
                maximum: Float(displayRefreshRate),
                preferred: Float(displayRefreshRate)
            )
        }

        displayLink?.add(to: .main, forMode: .common)

        print("[PerformanceMonitor] Started monitoring @ \(displayRefreshRate) Hz")
    }

    /// Stop performance monitoring
    func stopMonitoring() {
        isMonitoring = false
        displayLink?.invalidate()
        displayLink = nil
        print("[PerformanceMonitor] Stopped monitoring")
    }

    // MARK: - Frame Timing

    @objc private func displayLinkCallback() {
        let currentTime = CFAbsoluteTimeGetCurrent()
        let deltaTime = currentTime - lastFrameTime

        if deltaTime > 0.0 {
            // Calculate instantaneous FPS
            let fps = 1.0 / deltaTime
            currentFPS = fps

            // Add to buffer
            fpsBuffer.append(fps)
            if fpsBuffer.count > fpsBufferSize {
                fpsBuffer.removeFirst()
            }

            // Calculate average FPS
            if !fpsBuffer.isEmpty {
                averageFPS = fpsBuffer.reduce(0.0, +) / Double(fpsBuffer.count)
            }

            frameCount += 1
        }

        lastFrameTime = currentTime

        // Update other metrics every second
        if frameCount % displayRefreshRate == 0 {
            updateSystemMetrics()
        }
    }

    // MARK: - System Metrics

    /// Update CPU and memory usage
    private func updateSystemMetrics() {
        // CPU usage (simplified)
        var cpuUsageValue: Double = 0.0
        var threadList: thread_act_array_t?
        var threadCount = mach_msg_type_number_t(0)

        let threadInfoCount = MemoryLayout<thread_basic_info>.size / MemoryLayout<natural_t>.size
        let task = mach_task_self_

        if task_threads(task, &threadList, &threadCount) == KERN_SUCCESS,
           let threads = threadList {

            for i in 0..<Int(threadCount) {
                var threadInfo = thread_basic_info()
                var threadInfoCount = mach_msg_type_number_t(threadInfoCount)

                let infoResult = withUnsafeMutablePointer(to: &threadInfo) { pointer in
                    pointer.withMemoryRebound(to: integer_t.self, capacity: 1) { intPointer in
                        thread_info(threads[i], thread_flavor_t(THREAD_BASIC_INFO), intPointer, &threadInfoCount)
                    }
                }

                if infoResult == KERN_SUCCESS {
                    let cpu = Double(threadInfo.cpu_usage) / Double(TH_USAGE_SCALE)
                    cpuUsageValue += cpu
                }
            }

            vm_deallocate(task, vm_address_t(bitPattern: threads), vm_size_t(Int(threadCount) * MemoryLayout<thread_t>.stride))
        }

        cpuUsage = min(cpuUsageValue, 1.0)

        // Memory usage
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(task, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            memoryUsageMB = Double(info.resident_size) / (1024.0 * 1024.0)
        }
    }

    // MARK: - Performance Markers

    /// Mark start of audio processing
    private var audioStartTime: CFAbsoluteTime = 0.0

    func markAudioProcessingStart() {
        audioStartTime = CFAbsoluteTimeGetCurrent()
    }

    /// Mark end of audio processing
    func markAudioProcessingEnd() {
        let elapsed = CFAbsoluteTimeGetCurrent() - audioStartTime
        audioLatencyMS = elapsed * 1000.0  // Convert to ms
    }

    /// Mark start of Metal render pass
    private var renderStartTime: CFAbsoluteTime = 0.0

    func markRenderStart() {
        renderStartTime = CFAbsoluteTimeGetCurrent()
    }

    /// Mark end of Metal render pass
    func markRenderEnd() {
        let elapsed = CFAbsoluteTimeGetCurrent() - renderStartTime
        renderTimeMS = elapsed * 1000.0  // Convert to ms
    }

    // MARK: - Performance Report

    /// Generate performance report
    func generateReport() -> PerformanceReport {
        return PerformanceReport(
            averageFPS: averageFPS,
            currentFPS: currentFPS,
            cpuUsage: cpuUsage,
            memoryUsageMB: memoryUsageMB,
            audioLatencyMS: audioLatencyMS,
            renderTimeMS: renderTimeMS,
            displayRefreshRate: displayRefreshRate,
            isProMotionActive: isProMotionAvailable,
            uptime: CFAbsoluteTimeGetCurrent() - startTime
        )
    }

    /// Check if performance is within acceptable range
    func isPerformanceAcceptable() -> Bool {
        let fpsThreshold = Double(displayRefreshRate) * 0.9  // 90% of target
        let cpuThreshold = 0.8  // 80%
        let memoryThreshold: Double = 300.0  // 300 MB

        return averageFPS >= fpsThreshold &&
               cpuUsage < cpuThreshold &&
               memoryUsageMB < memoryThreshold
    }

    // MARK: - Debug Output

    /// Print current performance metrics
    func printMetrics() {
        print("""
        📊 PERFORMANCE METRICS:
        - FPS: \(String(format: "%.1f", currentFPS)) (avg: \(String(format: "%.1f", averageFPS)))
        - Refresh Rate: \(displayRefreshRate) Hz\(isProMotionAvailable ? " (ProMotion ✅)" : "")
        - CPU: \(String(format: "%.1f%%", cpuUsage * 100))
        - Memory: \(String(format: "%.1f", memoryUsageMB)) MB
        - Audio Latency: \(String(format: "%.2f", audioLatencyMS)) ms
        - Render Time: \(String(format: "%.2f", renderTimeMS)) ms
        """)
    }

    deinit {
        stopMonitoring()
    }
}

// MARK: - Performance Report

struct PerformanceReport: Codable {
    let averageFPS: Double
    let currentFPS: Double
    let cpuUsage: Double
    let memoryUsageMB: Double
    let audioLatencyMS: Double
    let renderTimeMS: Double
    let displayRefreshRate: Int
    let isProMotionActive: Bool
    let uptime: TimeInterval

    /// Human-readable description
    var description: String {
        """
        Performance Report:
        - Average FPS: \(String(format: "%.1f", averageFPS))
        - Display: \(displayRefreshRate) Hz\(isProMotionActive ? " (ProMotion)" : "")
        - CPU: \(String(format: "%.1f%%", cpuUsage * 100))
        - Memory: \(String(format: "%.1f MB", memoryUsageMB))
        - Audio Latency: \(String(format: "%.2f ms", audioLatencyMS))
        - Render Time: \(String(format: "%.2f ms", renderTimeMS))
        - Uptime: \(String(format: "%.1f s", uptime))
        """
    }

    /// Performance grade (A-F)
    var grade: String {
        let fpsScore = averageFPS / Double(displayRefreshRate)
        let cpuScore = 1.0 - cpuUsage
        let memoryScore = 1.0 - min(memoryUsageMB / 300.0, 1.0)

        let totalScore = (fpsScore + cpuScore + memoryScore) / 3.0

        switch totalScore {
        case 0.9...1.0: return "A+"
        case 0.8..<0.9: return "A"
        case 0.7..<0.8: return "B"
        case 0.6..<0.7: return "C"
        default: return "D"
        }
    }
}

// MARK: - SwiftUI View Extension

import SwiftUI

extension View {
    /// Show performance overlay
    func performanceOverlay(_ monitor: PerformanceMonitor, show: Bool = true) -> some View {
        self.overlay(alignment: .topTrailing) {
            if show && monitor.isMonitoring {
                PerformanceOverlayView(monitor: monitor)
            }
        }
    }
}

/// Performance overlay view
struct PerformanceOverlayView: View {
    @ObservedObject var monitor: PerformanceMonitor

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("FPS: \(Int(monitor.currentFPS))")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(fpsColor)

            if monitor.isProMotionAvailable {
                Text("ProMotion \(monitor.displayRefreshRate)Hz")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.cyan)
            }

            Text("CPU: \(Int(monitor.cpuUsage * 100))%")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))

            Text("RAM: \(Int(monitor.memoryUsageMB))MB")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.7))
        )
        .padding(12)
    }

    private var fpsColor: Color {
        let targetFPS = Double(monitor.displayRefreshRate)
        let ratio = monitor.currentFPS / targetFPS

        if ratio >= 0.9 {
            return .green
        } else if ratio >= 0.7 {
            return .yellow
        } else {
            return .red
        }
    }
}
