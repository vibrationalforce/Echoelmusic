import Foundation
import Combine
import Metal
import MetalKit

/// Adaptive Quality Manager für automatische Performance-Optimierung
///
/// Dieses System überwacht kontinuierlich die Performance-Metriken und passt
/// die Qualitätseinstellungen dynamisch an, um eine flüssige Nutzererfahrung
/// auf allen Geräten zu gewährleisten - besonders auf älteren/schwächeren Geräten.
///
/// Features:
/// - Echtzeit FPS-Monitoring mit gleitenden Durchschnitten
/// - CPU/GPU-Auslastungsüberwachung
/// - Speicherdruck-Erkennung und Reaktion
/// - Thermische Zustandsüberwachung
/// - Automatische Qualitätsdegradation und -wiederherstellung
/// - Adaptive Puffer-Größenanpassung
/// - Hysterese zur Vermeidung von "Flackern" zwischen Qualitätsstufen
///
@MainActor
@Observable
class AdaptiveQualityManager {

    // MARK: - Published Properties

    /// Aktuelle Qualitätsstufe
    var currentQuality: QualityLevel = .high {
        didSet {
            if currentQuality != oldValue {
                qualityChangePublisher.send(currentQuality)
                log.performance("📊 Quality Level changed: \(oldValue.rawValue) → \(currentQuality.rawValue)")
            }
        }
    }

    /// Performance-Metriken
    var metrics: PerformanceMetrics = PerformanceMetrics()

    /// Ist adaptive Qualität aktiviert?
    var isAdaptiveQualityEnabled: Bool = true

    /// Aktuelle visuelle Einstellungen
    var visualSettings: VisualSettings = VisualSettings()

    /// Aktuelle Audio-Einstellungen
    var audioSettings: AudioSettings = AudioSettings()

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    // OPTIMIERT: Circular Buffer statt Array für O(1) Performance
    private var frameTimestampBuffer: [TimeInterval]
    private var frameBufferIndex: Int = 0
    private var frameBufferCount: Int = 0

    private var lastQualityChange: Date = Date()
    private let qualityChangePublisher = PassthroughSubject<QualityLevel, Never>()

    /// Hysterese-Timer: Verhindert zu häufige Qualitätsänderungen
    private let hysteresisDelay: TimeInterval = 3.0

    /// Bewegter Durchschnitt für FPS (letzte 60 Frames)
    private let fpsWindowSize: Int = 60

    init() {
        // Pre-allocate circular buffer
        frameTimestampBuffer = [TimeInterval](repeating: 0, count: fpsWindowSize)
    }

    /// Schwellenwerte für Qualitätsanpassungen
    private let thresholds = QualityThresholds()

    // MARK: - Quality Level Definition

    enum QualityLevel: String, CaseIterable, Comparable {
        case minimal = "Minimal"
        case low = "Niedrig"
        case medium = "Mittel"
        case high = "Hoch"
        case ultra = "Ultra"

        static func < (lhs: QualityLevel, rhs: QualityLevel) -> Bool {
            let order: [QualityLevel] = [.minimal, .low, .medium, .high, .ultra]
            guard let lhsIndex = order.firstIndex(of: lhs),
                  let rhsIndex = order.firstIndex(of: rhs) else {
                return false
            }
            return lhsIndex < rhsIndex
        }

        var targetFPS: Float {
            switch self {
            case .minimal: return 24.0
            case .low: return 30.0
            case .medium: return 60.0
            case .high: return 90.0
            case .ultra: return 120.0
            }
        }

        var maxParticles: Int {
            switch self {
            case .minimal: return 256
            case .low: return 512
            case .medium: return 2048
            case .high: return 4096
            case .ultra: return 8192
            }
        }

        var audioBufferSize: Int {
            switch self {
            case .minimal: return 2048
            case .low: return 1024
            case .medium: return 512
            case .high: return 256
            case .ultra: return 128
            }
        }

