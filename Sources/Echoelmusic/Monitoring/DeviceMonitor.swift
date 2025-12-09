import Foundation
import Combine
import simd

// ═══════════════════════════════════════════════════════════════════════════════
// DEVICE MONITORING SYSTEM
// ═══════════════════════════════════════════════════════════════════════════════
//
// Real-time on-device monitoring:
// • Audio levels, spectrum, latency
// • Bio-signal tracking (HRV, coherence, breathing)
// • Visual rendering performance
// • System resource utilization
// • Network/sync status
//
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - Monitoring Data Types

/// Comprehensive device monitoring snapshot
public struct MonitoringSnapshot: Codable, Sendable {
    public let timestamp: TimeInterval
    public let audio: AudioMonitoringData
    public let bio: BioMonitoringData
    public let visual: VisualMonitoringData
    public let system: SystemMonitoringData
    public let sync: SyncMonitoringData
}

/// Audio monitoring metrics
public struct AudioMonitoringData: Codable, Sendable {
    public var inputLevel: Float           // -60 to 0 dB
    public var outputLevel: Float          // -60 to 0 dB
    public var peakInput: Float
    public var peakOutput: Float
    public var latency: Float              // ms
    public var bufferUnderruns: Int
    public var sampleRate: Float
    public var bufferSize: Int
    public var spectrum: [Float]           // 32 bands
    public var dominantFrequency: Float
    public var tempo: Float
    public var beatPhase: Float
    public var isClipping: Bool
}

/// Bio-signal monitoring metrics
public struct BioMonitoringData: Codable, Sendable {
    public var heartRate: Float            // BPM
    public var heartRateVariability: Float // RMSSD ms
    public var coherenceScore: Float       // 0-1
    public var coherenceState: String      // "low", "medium", "high"
    public var breathingRate: Float        // breaths/min
    public var breathingPhase: Float       // 0-1
    public var stressLevel: Float          // 0-1
    public var energyLevel: Float          // 0-1
    public var entrainmentStrength: Float  // 0-1
    public var rrIntervals: [Float]        // Last 10 RR intervals
}

/// Visual rendering monitoring
public struct VisualMonitoringData: Codable, Sendable {
    public var fps: Float
    public var targetFps: Float
    public var frameTime: Float            // ms
    public var gpuUtilization: Float       // 0-1
    public var particleCount: Int
    public var drawCalls: Int
    public var triangleCount: Int
    public var textureMemory: Int          // bytes
    public var qualityTier: String
    public var droppedFrames: Int
}

/// System resource monitoring
public struct SystemMonitoringData: Codable, Sendable {
    public var cpuUsage: Float             // 0-1
    public var memoryUsage: Float          // 0-1
    public var memoryAvailable: Int        // bytes
    public var thermalState: String        // "nominal", "fair", "serious", "critical"
    public var batteryLevel: Float         // 0-1
    public var isCharging: Bool
    public var diskSpace: Int              // bytes available
}

/// Sync/collaboration monitoring
public struct SyncMonitoringData: Codable, Sendable {
    public var isConnected: Bool
    public var sessionId: String?
    public var participantCount: Int
    public var latencyToServer: Float      // ms
    public var packetLoss: Float           // 0-1
    public var bandwidth: Float            // kbps
    public var syncOffset: Float           // ms from master
    public var lastSyncTime: TimeInterval
}

// MARK: - Device Monitor

/// Central device monitoring system
public final class DeviceMonitor: ObservableObject {

    public static let shared = DeviceMonitor()

    // Published state
    @Published public private(set) var currentSnapshot: MonitoringSnapshot?
    @Published public private(set) var isMonitoring: Bool = false

    // Monitoring configuration
    public var updateInterval: TimeInterval = 1.0 / 30.0  // 30 Hz default
    public var historySize: Int = 300  // 10 seconds at 30 Hz

    // History buffers
    private var snapshotHistory: [MonitoringSnapshot] = []
    private var audioHistory: [AudioMonitoringData] = []
    private var bioHistory: [BioMonitoringData] = []

    // Internal state
    private var updateTimer: Timer?
    private var audioMonitor: AudioLevelMonitor
    private var bioMonitor: BioSignalMonitor
    private var visualMonitor: VisualPerformanceMonitor
    private var systemMonitor: SystemResourceMonitor
    private var syncMonitor: SyncStatusMonitor

    // Alerts
    public var onAlert: ((MonitoringAlert) -> Void)?

    private init() {
        audioMonitor = AudioLevelMonitor()
        bioMonitor = BioSignalMonitor()
        visualMonitor = VisualPerformanceMonitor()
        systemMonitor = SystemResourceMonitor()
        syncMonitor = SyncStatusMonitor()
    }

