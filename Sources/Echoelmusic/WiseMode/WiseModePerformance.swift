import Foundation
import SwiftUI
import Combine
import os.signpost

// MARK: - Wise Mode Performance System
/// Lazy Loading, Memory Footprint Analyse und Battery Impact Messung

// MARK: - Lazy Loading System

/// Lazy Loading Manager für nicht-aktive Modi
@MainActor
class WiseLazyLoadingManager: ObservableObject {

    // MARK: - Singleton
    static let shared = WiseLazyLoadingManager()

    // MARK: - State

    @Published var loadedModes: Set<WiseMode> = []
    @Published var pendingModes: Set<WiseMode> = []
    @Published var loadingProgress: [WiseMode: Float] = [:]

    // MARK: - Configuration

    var preloadAdjacentModes: Bool = true
    var maxConcurrentLoads: Int = 2
    var unloadDelay: TimeInterval = 30.0 // Sekunden nach Mode-Wechsel

    // MARK: - Private

    private var loadTasks: [WiseMode: Task<Void, Never>] = [:]
    private var unloadTimers: [WiseMode: Timer] = [:]
    private var modeResources: [WiseMode: WiseModeResources] = [:]
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        setupModeChangeListener()

        print("🔄 WiseLazyLoadingManager: Initialized")
    }

    // MARK: - Resource Loading

    /// Lädt Ressourcen für einen Mode
    func loadMode(_ mode: WiseMode) async {
        guard !loadedModes.contains(mode) else { return }
        guard !pendingModes.contains(mode) else { return }

        pendingModes.insert(mode)
        loadingProgress[mode] = 0

        print("📥 Loading mode resources: \(mode.rawValue)")

        // Simulate progressive loading
        let resources = WiseModeResources(mode: mode)

        // Load audio resources
        loadingProgress[mode] = 0.3
        await loadAudioResources(for: mode, resources: resources)

        // Load visual resources
        loadingProgress[mode] = 0.6
        await loadVisualResources(for: mode, resources: resources)

        // Load configuration
        loadingProgress[mode] = 0.9
        await loadConfiguration(for: mode, resources: resources)

        // Complete
        loadingProgress[mode] = 1.0
        modeResources[mode] = resources
        loadedModes.insert(mode)
        pendingModes.remove(mode)

        print("✅ Mode loaded: \(mode.rawValue)")

        // Preload adjacent modes if enabled
        if preloadAdjacentModes {
            preloadAdjacentModes(for: mode)
        }
    }

    /// Entlädt Ressourcen für einen Mode
    func unloadMode(_ mode: WiseMode) {
        guard loadedModes.contains(mode) else { return }

        // Cancel any pending load
        loadTasks[mode]?.cancel()
        loadTasks.removeValue(forKey: mode)

        // Clear resources
        modeResources.removeValue(forKey: mode)
        loadedModes.remove(mode)
        loadingProgress.removeValue(forKey: mode)

        print("📤 Unloaded mode: \(mode.rawValue)")
    }

    /// Überprüft ob ein Mode geladen ist
    func isModeLoaded(_ mode: WiseMode) -> Bool {
        loadedModes.contains(mode)
    }

    /// Gibt Ressourcen für einen Mode zurück
    func getResources(for mode: WiseMode) -> WiseModeResources? {
        modeResources[mode]
    }

    // MARK: - Preloading

    private func preloadAdjacentModes(for currentMode: WiseMode) {
        let allModes = WiseMode.allCases
        guard let currentIndex = allModes.firstIndex(of: currentMode) else { return }

        var modesToPreload: [WiseMode] = []

        // Previous mode
        if currentIndex > 0 {
            modesToPreload.append(allModes[currentIndex - 1])
        }

        // Next mode
        if currentIndex < allModes.count - 1 {
            modesToPreload.append(allModes[currentIndex + 1])
        }

        for mode in modesToPreload where !loadedModes.contains(mode) && !pendingModes.contains(mode) {
            Task {
                await loadMode(mode)
            }
        }
    }

    // MARK: - Resource Loading Helpers

    private func loadAudioResources(for mode: WiseMode, resources: WiseModeResources) async {
        // Simulate loading binaural beats, carriers, etc.
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        resources.binauralFrequency = mode.binauralFrequency
        resources.carrierFrequency = 432.0
        resources.audioConfigured = true
    }

    private func loadVisualResources(for mode: WiseMode, resources: WiseModeResources) async {
        // Simulate loading visualization shaders, textures
        try? await Task.sleep(nanoseconds: 150_000_000) // 150ms

        resources.visualizationMode = mode.recommendedVisualization
        resources.colorScheme = mode.color
        resources.visualConfigured = true
    }

    private func loadConfiguration(for mode: WiseMode, resources: WiseModeResources) async {
        // Simulate loading configuration
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

        resources.configuration = WiseModeConfiguration(mode: mode)
        resources.configLoaded = true
    }

    // MARK: - Mode Change Handling

    private func setupModeChangeListener() {
        WiseModeManager.shared.$currentMode
            .sink { [weak self] newMode in
                Task { @MainActor in
                    await self?.handleModeChange(to: newMode)
                }
            }
            .store(in: &cancellables)
    }

    private func handleModeChange(to newMode: WiseMode) async {
        // Load new mode if not already loaded
        if !loadedModes.contains(newMode) {
            await loadMode(newMode)
        }

        // Schedule unloading of other modes
        for mode in loadedModes where mode != newMode {
            scheduleUnload(for: mode)
        }
    }

    private func scheduleUnload(for mode: WiseMode) {
        // Cancel existing timer
        unloadTimers[mode]?.invalidate()

        // Schedule new unload
        unloadTimers[mode] = Timer.scheduledTimer(withTimeInterval: unloadDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                // Don't unload if it's the current mode
                if WiseModeManager.shared.currentMode != mode {
                    self?.unloadMode(mode)
                }
            }
        }
    }

    // MARK: - Memory Management

    /// Erzwingt das Entladen aller nicht-aktiven Modi
    func purgeInactiveModes() {
        let currentMode = WiseModeManager.shared.currentMode

        for mode in loadedModes where mode != currentMode {
            unloadMode(mode)
        }

        print("🧹 Purged inactive modes")
    }

    /// Gibt den Speicherverbrauch aller geladenen Modi zurück
    func totalMemoryFootprint() -> Int64 {
        modeResources.values.reduce(0) { $0 + $1.estimatedMemoryBytes }
    }
}