        var textureQuality: Float {
            switch self {
            case .minimal: return 0.25
            case .low: return 0.5
            case .medium: return 0.75
            case .high: return 1.0
            case .ultra: return 1.0
            }
        }
    }

    // MARK: - Performance Metrics

    struct PerformanceMetrics {
        var currentFPS: Float = 60.0
        var averageFPS: Float = 60.0
        var minFPS: Float = 60.0
        var maxFPS: Float = 60.0

        var cpuUsage: Float = 0.0
        var gpuUsage: Float = 0.0
        var memoryUsage: Float = 0.0
        var thermalState: ThermalState = .nominal

        var frameDrops: Int = 0
        var audioUnderruns: Int = 0

        var lastUpdateTime: Date = Date()

        enum ThermalState: String {
            case nominal = "Normal"
            case fair = "Warm"
            case serious = "Heiß"
            case critical = "Kritisch"

            var performanceMultiplier: Float {
                switch self {
                case .nominal: return 1.0
                case .fair: return 0.85
                case .serious: return 0.7
                case .critical: return 0.5
                }
            }
        }
    }

    // MARK: - Quality Thresholds

    struct QualityThresholds {
        // FPS-Schwellenwerte
        let fpsMinimal: Float = 20.0
        let fpsLow: Float = 25.0
        let fpsMedium: Float = 45.0
        let fpsHigh: Float = 75.0

        // CPU-Auslastung
        let cpuCritical: Float = 0.9
        let cpuHigh: Float = 0.75
        let cpuMedium: Float = 0.6

        // GPU-Auslastung
        let gpuCritical: Float = 0.95
        let gpuHigh: Float = 0.8
        let gpuMedium: Float = 0.65

        // Speicher-Auslastung
        let memoryCritical: Float = 0.9
        let memoryHigh: Float = 0.75
        let memoryMedium: Float = 0.6
    }

    // MARK: - Visual Settings

    struct VisualSettings {
        var particleCount: Int = 4096
        var textureResolution: Float = 1.0

        var enableBloom: Bool = true
        var enableMotionBlur: Bool = true
        var enableAmbientOcclusion: Bool = true
        var enableShadows: Bool = true
        var enableReflections: Bool = true

        var shadowQuality: ShadowQuality = .high
        var antialiasing: AntialiasingMode = .msaa4x

        var renderScale: Float = 1.0

        enum ShadowQuality: String {
            case off = "Aus"
            case low = "Niedrig"
            case medium = "Mittel"
            case high = "Hoch"
            case ultra = "Ultra"

            var resolution: Int {
                switch self {
                case .off: return 0
                case .low: return 512
                case .medium: return 1024
                case .high: return 2048
                case .ultra: return 4096
                }
            }
        }

        enum AntialiasingMode: String {
            case off = "Aus"
            case fxaa = "FXAA"
            case msaa2x = "MSAA 2x"
            case msaa4x = "MSAA 4x"
            case msaa8x = "MSAA 8x"
        }
    }

    // MARK: - Audio Settings

    struct AudioSettings {
        var sampleRate: Int = 48000
        var bufferSize: Int = 512
        var bitDepth: Int = 32

        var maxVoices: Int = 128
        var enableReverb: Bool = true
        var enableConvolution: Bool = true
        var enableSpatialAudio: Bool = true

        var dspQuality: DSPQuality = .high

        enum DSPQuality: String {
            case minimal = "Minimal"
            case low = "Niedrig"
            case medium = "Mittel"
            case high = "Hoch"
            case ultra = "Ultra"

            var oversamplingFactor: Int {
                switch self {
                case .minimal: return 1
                case .low: return 1
                case .medium: return 2
                case .high: return 4
                case .ultra: return 8
                }
            }
        }
    }

    // MARK: - Initialization