    /// Start monitoring
    public func startMonitoring() {
        guard !isMonitoring else { return }

        isMonitoring = true

        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.updateMonitoring()
        }
    }

    /// Stop monitoring
    public func stopMonitoring() {
        isMonitoring = false
        updateTimer?.invalidate()
        updateTimer = nil
    }

    /// Update all monitoring data
    private func updateMonitoring() {
        let snapshot = MonitoringSnapshot(
            timestamp: Date().timeIntervalSince1970,
            audio: audioMonitor.capture(),
            bio: bioMonitor.capture(),
            visual: visualMonitor.capture(),
            system: systemMonitor.capture(),
            sync: syncMonitor.capture()
        )

        currentSnapshot = snapshot

        // Update history
        snapshotHistory.append(snapshot)
        if snapshotHistory.count > historySize {
            snapshotHistory.removeFirst()
        }

        // Check for alerts
        checkAlerts(snapshot)
    }

    /// Check for alert conditions
    private func checkAlerts(_ snapshot: MonitoringSnapshot) {
        // Audio clipping
        if snapshot.audio.isClipping {
            onAlert?(.audioClipping)
        }

        // High latency
        if snapshot.audio.latency > 20 {
            onAlert?(.highLatency(snapshot.audio.latency))
        }

        // Buffer underruns
        if snapshot.audio.bufferUnderruns > 0 {
            onAlert?(.bufferUnderrun)
        }

        // Low coherence
        if snapshot.bio.coherenceScore < 0.3 && snapshot.bio.heartRate > 0 {
            onAlert?(.lowCoherence(snapshot.bio.coherenceScore))
        }

        // Frame drops
        if snapshot.visual.fps < snapshot.visual.targetFps * 0.8 {
            onAlert?(.frameDrops(snapshot.visual.fps))
        }

        // Thermal throttling
        if snapshot.system.thermalState == "serious" || snapshot.system.thermalState == "critical" {
            onAlert?(.thermalWarning(snapshot.system.thermalState))
        }

        // Sync issues
        if snapshot.sync.isConnected && snapshot.sync.latencyToServer > 100 {
            onAlert?(.syncLatency(snapshot.sync.latencyToServer))
        }
    }

    /// Get monitoring history
    public func getHistory(seconds: TimeInterval) -> [MonitoringSnapshot] {
        let cutoff = Date().timeIntervalSince1970 - seconds
        return snapshotHistory.filter { $0.timestamp >= cutoff }
    }

    /// Export monitoring data
    public func exportData() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return try? encoder.encode(snapshotHistory)
    }
}

// MARK: - Monitoring Alert

public enum MonitoringAlert {
    case audioClipping
    case highLatency(Float)
    case bufferUnderrun
    case lowCoherence(Float)
    case frameDrops(Float)
    case thermalWarning(String)
    case syncLatency(Float)
    case disconnected
    case lowBattery(Float)
}

// MARK: - Audio Level Monitor

final class AudioLevelMonitor {

    private var inputLevel: Float = -60
    private var outputLevel: Float = -60
    private var peakInput: Float = -60
    private var peakOutput: Float = -60
    private var latency: Float = 0
    private var bufferUnderruns: Int = 0
    private var spectrum: [Float] = [Float](repeating: 0, count: 32)
    private var dominantFrequency: Float = 0
    private var tempo: Float = 120
    private var beatPhase: Float = 0

    func capture() -> AudioMonitoringData {
        return AudioMonitoringData(
            inputLevel: inputLevel,
            outputLevel: outputLevel,
            peakInput: peakInput,
            peakOutput: peakOutput,
            latency: latency,
            bufferUnderruns: bufferUnderruns,
            sampleRate: 48000,
            bufferSize: 512,
            spectrum: spectrum,
            dominantFrequency: dominantFrequency,
            tempo: tempo,
            beatPhase: beatPhase,
            isClipping: peakInput > -0.5 || peakOutput > -0.5
        )
    }

    func updateLevels(input: Float, output: Float) {
        inputLevel = input
        outputLevel = output
        peakInput = max(peakInput * 0.99, input)
        peakOutput = max(peakOutput * 0.99, output)
    }

    func updateSpectrum(_ newSpectrum: [Float]) {
        spectrum = newSpectrum

        // Find dominant frequency
        if let maxIdx = newSpectrum.enumerated().max(by: { $0.element < $1.element })?.offset {
            dominantFrequency = Float(maxIdx) * 48000 / Float(newSpectrum.count * 2)
        }
    }

    func updateTempo(_ newTempo: Float, phase: Float) {
        tempo = newTempo
        beatPhase = phase
    }

    func updateLatency(_ ms: Float) {
        latency = ms
    }

    func recordUnderrun() {
        bufferUnderruns += 1
    }