/// Ressourcen für einen WiseMode
class WiseModeResources {
    let mode: WiseMode

    var binauralFrequency: Float = 0
    var carrierFrequency: Float = 432.0
    var visualizationMode: String = ""
    var colorScheme: Color = .blue
    var configuration: WiseModeConfiguration?

    var audioConfigured: Bool = false
    var visualConfigured: Bool = false
    var configLoaded: Bool = false

    var isFullyLoaded: Bool {
        audioConfigured && visualConfigured && configLoaded
    }

    var estimatedMemoryBytes: Int64 {
        // Rough estimates based on mode complexity
        var bytes: Int64 = 1024 * 10 // Base overhead

        if audioConfigured { bytes += 1024 * 50 } // Audio buffers
        if visualConfigured { bytes += 1024 * 200 } // Visual resources
        if configLoaded { bytes += 1024 * 5 } // Configuration

        return bytes
    }

    init(mode: WiseMode) {
        self.mode = mode
    }
}

// MARK: - Memory Footprint Analyzer

/// Analysiert den Speicherverbrauch des Wise Mode Systems
@MainActor
class WiseMemoryAnalyzer: ObservableObject {

    // MARK: - Singleton
    static let shared = WiseMemoryAnalyzer()

    // MARK: - State

    @Published var currentMemoryUsage: Int64 = 0
    @Published var peakMemoryUsage: Int64 = 0
    @Published var memoryHistory: [MemorySample] = []
    @Published var componentBreakdown: [String: Int64] = [:]

    // MARK: - Private

    private var sampleTimer: Timer?
    private let maxHistorySamples = 60 // 1 minute of history at 1s intervals

    // MARK: - Initialization