    init() {
        startMonitoring()
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        // Überwache Performance alle 500ms
        Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor in
                    await self.updateMetrics()
                    self.evaluateQuality()
                }
            }
            .store(in: &cancellables)

        // Thermal State Monitoring
        #if os(iOS)
        NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor in
                    self.updateThermalState()
                }
            }
            .store(in: &cancellables)
        #endif

        // Memory Warning Monitoring
        #if os(iOS)
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor in
                    self.handleMemoryWarning()
                }
            }
            .store(in: &cancellables)
        #endif
    }

    // MARK: - Metrics Update

    func updateMetrics() async {
        updateFPS()
        updateCPUUsage()
        updateGPUUsage()
        updateMemoryUsage()
        updateThermalState()

        metrics.lastUpdateTime = Date()
    }

    func recordFrame(timestamp: TimeInterval) {
        // OPTIMIERT: O(1) Circular Buffer Insert statt O(n) removeFirst()
        frameTimestampBuffer[frameBufferIndex] = timestamp
        frameBufferIndex = (frameBufferIndex + 1) % fpsWindowSize
        frameBufferCount = min(frameBufferCount + 1, fpsWindowSize)
    }

    private func updateFPS() {
        guard frameBufferCount > 1 else {
            return
        }

        // Berechne FPS aus Circular Buffer
        let oldestIndex = (frameBufferIndex - frameBufferCount + fpsWindowSize) % fpsWindowSize
        let newestIndex = (frameBufferIndex - 1 + fpsWindowSize) % fpsWindowSize

        let oldestTime = frameTimestampBuffer[oldestIndex]
        let newestTime = frameTimestampBuffer[newestIndex]
        let totalTime = newestTime - oldestTime
        let frameCount = frameBufferCount - 1

        if totalTime > 0 {
            metrics.currentFPS = Float(frameCount) / Float(totalTime)

            // Gleitender Durchschnitt (nutze AudioConstants)
            metrics.averageFPS = metrics.averageFPS * Float(AudioConstants.Smoothing.fps) + metrics.currentFPS * Float(1.0 - AudioConstants.Smoothing.fps)

            // Min/Max
            metrics.minFPS = min(metrics.minFPS, metrics.currentFPS)
            metrics.maxFPS = max(metrics.maxFPS, metrics.currentFPS)
        }

        // Frame Drop Detection (optimiert: nur letzte 2 Frames prüfen)
        if frameBufferCount >= 2 {
            let prevIndex = (frameBufferIndex - 2 + fpsWindowSize) % fpsWindowSize
            let currIndex = (frameBufferIndex - 1 + fpsWindowSize) % fpsWindowSize
            let frameTime = frameTimestampBuffer[currIndex] - frameTimestampBuffer[prevIndex]
            let targetFrameTime = 1.0 / Double(currentQuality.targetFPS)
            if frameTime > targetFrameTime * 1.5 {
                metrics.frameDrops += 1
            }
        }
    }

    private func updateCPUUsage() {
        // Vereinfachte CPU-Auslastungsschätzung
        // In einer echten Implementierung würde man hier die tatsächliche CPU-Auslastung messen
        var usage = BasicHostInfo.cpuUsage()

        // Glätte die Werte
        metrics.cpuUsage = metrics.cpuUsage * 0.8 + usage * 0.2
    }

    private func updateGPUUsage() {
        // GPU-Auslastungsschätzung basierend auf Frame-Zeiten
        let targetFrameTime = 1000.0 / currentQuality.targetFPS
        let actualFrameTime = 1000.0 / Double(metrics.currentFPS)

        let usage = Float(min(actualFrameTime / targetFrameTime, 1.0))
        metrics.gpuUsage = metrics.gpuUsage * 0.8 + usage * 0.2
    }

    private func updateMemoryUsage() {
        let usage = BasicHostInfo.memoryUsage()
        metrics.memoryUsage = metrics.memoryUsage * 0.8 + usage * 0.2
    }

    private func updateThermalState() {
        #if os(iOS)
        let state = ProcessInfo.processInfo.thermalState
        metrics.thermalState = switch state {
        case .nominal: .nominal
        case .fair: .fair
        case .serious: .serious
        case .critical: .critical
        @unknown default: .nominal
        }
        #endif
    }

    // MARK: - Quality Evaluation

    private func evaluateQuality() {
        guard isAdaptiveQualityEnabled else { return }

        // Hysterese: Verhindere zu häufige Änderungen
        let timeSinceLastChange = Date().timeIntervalSince(lastQualityChange)
        if timeSinceLastChange < hysteresisDelay {
            return
        }

        // Berechne ideale Qualitätsstufe basierend auf Metriken
        let idealQuality = calculateIdealQuality()

        if idealQuality != currentQuality {
            transitionToQuality(idealQuality)
        }
    }

    private func calculateIdealQuality() -> QualityLevel {
        var score: Float = 100.0

        // FPS-basierte Bewertung (höchste Priorität)
        if metrics.averageFPS < thresholds.fpsMinimal {
            score -= 40.0
        } else if metrics.averageFPS < thresholds.fpsLow {
            score -= 30.0
        } else if metrics.averageFPS < thresholds.fpsMedium {
            score -= 20.0
        } else if metrics.averageFPS < thresholds.fpsHigh {
            score -= 10.0
        }

        // CPU-Auslastung
        if metrics.cpuUsage > thresholds.cpuCritical {
            score -= 30.0
        } else if metrics.cpuUsage > thresholds.cpuHigh {
            score -= 20.0
        } else if metrics.cpuUsage > thresholds.cpuMedium {
            score -= 10.0
        }

        // GPU-Auslastung
        if metrics.gpuUsage > thresholds.gpuCritical {
            score -= 30.0
        } else if metrics.gpuUsage > thresholds.gpuHigh {
            score -= 20.0
        } else if metrics.gpuUsage > thresholds.gpuMedium {
            score -= 10.0
        }

        // Speicherauslastung
        if metrics.memoryUsage > thresholds.memoryCritical {
            score -= 25.0
        } else if metrics.memoryUsage > thresholds.memoryHigh {
            score -= 15.0
        } else if metrics.memoryUsage > thresholds.memoryMedium {
            score -= 8.0
        }

        // Thermal State
        switch metrics.thermalState {
        case .critical:
            score -= 40.0
        case .serious:
            score -= 25.0
        case .fair:
            score -= 10.0
        case .nominal:
            break
        }

        // Frame Drops
        if metrics.frameDrops > 10 {
            score -= 15.0
        } else if metrics.frameDrops > 5 {
            score -= 8.0
        }

        // Mappe Score auf Qualitätsstufe
        switch score {
        case ..<30.0:
            return .minimal
        case 30.0..<50.0:
            return .low
        case 50.0..<70.0:
            return .medium
        case 70.0..<90.0:
            return .high
        default:
            return .ultra
        }
    }

    // MARK: - Quality Transition

    private func transitionToQuality(_ newQuality: QualityLevel) {
        log.performance("🔄 Transitioning quality: \(currentQuality.rawValue) → \(newQuality.rawValue)")
        log.performance("   FPS: \(String(format: "%.1f", metrics.averageFPS)) | CPU: \(String(format: "%.1f%%", metrics.cpuUsage * 100)) | GPU: \(String(format: "%.1f%%", metrics.gpuUsage * 100))")

        currentQuality = newQuality
        lastQualityChange = Date()

        // Aktualisiere Einstellungen
        updateVisualSettings()
        updateAudioSettings()

        // Reset Metriken
        metrics.frameDrops = 0
        // OPTIMIERT: Reset circular buffer indices statt removeAll()
        frameBufferIndex = 0
        frameBufferCount = 0
    }

    private func updateVisualSettings() {
        visualSettings.particleCount = currentQuality.maxParticles
        visualSettings.textureResolution = currentQuality.textureQuality

        switch currentQuality {
        case .minimal:
            visualSettings.enableBloom = false
            visualSettings.enableMotionBlur = false
            visualSettings.enableAmbientOcclusion = false
            visualSettings.enableShadows = false
            visualSettings.enableReflections = false
            visualSettings.shadowQuality = .off
            visualSettings.antialiasing = .off
            visualSettings.renderScale = 0.5

        case .low:
            visualSettings.enableBloom = false
            visualSettings.enableMotionBlur = false
            visualSettings.enableAmbientOcclusion = false
            visualSettings.enableShadows = true
            visualSettings.enableReflections = false
            visualSettings.shadowQuality = .low
            visualSettings.antialiasing = .fxaa
            visualSettings.renderScale = 0.75

        case .medium:
            visualSettings.enableBloom = true
            visualSettings.enableMotionBlur = false
            visualSettings.enableAmbientOcclusion = false
            visualSettings.enableShadows = true
            visualSettings.enableReflections = false
            visualSettings.shadowQuality = .medium
            visualSettings.antialiasing = .msaa2x
            visualSettings.renderScale = 1.0

        case .high:
            visualSettings.enableBloom = true
            visualSettings.enableMotionBlur = true
            visualSettings.enableAmbientOcclusion = true
            visualSettings.enableShadows = true
            visualSettings.enableReflections = true
            visualSettings.shadowQuality = .high
            visualSettings.antialiasing = .msaa4x
            visualSettings.renderScale = 1.0

        case .ultra:
            visualSettings.enableBloom = true
            visualSettings.enableMotionBlur = true
            visualSettings.enableAmbientOcclusion = true
            visualSettings.enableShadows = true
            visualSettings.enableReflections = true
            visualSettings.shadowQuality = .ultra
            visualSettings.antialiasing = .msaa8x
            visualSettings.renderScale = 1.0
        }
    }

    private func updateAudioSettings() {
        audioSettings.bufferSize = currentQuality.audioBufferSize

        switch currentQuality {
        case .minimal:
            audioSettings.sampleRate = 44100
            audioSettings.maxVoices = 32
            audioSettings.enableReverb = false
            audioSettings.enableConvolution = false
            audioSettings.enableSpatialAudio = false
            audioSettings.dspQuality = .minimal

        case .low:
            audioSettings.sampleRate = 44100
            audioSettings.maxVoices = 64
            audioSettings.enableReverb = true
            audioSettings.enableConvolution = false
            audioSettings.enableSpatialAudio = false
            audioSettings.dspQuality = .low

        case .medium:
            audioSettings.sampleRate = 48000
            audioSettings.maxVoices = 96
            audioSettings.enableReverb = true
            audioSettings.enableConvolution = false
            audioSettings.enableSpatialAudio = true
            audioSettings.dspQuality = .medium

        case .high:
            audioSettings.sampleRate = 48000
            audioSettings.maxVoices = 128
            audioSettings.enableReverb = true
            audioSettings.enableConvolution = true
            audioSettings.enableSpatialAudio = true
            audioSettings.dspQuality = .high

        case .ultra:
            audioSettings.sampleRate = 96000
            audioSettings.maxVoices = 256
            audioSettings.enableReverb = true
            audioSettings.enableConvolution = true
            audioSettings.enableSpatialAudio = true
            audioSettings.dspQuality = .ultra
        }
    }

    // MARK: - Emergency Handlers

    private func handleMemoryWarning() {
        log.performance("⚠️ Memory Warning! Degrading quality immediately.", level: .warning)

        // Sofortige Qualitätsreduzierung
        if currentQuality > .minimal {
            let newQuality = QualityLevel.allCases[max(0, QualityLevel.allCases.firstIndex(of: currentQuality)! - 2)]
            transitionToQuality(newQuality)
        }

        // Zusätzliche Notfall-Maßnahmen
        clearCaches()
    }

    private func clearCaches() {
        // Implementierung würde hier Caches leeren
        log.performance("🧹 Clearing caches to free memory")
    }

    // MARK: - Manual Control

    func setQuality(_ quality: QualityLevel, manual: Bool = false) {
        if manual {
            // Deaktiviere adaptive Qualität bei manueller Einstellung
            isAdaptiveQualityEnabled = false
        }

        transitionToQuality(quality)
    }

    func resetToAutomatic() {
        isAdaptiveQualityEnabled = true
        lastQualityChange = Date().addingTimeInterval(-hysteresisDelay)
        evaluateQuality()
    }

    // MARK: - Statistics

    func getPerformanceReport() -> String {
        var report = "📊 Performance Report\n"
        report += "━━━━━━━━━━━━━━━━━━━━━━\n"
        report += "Quality Level: \(currentQuality.rawValue)\n"
        report += "FPS: \(String(format: "%.1f", metrics.averageFPS)) (min: \(String(format: "%.1f", metrics.minFPS)), max: \(String(format: "%.1f", metrics.maxFPS)))\n"
        report += "CPU Usage: \(String(format: "%.1f%%", metrics.cpuUsage * 100))\n"
        report += "GPU Usage: \(String(format: "%.1f%%", metrics.gpuUsage * 100))\n"
        report += "Memory Usage: \(String(format: "%.1f%%", metrics.memoryUsage * 100))\n"
        report += "Thermal State: \(metrics.thermalState.rawValue)\n"
        report += "Frame Drops: \(metrics.frameDrops)\n"
        report += "Audio Underruns: \(metrics.audioUnderruns)\n"
        report += "━━━━━━━━━━━━━━━━━━━━━━\n"
        report += "Visual Settings:\n"
        report += "  Particles: \(visualSettings.particleCount)\n"
        report += "  Shadows: \(visualSettings.shadowQuality.rawValue)\n"
        report += "  AA: \(visualSettings.antialiasing.rawValue)\n"
        report += "  Render Scale: \(String(format: "%.2f", visualSettings.renderScale))\n"
        report += "Audio Settings:\n"
        report += "  Sample Rate: \(audioSettings.sampleRate) Hz\n"
        report += "  Buffer Size: \(audioSettings.bufferSize) samples\n"
        report += "  Max Voices: \(audioSettings.maxVoices)\n"
        report += "  DSP Quality: \(audioSettings.dspQuality.rawValue)\n"

        return report
    }
}

