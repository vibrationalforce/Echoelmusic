//
//  BioPresetManager.swift
//  Echoelmusic
//
//  Erweiterte Preset-Verwaltung mit Auto-Selection, Morphing, und Custom Presets
//

import Foundation
import Combine

@MainActor
@Observable
class BioPresetManager {

    // MARK: - Properties

    private let parameterMapper: BioParameterMapper

    /// Aktuell aktives Preset
    var activePreset: BioParameterMapper.BioPreset?

    /// Custom User Presets
    var customPresets: [CustomPreset] = []

    /// Preset Morphing aktiv
    var isMorphing: Bool = false

    /// Morphing Progress (0.0 - 1.0)
    var morphProgress: Float = 0.0

    /// Auto-Selection aktiviert
    var autoSelectionEnabled: Bool = false

    /// Historie der angewendeten Presets
    private var presetHistory: [(preset: BioParameterMapper.BioPreset, timestamp: Date)] = []

    // MARK: - Initialization

    init(parameterMapper: BioParameterMapper) {
        self.parameterMapper = parameterMapper
        loadCustomPresets()
    }

    // MARK: - Preset Application

    /// Wende Preset sofort an
    func applyPreset(_ preset: BioParameterMapper.BioPreset) {
        parameterMapper.applyPreset(preset)
        activePreset = preset

        // Zur Historie hinzufügen
        presetHistory.append((preset, Date()))

        // Historie auf letzte 50 begrenzen
        if presetHistory.count > 50 {
            presetHistory.removeFirst(presetHistory.count - 50)
        }

        print("✅ Preset applied: \(preset.icon) \(preset.rawValue)")
    }

    /// Morphe sanft von aktuellem zu neuem Preset
    func morphToPreset(_ targetPreset: BioParameterMapper.BioPreset, duration: TimeInterval = 3.0) async {
        guard let currentPreset = activePreset else {
            applyPreset(targetPreset)
            return
        }

        isMorphing = true
        morphProgress = 0.0

        let currentConfig = currentPreset.configuration
        let targetConfig = targetPreset.configuration

        let steps = Int(duration * 30)  // 30 FPS
        let stepDuration = duration / Double(steps)

        for step in 0...steps {
            let t = Float(step) / Float(steps)
            morphProgress = t

            // Interpoliere alle Parameter
            parameterMapper.reverbWet = lerp(
                from: currentConfig.reverbWet,
                to: targetConfig.reverbWet,
                t: smoothstep(t)
            )

            parameterMapper.filterCutoff = lerp(
                from: currentConfig.filterCutoff,
                to: targetConfig.filterCutoff,
                t: smoothstep(t)
            )

            parameterMapper.amplitude = lerp(
                from: currentConfig.amplitude,
                to: targetConfig.amplitude,
                t: smoothstep(t)
            )

            parameterMapper.baseFrequency = lerp(
                from: currentConfig.baseFrequency,
                to: targetConfig.baseFrequency,
                t: smoothstep(t)
            )

            parameterMapper.tempo = lerp(
                from: currentConfig.tempo,
                to: targetConfig.tempo,
                t: smoothstep(t)
            )

            // Interpoliere Harmonic Count (diskret)
            parameterMapper.harmonicCount = Int(lerp(
                from: Float(currentConfig.harmonicCount),
                to: Float(targetConfig.harmonicCount),
                t: t
            ))

            // Interpoliere Spatial Position
            parameterMapper.spatialPosition = (
                x: lerp(from: currentConfig.spatialPosition.x, to: targetConfig.spatialPosition.x, t: smoothstep(t)),
                y: lerp(from: currentConfig.spatialPosition.y, to: targetConfig.spatialPosition.y, t: smoothstep(t)),
                z: lerp(from: currentConfig.spatialPosition.z, to: targetConfig.spatialPosition.z, t: smoothstep(t))
            )

            try? await Task.sleep(for: .milliseconds(Int(stepDuration * 1000)))
        }

        activePreset = targetPreset
        isMorphing = false
        morphProgress = 1.0

        print("✅ Morphing complete: \(currentPreset.icon) → \(targetPreset.icon)")
    }

    // MARK: - Auto-Selection

    /// Automatische Preset-Auswahl basierend auf Bio-Daten
    func autoSelectPreset(
        hrvCoherence: Double,
        heartRate: Double,
        stressLevel: Float
    ) -> BioParameterMapper.BioPreset? {

        guard autoSelectionEnabled else { return nil }

        // Entscheidungslogik basierend auf Bio-Daten

        // Hoher Stress → Relaxation
        if stressLevel > 0.7 {
            return .relaxation
        }

        // Sehr niedrige Kohärenz → Meditation
        if hrvCoherence < 30.0 {
            return .meditation
        }

        // Hohe Kohärenz + moderate HR → Creative Flow
        if hrvCoherence > 70.0 && heartRate > 60.0 && heartRate < 80.0 {
            return .creativeFlow
        }

        // Hohe Kohärenz + niedrige HR → Focus
        if hrvCoherence > 60.0 && heartRate < 70.0 {
            return .focus
        }

        // Hohe HR → Energize
        if heartRate > 90.0 {
            return .energize
        }

        // Default: Focus
        return .focus
    }