    private init() {
        startMonitoring()

        print("🧠 WiseMemoryAnalyzer: Initialized")
    }

    // MARK: - Monitoring

    func startMonitoring() {
        sampleTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sampleMemory()
            }
        }
    }

    func stopMonitoring() {
        sampleTimer?.invalidate()
        sampleTimer = nil
    }

    private func sampleMemory() {
        let usage = getMemoryUsage()
        currentMemoryUsage = usage

        if usage > peakMemoryUsage {
            peakMemoryUsage = usage
        }

        let sample = MemorySample(timestamp: Date(), bytes: usage)
        memoryHistory.append(sample)

        // Keep only recent samples
        if memoryHistory.count > maxHistorySamples {
            memoryHistory.removeFirst()
        }

        // Update component breakdown
        updateComponentBreakdown()
    }

    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }

    private func updateComponentBreakdown() {
        componentBreakdown = [
            "Wise Mode Core": WiseLazyLoadingManager.shared.totalMemoryFootprint(),
            "Presets": estimatePresetsMemory(),
            "Analytics": estimateAnalyticsMemory(),
            "Scheduler": estimateSchedulerMemory()
        ]
    }

    private func estimatePresetsMemory() -> Int64 {
        Int64(WisePresetManager.shared.presets.count * 1024 * 2)
    }

    private func estimateAnalyticsMemory() -> Int64 {
        Int64(WiseAnalyticsManager.shared.coherenceHistory.count * 32 +
              WiseAnalyticsManager.shared.dailySummaries.count * 128)
    }

    private func estimateSchedulerMemory() -> Int64 {
        Int64(WiseScheduler.shared.scheduleItems.count * 512)
    }

    // MARK: - Reports

    func generateReport() -> MemoryReport {
        MemoryReport(
            timestamp: Date(),
            currentUsage: currentMemoryUsage,
            peakUsage: peakMemoryUsage,
            componentBreakdown: componentBreakdown,
            recommendations: generateRecommendations()
        )
    }

    private func generateRecommendations() -> [String] {
        var recommendations: [String] = []

        if currentMemoryUsage > 100_000_000 { // > 100MB
            recommendations.append("Memory usage is high. Consider purging inactive modes.")
        }

        let loadedModes = WiseLazyLoadingManager.shared.loadedModes.count
        if loadedModes > 3 {
            recommendations.append("\(loadedModes) modes loaded. Unload unused modes to save memory.")
        }

        let presetCount = WisePresetManager.shared.presets.count
        if presetCount > 50 {
            recommendations.append("Large number of presets (\(presetCount)). Consider archiving unused ones.")
        }

        return recommendations
    }
}

struct MemorySample: Identifiable {
    let id = UUID()
    let timestamp: Date
    let bytes: Int64
}

struct MemoryReport: Codable {
    let timestamp: Date
    let currentUsage: Int64
    let peakUsage: Int64
    let componentBreakdown: [String: Int64]
    let recommendations: [String]

    var formattedCurrentUsage: String {
        ByteCountFormatter.string(fromByteCount: currentUsage, countStyle: .memory)
    }

    var formattedPeakUsage: String {
        ByteCountFormatter.string(fromByteCount: peakUsage, countStyle: .memory)
    }
}

// MARK: - Battery Impact Monitor

/// Misst den Battery-Impact pro Modus
@MainActor
class WiseBatteryMonitor: ObservableObject {

    // MARK: - Singleton
    static let shared = WiseBatteryMonitor()

    // MARK: - State

    @Published var currentBatteryLevel: Float = 1.0
    @Published var isCharging: Bool = false
    @Published var modeEnergyConsumption: [WiseMode: EnergyConsumption] = [:]
    @Published var currentPowerMode: PowerMode = .balanced

    // MARK: - Configuration

    enum PowerMode: String, CaseIterable {
        case lowPower = "Low Power"
        case balanced = "Balanced"
        case performance = "Performance"

        var description: String {
            switch self {
            case .lowPower: return "Maximizes battery life, reduces visual effects"
            case .balanced: return "Balance between performance and battery"
            case .performance: return "Maximum quality, higher battery usage"
            }
        }
    }