// MARK: - Basic Host Info Helper

private struct BasicHostInfo {
    static func cpuUsage() -> Float {
        var totalUsageOfCPU: Float = 0.0
        var threadsList = UnsafeMutablePointer<thread_act_t>(nil)
        var threadsCount: mach_msg_type_number_t = 0

        let threadsResult = withUnsafeMutablePointer(to: &threadsList) {
            task_threads(mach_task_self_, $0, &threadsCount)
        }

        guard threadsResult == KERN_SUCCESS,
              let threadsList = threadsList else {
            return 0.0
        }

        defer {
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: threadsList)), vm_size_t(Int(threadsCount) * MemoryLayout<thread_t>.stride))
        }

        for index in 0..<Int(threadsCount) {
            var threadInfo = thread_basic_info()
            var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)

            let result = withUnsafeMutablePointer(to: &threadInfo) {
                $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                    thread_info(threadsList[index], thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
                }
            }

            guard result == KERN_SUCCESS else { continue }

            let threadBasicInfo = threadInfo as thread_basic_info
            if threadBasicInfo.flags & TH_FLAGS_IDLE == 0 {
                totalUsageOfCPU += Float(threadBasicInfo.cpu_usage) / Float(TH_USAGE_SCALE)
            }
        }

        return min(totalUsageOfCPU, 1.0)
    }

    static func memoryUsage() -> Float {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return 0.0 }

        let usedMemory = Float(info.resident_size)
        let totalMemory = Float(ProcessInfo.processInfo.physicalMemory)

        return usedMemory / totalMemory
    }
}