    /// Update mit Auto-Selection
    func updateWithAutoSelection(
        hrvCoherence: Double,
        heartRate: Double,
        stressLevel: Float
    ) async {
        guard let suggestedPreset = autoSelectPreset(
            hrvCoherence: hrvCoherence,
            heartRate: heartRate,
            stressLevel: stressLevel
        ) else { return }

        // Nur wechseln wenn unterschiedlich vom aktuellen
        if suggestedPreset != activePreset {
            print("🤖 Auto-selecting preset: \(suggestedPreset.icon) \(suggestedPreset.rawValue)")
            await morphToPreset(suggestedPreset, duration: 5.0)
        }
    }

    // MARK: - Custom Presets

    /// Erstelle Custom Preset aus aktuellen Parametern
    func createCustomPreset(name: String) {
        let config = BioParameterMapper.PresetConfiguration(
            reverbWet: parameterMapper.reverbWet,
            filterCutoff: parameterMapper.filterCutoff,
            amplitude: parameterMapper.amplitude,
            baseFrequency: parameterMapper.baseFrequency,
            tempo: parameterMapper.tempo,
            harmonicCount: parameterMapper.harmonicCount,
            spatialPosition: parameterMapper.spatialPosition,
            colorMood: (r: 0.5, g: 0.5, b: 0.5)  // Default color
        )

        let customPreset = CustomPreset(
            id: UUID(),
            name: name,
            configuration: config,
            createdAt: Date()
        )

        customPresets.append(customPreset)
        saveCustomPresets()

        print("💾 Custom preset saved: \(name)")
    }

    /// Wende Custom Preset an
    func applyCustomPreset(_ preset: CustomPreset) {
        let config = preset.configuration

        parameterMapper.reverbWet = config.reverbWet
        parameterMapper.filterCutoff = config.filterCutoff
        parameterMapper.amplitude = config.amplitude
        parameterMapper.baseFrequency = config.baseFrequency
        parameterMapper.tempo = config.tempo
        parameterMapper.harmonicCount = config.harmonicCount
        parameterMapper.spatialPosition = config.spatialPosition

        activePreset = nil  // Custom preset
        print("✅ Custom preset applied: \(preset.name)")
    }

    /// Lösche Custom Preset
    func deleteCustomPreset(_ preset: CustomPreset) {
        customPresets.removeAll { $0.id == preset.id }
        saveCustomPresets()
    }

    // MARK: - Persistence

    private func saveCustomPresets() {
        // In Production: UserDefaults oder CloudKit
        // Hier vereinfacht
        print("💾 Saved \(customPresets.count) custom presets")
    }

    private func loadCustomPresets() {
        // In Production: Lade von UserDefaults/CloudKit
        customPresets = []
    }

    // MARK: - Analytics

    /// Statistik über verwendete Presets
    func getPresetUsageStats() -> [BioParameterMapper.BioPreset: Int] {
        var stats: [BioParameterMapper.BioPreset: Int] = [:]

        for (preset, _) in presetHistory {
            stats[preset, default: 0] += 1
        }

        return stats
    }

    /// Meist verwendetes Preset
    func getMostUsedPreset() -> BioParameterMapper.BioPreset? {
        let stats = getPresetUsageStats()
        return stats.max { $0.value < $1.value }?.key
    }

    /// Durchschnittliche Zeit pro Preset
    func getAverageTimePerPreset() -> [BioParameterMapper.BioPreset: TimeInterval] {
        var times: [BioParameterMapper.BioPreset: [TimeInterval]] = [:]

        for i in 0..<(presetHistory.count - 1) {
            let current = presetHistory[i]
            let next = presetHistory[i + 1]
            let duration = next.timestamp.timeIntervalSince(current.timestamp)

            times[current.preset, default: []].append(duration)
        }

        var averages: [BioParameterMapper.BioPreset: TimeInterval] = [:]
        for (preset, durations) in times {
            let average = durations.reduce(0, +) / Double(durations.count)
            averages[preset] = average
        }

        return averages
    }

    // MARK: - Utility Functions

    private func lerp(from: Float, to: Float, t: Float) -> Float {
        return from + (to - from) * t
    }

    /// Smoothstep für sanftere Interpolation
    private func smoothstep(_ t: Float) -> Float {
        let x = max(0.0, min(1.0, t))
        return x * x * (3.0 - 2.0 * x)
    }
}

// MARK: - Custom Preset

struct CustomPreset: Identifiable, Codable {
    let id: UUID
    let name: String
    let configuration: BioParameterMapper.PresetConfiguration
    let createdAt: Date

    var icon: String { "🎛️" }
}

// MARK: - PresetConfiguration Codable