    // MARK: - Private

    private var monitoringTimer: Timer?
    private var sessionStartBattery: Float = 1.0
    private var sessionStartTime: Date?
    private var currentSessionMode: WiseMode?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        setupBatteryMonitoring()
        loadEnergyConsumptionData()
        setupModeChangeListener()

        print("🔋 WiseBatteryMonitor: Initialized")
    }

    // MARK: - Battery Monitoring

    private func setupBatteryMonitoring() {
        #if os(iOS)
        UIDevice.current.isBatteryMonitoringEnabled = true

        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateBatteryStatus()
            }
        }

        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateBatteryStatus()
            }
        }

        updateBatteryStatus()
        #endif
    }

    private func updateBatteryStatus() {
        #if os(iOS)
        currentBatteryLevel = UIDevice.current.batteryLevel
        isCharging = UIDevice.current.batteryState == .charging || UIDevice.current.batteryState == .full
        #endif
    }

    // MARK: - Session Tracking

    func startSessionTracking(mode: WiseMode) {
        sessionStartBattery = currentBatteryLevel
        sessionStartTime = Date()
        currentSessionMode = mode

        print("🔋 Started battery tracking for: \(mode.rawValue)")
    }

    func endSessionTracking() {
        guard let mode = currentSessionMode,
              let startTime = sessionStartTime,
              sessionStartBattery > 0 else { return }

        let duration = Date().timeIntervalSince(startTime)
        let batteryUsed = sessionStartBattery - currentBatteryLevel

        // Update consumption data
        var consumption = modeEnergyConsumption[mode] ?? EnergyConsumption(mode: mode)
        consumption.totalSessionMinutes += Int(duration / 60)
        consumption.totalBatteryPercentUsed += batteryUsed * 100

        if consumption.totalSessionMinutes > 0 {
            consumption.averagePercentPerHour = (consumption.totalBatteryPercentUsed / Float(consumption.totalSessionMinutes)) * 60
        }

        modeEnergyConsumption[mode] = consumption

        // Save
        saveEnergyConsumptionData()

        // Reset
        currentSessionMode = nil
        sessionStartTime = nil

        print("🔋 Session tracked: \(mode.rawValue) - \(batteryUsed * 100)% battery used")
    }

    // MARK: - Energy Consumption Data

    private func loadEnergyConsumptionData() {
        // Load from UserDefaults or initialize with estimates
        for mode in WiseMode.allCases {
            modeEnergyConsumption[mode] = EnergyConsumption(mode: mode)
        }

        // Set estimated values based on mode characteristics
        setEstimatedConsumption()
    }

    private func setEstimatedConsumption() {
        // Estimates based on visual/audio complexity
        let estimates: [WiseMode: Float] = [
            .focus: 2.5,      // Low visuals, moderate audio
            .flow: 4.0,       // High visuals, full audio
            .healing: 3.0,    // Medium visuals, full audio
            .meditation: 2.0, // Low visuals, ambient audio
            .energize: 4.5,   // High visuals, intense audio
            .sleep: 1.5,      // Minimal visuals, soft audio
            .social: 5.0,     // Network + full features
            .custom: 3.5      // Average estimate
        ]

        for (mode, estimate) in estimates {
            if modeEnergyConsumption[mode]?.totalSessionMinutes == 0 {
                modeEnergyConsumption[mode]?.averagePercentPerHour = estimate
            }
        }
    }

    private func saveEnergyConsumptionData() {
        if let data = try? JSONEncoder().encode(Array(modeEnergyConsumption.values)) {
            UserDefaults.standard.set(data, forKey: "wiseBattery.consumption")
        }
    }

    // MARK: - Power Mode

    func setPowerMode(_ mode: PowerMode) {
        currentPowerMode = mode

        // Apply settings based on power mode
        switch mode {
        case .lowPower:
            WiseLazyLoadingManager.shared.preloadAdjacentModes = false
            WiseLazyLoadingManager.shared.unloadDelay = 10.0
        case .balanced:
            WiseLazyLoadingManager.shared.preloadAdjacentModes = true
            WiseLazyLoadingManager.shared.unloadDelay = 30.0
        case .performance:
            WiseLazyLoadingManager.shared.preloadAdjacentModes = true
            WiseLazyLoadingManager.shared.unloadDelay = 120.0
        }

        print("🔋 Power mode set to: \(mode.rawValue)")
    }

    // MARK: - Recommendations

    func getRecommendation() -> BatteryRecommendation {
        if currentBatteryLevel < 0.2 && !isCharging {
            return .switchToLowPower
        } else if currentBatteryLevel < 0.1 && !isCharging {
            return .criticalBattery
        } else if isCharging {
            return .chargingOptimal
        } else {
            return .normal
        }
    }

    // MARK: - Mode Change Listener

    private func setupModeChangeListener() {
        WiseModeManager.shared.$currentMode
            .dropFirst()
            .sink { [weak self] newMode in
                // End previous session
                self?.endSessionTracking()
                // Start new session
                self?.startSessionTracking(mode: newMode)
            }
            .store(in: &cancellables)
    }
}