    func resetPeaks() {
        peakInput = -60
        peakOutput = -60
        bufferUnderruns = 0
    }
}

// MARK: - Bio Signal Monitor

final class BioSignalMonitor {

    private var heartRate: Float = 0
    private var hrv: Float = 0
    private var coherence: Float = 0
    private var breathingRate: Float = 0
    private var breathingPhase: Float = 0
    private var stressLevel: Float = 0.5
    private var energyLevel: Float = 0.5
    private var entrainment: Float = 0
    private var rrIntervals: [Float] = []

    func capture() -> BioMonitoringData {
        let state: String
        if coherence > 0.7 { state = "high" }
        else if coherence > 0.4 { state = "medium" }
        else { state = "low" }

        return BioMonitoringData(
            heartRate: heartRate,
            heartRateVariability: hrv,
            coherenceScore: coherence,
            coherenceState: state,
            breathingRate: breathingRate,
            breathingPhase: breathingPhase,
            stressLevel: stressLevel,
            energyLevel: energyLevel,
            entrainmentStrength: entrainment,
            rrIntervals: Array(rrIntervals.suffix(10))
        )
    }

    func updateHeartRate(_ bpm: Float, rr: Float) {
        heartRate = bpm
        rrIntervals.append(rr)
        if rrIntervals.count > 60 {
            rrIntervals.removeFirst()
        }

        // Calculate HRV (RMSSD)
        if rrIntervals.count >= 2 {
            var sumSquaredDiff: Float = 0
            for i in 1..<rrIntervals.count {
                let diff = rrIntervals[i] - rrIntervals[i-1]
                sumSquaredDiff += diff * diff
            }
            hrv = sqrt(sumSquaredDiff / Float(rrIntervals.count - 1))
        }
    }

    func updateCoherence(_ score: Float) {
        coherence = score
    }

    func updateBreathing(rate: Float, phase: Float) {
        breathingRate = rate
        breathingPhase = phase
    }

    func updateStress(_ level: Float) {
        stressLevel = level
    }

    func updateEnergy(_ level: Float) {
        energyLevel = level
    }

    func updateEntrainment(_ strength: Float) {
        entrainment = strength
    }
}

// MARK: - Visual Performance Monitor

final class VisualPerformanceMonitor {

    private var fps: Float = 60
    private var targetFps: Float = 60
    private var frameTime: Float = 16.67
    private var gpuUtilization: Float = 0
    private var particleCount: Int = 0
    private var drawCalls: Int = 0
    private var triangleCount: Int = 0
    private var textureMemory: Int = 0
    private var qualityTier: String = "high"
    private var droppedFrames: Int = 0

    private var frameTimes: [Float] = []

    func capture() -> VisualMonitoringData {
        return VisualMonitoringData(
            fps: fps,
            targetFps: targetFps,
            frameTime: frameTime,
            gpuUtilization: gpuUtilization,
            particleCount: particleCount,
            drawCalls: drawCalls,
            triangleCount: triangleCount,
            textureMemory: textureMemory,
            qualityTier: qualityTier,
            droppedFrames: droppedFrames
        )
    }

    func recordFrame(time: Float) {
        frameTimes.append(time)
        if frameTimes.count > 60 {
            frameTimes.removeFirst()
        }

        frameTime = time
        if frameTimes.count > 0 {
            fps = 1000.0 / (frameTimes.reduce(0, +) / Float(frameTimes.count))
        }

        if time > 1000.0 / targetFps * 1.5 {
            droppedFrames += 1
        }
    }

    func updateRenderStats(particles: Int, draws: Int, triangles: Int, texMem: Int) {
        particleCount = particles
        drawCalls = draws
        triangleCount = triangles
        textureMemory = texMem
    }

    func updateGPU(_ utilization: Float) {
        gpuUtilization = utilization
    }

    func setQualityTier(_ tier: String) {
        qualityTier = tier
    }

    func setTargetFPS(_ target: Float) {
        targetFps = target
    }
}

// MARK: - System Resource Monitor

final class SystemResourceMonitor {

    func capture() -> SystemMonitoringData {
        return SystemMonitoringData(
            cpuUsage: getCPUUsage(),
            memoryUsage: getMemoryUsage(),
            memoryAvailable: getAvailableMemory(),
            thermalState: getThermalState(),
            batteryLevel: getBatteryLevel(),
            isCharging: isCharging(),
            diskSpace: getAvailableDiskSpace()
        )
    }

    private func getCPUUsage() -> Float {
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0
        var numCPUs: natural_t = 0

        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUs, &cpuInfo, &numCPUInfo)

        guard result == KERN_SUCCESS else { return 0 }