extension BioParameterMapper.PresetConfiguration: Codable {
    enum CodingKeys: String, CodingKey {
        case reverbWet, filterCutoff, amplitude, baseFrequency, tempo, harmonicCount
        case spatialX, spatialY, spatialZ
        case colorR, colorG, colorB
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(reverbWet, forKey: .reverbWet)
        try container.encode(filterCutoff, forKey: .filterCutoff)
        try container.encode(amplitude, forKey: .amplitude)
        try container.encode(baseFrequency, forKey: .baseFrequency)
        try container.encode(tempo, forKey: .tempo)
        try container.encode(harmonicCount, forKey: .harmonicCount)
        try container.encode(spatialPosition.x, forKey: .spatialX)
        try container.encode(spatialPosition.y, forKey: .spatialY)
        try container.encode(spatialPosition.z, forKey: .spatialZ)
        try container.encode(colorMood.r, forKey: .colorR)
        try container.encode(colorMood.g, forKey: .colorG)
        try container.encode(colorMood.b, forKey: .colorB)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        reverbWet = try container.decode(Float.self, forKey: .reverbWet)
        filterCutoff = try container.decode(Float.self, forKey: .filterCutoff)
        amplitude = try container.decode(Float.self, forKey: .amplitude)
        baseFrequency = try container.decode(Float.self, forKey: .baseFrequency)
        tempo = try container.decode(Float.self, forKey: .tempo)
        harmonicCount = try container.decode(Int.self, forKey: .harmonicCount)

        let x = try container.decode(Float.self, forKey: .spatialX)
        let y = try container.decode(Float.self, forKey: .spatialY)
        let z = try container.decode(Float.self, forKey: .spatialZ)
        spatialPosition = (x, y, z)

        let r = try container.decode(Float.self, forKey: .colorR)
        let g = try container.decode(Float.self, forKey: .colorG)
        let b = try container.decode(Float.self, forKey: .colorB)
        colorMood = (r, g, b)
    }
}

// MARK: - Preset Recommendations

extension BioPresetManager {

    /// Empfehle Presets basierend auf Tageszeit
    func getTimeBasedRecommendation() -> BioParameterMapper.BioPreset {
        let hour = Calendar.current.component(.hour, from: Date())

        switch hour {
        case 6...9:   // Morgen
            return .energize
        case 10...12: // Vormittag
            return .focus
        case 13...14: // Mittag
            return .relaxation
        case 15...18: // Nachmittag
            return .creativeFlow
        case 19...21: // Abend
            return .meditation
        default:      // Nacht
            return .relaxation
        }
    }

    /// Empfehle Presets basierend auf Aktivität
    func getActivityBasedRecommendation(activity: Activity) -> BioParameterMapper.BioPreset {
        switch activity {
        case .working:
            return .focus
        case .creating:
            return .creativeFlow
        case .exercising:
            return .energize
        case .resting:
            return .relaxation
        case .meditating:
            return .meditation
        }
    }

    enum Activity: String, CaseIterable {
        case working = "Working"
        case creating = "Creating"
        case exercising = "Exercising"
        case resting = "Resting"
        case meditating = "Meditating"

        var icon: String {
            switch self {
            case .working: return "💼"
            case .creating: return "🎨"
            case .exercising: return "🏃"
            case .resting: return "🛋️"
            case .meditating: return "🧘"
            }
        }
    }
}

// MARK: - Preset Scheduling

extension BioPresetManager {

    /// Geplanter Preset-Wechsel
    struct ScheduledPreset: Identifiable {
        let id = UUID()
        let preset: BioParameterMapper.BioPreset
        let scheduledTime: Date
        var isActive: Bool = true
    }

    /// Plane Preset für bestimmte Zeit
    func schedulePreset(_ preset: BioParameterMapper.BioPreset, at time: Date) {
        // In Production: Timer oder Background Task
        print("📅 Scheduled preset \(preset.icon) \(preset.rawValue) for \(time)")
    }

    /// Erstelle tägliche Routine
    func createDailyRoutine() -> [ScheduledPreset] {
        let calendar = Calendar.current
        var routine: [ScheduledPreset] = []

        // Morgen - Energize
        if let morning = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) {
            routine.append(ScheduledPreset(preset: .energize, scheduledTime: morning))
        }

        // Vormittag - Focus
        if let midMorning = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: Date()) {
            routine.append(ScheduledPreset(preset: .focus, scheduledTime: midMorning))
        }

        // Mittag - Relaxation
        if let noon = calendar.date(bySettingHour: 13, minute: 0, second: 0, of: Date()) {
            routine.append(ScheduledPreset(preset: .relaxation, scheduledTime: noon))
        }

        // Nachmittag - Creative Flow
        if let afternoon = calendar.date(bySettingHour: 15, minute: 0, second: 0, of: Date()) {
            routine.append(ScheduledPreset(preset: .creativeFlow, scheduledTime: afternoon))
        }

        // Abend - Meditation
        if let evening = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) {
            routine.append(ScheduledPreset(preset: .meditation, scheduledTime: evening))
        }

        return routine
    }
}