struct EnergyConsumption: Codable, Identifiable {
    var id: String { mode.rawValue }
    let mode: WiseMode
    var totalSessionMinutes: Int
    var totalBatteryPercentUsed: Float
    var averagePercentPerHour: Float

    init(mode: WiseMode) {
        self.mode = mode
        self.totalSessionMinutes = 0
        self.totalBatteryPercentUsed = 0
        self.averagePercentPerHour = 0
    }

    var efficiencyRating: String {
        if averagePercentPerHour < 2.0 {
            return "Excellent"
        } else if averagePercentPerHour < 3.5 {
            return "Good"
        } else if averagePercentPerHour < 5.0 {
            return "Moderate"
        } else {
            return "High"
        }
    }

    var estimatedRuntime: String {
        guard averagePercentPerHour > 0 else { return "N/A" }
        let hours = 100.0 / averagePercentPerHour
        return String(format: "%.1fh", hours)
    }
}

enum BatteryRecommendation {
    case normal
    case switchToLowPower
    case criticalBattery
    case chargingOptimal

    var message: String {
        switch self {
        case .normal: return "Battery level is good"
        case .switchToLowPower: return "Low battery - switch to Low Power mode"
        case .criticalBattery: return "Critical battery - save your work"
        case .chargingOptimal: return "Charging - optimal for Performance mode"
        }
    }
}

// MARK: - Performance Benchmark

/// Performance Benchmark System pro Modus
@MainActor
class WisePerformanceBenchmark: ObservableObject {

    // MARK: - Singleton
    static let shared = WisePerformanceBenchmark()

    // MARK: - State

    @Published var benchmarkResults: [WiseMode: BenchmarkResult] = [:]
    @Published var isRunning: Bool = false
    @Published var currentProgress: Float = 0

    // MARK: - Signposts for Instruments

    private let signpostLog = OSLog(subsystem: "com.echoelmusic.wise", category: "Performance")

    // MARK: - Initialization

    private init() {
        print("⏱️ WisePerformanceBenchmark: Initialized")
    }

    // MARK: - Benchmark Execution

    /// Führt Benchmarks für alle Modi aus
    func runFullBenchmark() async {
        isRunning = true
        currentProgress = 0

        let modes = WiseMode.allCases
        let progressStep = 1.0 / Float(modes.count)

        for (index, mode) in modes.enumerated() {
            let result = await benchmarkMode(mode)
            benchmarkResults[mode] = result
            currentProgress = Float(index + 1) * progressStep
        }

        isRunning = false
        currentProgress = 1.0

        print("⏱️ Benchmark complete for all modes")
    }