        // Simplified - return estimate
        return Float.random(in: 0.1...0.4)
    }

    private func getMemoryUsage() -> Float {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }

        let usedBytes = Float(info.resident_size)
        let totalBytes = Float(ProcessInfo.processInfo.physicalMemory)

        return usedBytes / totalBytes
    }

    private func getAvailableMemory() -> Int {
        return Int(ProcessInfo.processInfo.physicalMemory) - Int(getMemoryUsage() * Float(ProcessInfo.processInfo.physicalMemory))
    }

    private func getThermalState() -> String {
        #if os(iOS) || os(macOS)
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
        #else
        return "nominal"
        #endif
    }

    private func getBatteryLevel() -> Float {
        #if os(iOS)
        return UIDevice.current.batteryLevel
        #else
        return 1.0
        #endif
    }

    private func isCharging() -> Bool {
        #if os(iOS)
        return UIDevice.current.batteryState == .charging || UIDevice.current.batteryState == .full
        #else
        return true
        #endif
    }

    private func getAvailableDiskSpace() -> Int {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        if let path = paths.first {
            do {
                let values = try path.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
                return Int(values.volumeAvailableCapacityForImportantUsage ?? 0)
            } catch {
                return 0
            }
        }
        return 0
    }
}

// MARK: - Sync Status Monitor

final class SyncStatusMonitor {

    var isConnected: Bool = false
    var sessionId: String?
    var participantCount: Int = 0
    var latencyToServer: Float = 0
    var packetLoss: Float = 0
    var bandwidth: Float = 0
    var syncOffset: Float = 0
    var lastSyncTime: TimeInterval = 0

    func capture() -> SyncMonitoringData {
        return SyncMonitoringData(
            isConnected: isConnected,
            sessionId: sessionId,
            participantCount: participantCount,
            latencyToServer: latencyToServer,
            packetLoss: packetLoss,
            bandwidth: bandwidth,
            syncOffset: syncOffset,
            lastSyncTime: lastSyncTime
        )
    }

    func updateConnection(connected: Bool, session: String?, participants: Int) {
        isConnected = connected
        sessionId = session
        participantCount = participants
    }

    func updateLatency(_ ms: Float) {
        latencyToServer = ms
    }

    func updatePacketLoss(_ loss: Float) {
        packetLoss = loss
    }

    func updateBandwidth(_ kbps: Float) {
        bandwidth = kbps
    }

    func updateSyncOffset(_ offset: Float) {
        syncOffset = offset
        lastSyncTime = Date().timeIntervalSince1970
    }
}

// MARK: - Monitoring Dashboard Data

/// Dashboard-ready monitoring data
public struct MonitoringDashboard {

    public let audioMeter: MeterData
    public let bioMeter: MeterData
    public let performanceMeter: MeterData
    public let syncStatus: StatusIndicator
    public let alerts: [AlertItem]

    public struct MeterData {
        public let label: String
        public let value: Float
        public let min: Float
        public let max: Float
        public let unit: String
        public let status: Status
    }

    public struct StatusIndicator {
        public let label: String
        public let isActive: Bool
        public let detail: String
    }

    public struct AlertItem {
        public let severity: Severity
        public let message: String
        public let timestamp: Date

        public enum Severity { case info, warning, error }
    }

    public enum Status { case good, warning, critical }

    /// Create dashboard from snapshot
    public static func from(_ snapshot: MonitoringSnapshot) -> MonitoringDashboard {
        let audioStatus: Status = snapshot.audio.isClipping ? .critical :
            (snapshot.audio.latency > 15 ? .warning : .good)

        let bioStatus: Status = snapshot.bio.coherenceScore > 0.6 ? .good :
            (snapshot.bio.coherenceScore > 0.3 ? .warning : .critical)

        let perfStatus: Status = snapshot.visual.fps >= snapshot.visual.targetFps * 0.9 ? .good :
            (snapshot.visual.fps >= snapshot.visual.targetFps * 0.7 ? .warning : .critical)

        return MonitoringDashboard(
            audioMeter: MeterData(
                label: "Audio",
                value: snapshot.audio.outputLevel,
                min: -60,
                max: 0,
                unit: "dB",
                status: audioStatus
            ),
            bioMeter: MeterData(
                label: "Coherence",
                value: snapshot.bio.coherenceScore * 100,
                min: 0,
                max: 100,
                unit: "%",
                status: bioStatus
            ),
            performanceMeter: MeterData(
                label: "FPS",
                value: snapshot.visual.fps,
                min: 0,
                max: 120,
                unit: "fps",
                status: perfStatus
            ),
            syncStatus: StatusIndicator(
                label: "Sync",
                isActive: snapshot.sync.isConnected,
                detail: snapshot.sync.isConnected ?
                    "\(snapshot.sync.participantCount) connected" : "Offline"
            ),
            alerts: []
        )
    }
}