    /// Führt Benchmark für einen einzelnen Modus aus
    func benchmarkMode(_ mode: WiseMode) async -> BenchmarkResult {
        let signpostID = OSSignpostID(log: signpostLog)
        os_signpost(.begin, log: signpostLog, name: "Mode Benchmark", signpostID: signpostID, "Mode: %{public}s", mode.rawValue)

        var result = BenchmarkResult(mode: mode)

        // 1. Load Time
        let loadStart = CFAbsoluteTimeGetCurrent()
        await WiseLazyLoadingManager.shared.loadMode(mode)
        result.loadTimeMs = (CFAbsoluteTimeGetCurrent() - loadStart) * 1000

        // 2. Switch Time
        let switchStart = CFAbsoluteTimeGetCurrent()
        WiseModeManager.shared.switchMode(to: mode)
        // Wait for transition
        try? await Task.sleep(nanoseconds: 2_100_000_000)
        result.switchTimeMs = (CFAbsoluteTimeGetCurrent() - switchStart) * 1000

        // 3. Memory Usage
        result.memoryBytes = WiseLazyLoadingManager.shared.getResources(for: mode)?.estimatedMemoryBytes ?? 0

        // 4. CPU Usage Estimate (based on mode complexity)
        result.cpuUsagePercent = estimateCPUUsage(for: mode)

        // 5. GPU Usage Estimate
        result.gpuUsagePercent = estimateGPUUsage(for: mode)

        // 6. Frame Rate (simulated)
        result.averageFPS = estimateFPS(for: mode)

        os_signpost(.end, log: signpostLog, name: "Mode Benchmark", signpostID: signpostID)

        return result
    }

    private func estimateCPUUsage(for mode: WiseMode) -> Float {
        switch mode {
        case .focus: return 15.0
        case .flow: return 35.0
        case .healing: return 25.0
        case .meditation: return 10.0
        case .energize: return 40.0
        case .sleep: return 8.0
        case .social: return 45.0
        case .custom: return 25.0
        }
    }

    private func estimateGPUUsage(for mode: WiseMode) -> Float {
        switch mode {
        case .focus: return 20.0
        case .flow: return 55.0
        case .healing: return 40.0
        case .meditation: return 30.0
        case .energize: return 60.0
        case .sleep: return 15.0
        case .social: return 45.0
        case .custom: return 35.0
        }
    }

    private func estimateFPS(for mode: WiseMode) -> Float {
        switch mode {
        case .focus: return 60.0
        case .flow: return 60.0
        case .healing: return 60.0
        case .meditation: return 30.0 // Reduced for calm experience
        case .energize: return 60.0
        case .sleep: return 24.0 // Reduced for power saving
        case .social: return 60.0
        case .custom: return 60.0
        }
    }

    // MARK: - Report

    func generateReport() -> String {
        var report = "=== WISE MODE PERFORMANCE BENCHMARK ===\n\n"

        for mode in WiseMode.allCases {
            if let result = benchmarkResults[mode] {
                report += "[\(mode.rawValue)]\n"
                report += "  Load Time: \(String(format: "%.1f", result.loadTimeMs))ms\n"
                report += "  Switch Time: \(String(format: "%.1f", result.switchTimeMs))ms\n"
                report += "  Memory: \(ByteCountFormatter.string(fromByteCount: result.memoryBytes, countStyle: .memory))\n"
                report += "  CPU: \(String(format: "%.1f", result.cpuUsagePercent))%\n"
                report += "  GPU: \(String(format: "%.1f", result.gpuUsagePercent))%\n"
                report += "  FPS: \(String(format: "%.0f", result.averageFPS))\n"
                report += "  Score: \(String(format: "%.0f", result.overallScore))\n\n"
            }
        }

        return report
    }
}

struct BenchmarkResult: Codable, Identifiable {
    var id: String { mode.rawValue }
    let mode: WiseMode
    var loadTimeMs: Double = 0
    var switchTimeMs: Double = 0
    var memoryBytes: Int64 = 0
    var cpuUsagePercent: Float = 0
    var gpuUsagePercent: Float = 0
    var averageFPS: Float = 60

    var overallScore: Float {
        // Higher is better
        var score: Float = 100

        // Penalize slow load times (target: <300ms)
        if loadTimeMs > 300 { score -= Float((loadTimeMs - 300) / 10) }

        // Penalize slow switch times (target: <2100ms)
        if switchTimeMs > 2100 { score -= Float((switchTimeMs - 2100) / 50) }

        // Penalize high memory (target: <500KB)
        if memoryBytes > 500_000 { score -= Float((memoryBytes - 500_000) / 100_000) }

        // Penalize high CPU (target: <30%)
        if cpuUsagePercent > 30 { score -= (cpuUsagePercent - 30) }

        // Penalize low FPS (target: 60)
        if averageFPS < 60 { score -= (60 - averageFPS) }

        return max(0, min(100, score))
    }
}

// MARK: - Performance Dashboard View

struct WisePerformanceDashboard: View {
    @ObservedObject var memory = WiseMemoryAnalyzer.shared
    @ObservedObject var battery = WiseBatteryMonitor.shared
    @ObservedObject var benchmark = WisePerformanceBenchmark.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Memory Section
                MemorySectionView(analyzer: memory)

                // Battery Section
                BatterySectionView(monitor: battery)

                // Benchmark Section
                BenchmarkSectionView(benchmark: benchmark)
            }
            .padding()
        }
    }
}

struct MemorySectionView: View {
    @ObservedObject var analyzer: WiseMemoryAnalyzer

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Memory Usage")
                .font(.headline)

            HStack {
                VStack(alignment: .leading) {
                    Text("Current")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(ByteCountFormatter.string(fromByteCount: analyzer.currentMemoryUsage, countStyle: .memory))
                        .font(.title2)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("Peak")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(ByteCountFormatter.string(fromByteCount: analyzer.peakMemoryUsage, countStyle: .memory))
                        .font(.title2)
                }
            }

            // Component breakdown
            ForEach(analyzer.componentBreakdown.sorted(by: { $0.value > $1.value }), id: \.key) { component, bytes in
                HStack {
                    Text(component)
                        .font(.caption)
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .memory))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct BatterySectionView: View {
    @ObservedObject var monitor: WiseBatteryMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Battery Impact")
                    .font(.headline)
                Spacer()
                Text("\(Int(monitor.currentBatteryLevel * 100))%")
                    .font(.headline)
                    .foregroundColor(monitor.currentBatteryLevel > 0.2 ? .green : .red)
            }

            Picker("Power Mode", selection: Binding(
                get: { monitor.currentPowerMode },
                set: { monitor.setPowerMode($0) }
            )) {
                ForEach(WiseBatteryMonitor.PowerMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            // Mode consumption list
            ForEach(WiseMode.allCases, id: \.self) { mode in
                if let consumption = monitor.modeEnergyConsumption[mode] {
                    HStack {
                        Image(systemName: mode.icon)
                            .foregroundColor(mode.color)
                            .frame(width: 24)
                        Text(mode.rawValue)
                            .font(.caption)
                        Spacer()
                        Text("\(String(format: "%.1f", consumption.averagePercentPerHour))%/h")
                            .font(.caption)
                        Text(consumption.efficiencyRating)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(efficiencyColor(consumption.efficiencyRating).opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    func efficiencyColor(_ rating: String) -> Color {
        switch rating {
        case "Excellent": return .green
        case "Good": return .blue
        case "Moderate": return .orange
        default: return .red
        }
    }
}

struct BenchmarkSectionView: View {
    @ObservedObject var benchmark: WisePerformanceBenchmark

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Performance Benchmark")
                    .font(.headline)
                Spacer()
                Button("Run") {
                    Task {
                        await benchmark.runFullBenchmark()
                    }
                }
                .disabled(benchmark.isRunning)
            }

            if benchmark.isRunning {
                ProgressView(value: benchmark.currentProgress)
            }

            if !benchmark.benchmarkResults.isEmpty {
                ForEach(WiseMode.allCases, id: \.self) { mode in
                    if let result = benchmark.benchmarkResults[mode] {
                        HStack {
                            Image(systemName: mode.icon)
                                .foregroundColor(mode.color)
                                .frame(width: 24)
                            Text(mode.rawValue)
                                .font(.caption)
                            Spacer()
                            Text("Score: \(Int(result.overallScore))")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(scoreColor(result.overallScore))
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    func scoreColor(_ score: Float) -> Color {
        if score >= 80 { return .green }
        else if score >= 60 { return .orange }
        else { return .red }
    }
}
