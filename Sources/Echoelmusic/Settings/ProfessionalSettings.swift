import Foundation
import SwiftUI

/// Professional Settings - All Precision Controls
/// **Complete control over timing, tuning, and bio-reactive features**
///
/// **Settings Categories**:
/// - **Video Editing Grid**: Heartbeat-based vs Straight fixed grid
/// - **Chamber Tone**: A440 Hz standard or custom tuning
/// - **Pitch Shifting**: Semitone precision with decimal places
/// - **Tuning Precision**: 0.01 Hz precision for professional tuning
/// - **Bio-Reactive Modes**: Enable/disable heartbeat sync
/// - **MIDI Mapping**: MPE, pitch bend range, velocity curves
@MainActor
class ProfessionalSettingsManager: ObservableObject {

    // MARK: - Published Settings

    // VIDEO EDITING GRID
    @Published var videoGridMode: VideoGridMode = .heartbeatSync {
        didSet { saveSettings() }
    }
    @Published var heartbeatGridDivision: HeartbeatGridDivision = .everyBeat {
        didSet { saveSettings() }
    }
    @Published var fixedGridDivision: FixedGridDivision = .quarterNote {
        didSet { saveSettings() }
    }
    @Published var gridSnapEnabled: Bool = true {
        didSet { saveSettings() }
    }
    @Published var gridTolerance: Float = 50.0 {  // milliseconds
        didSet { saveSettings() }
    }

    // CHAMBER TONE / TUNING
    @Published var chamberToneFrequency: Double = 440.0 {  // Hz (A4)
        didSet { saveSettings() }
    }
    @Published var tuningPrecision: Int = 2 {  // Decimal places (0.01 Hz)
        didSet { saveSettings() }
    }
    @Published var tuningPreset: TuningPreset = .standard440 {
        didSet {
            chamberToneFrequency = tuningPreset.frequency
            saveSettings()
        }
    }
    @Published var microtonalEnabled: Bool = false {
        didSet { saveSettings() }
    }

    // PITCH SHIFTING
    @Published var pitchShiftSemitones: Double = 0.0 {  // -12 to +12
        didSet { saveSettings() }
    }
    @Published var pitchShiftCents: Int = 0 {  // -100 to +100
        didSet { saveSettings() }
    }
    @Published var pitchShiftPrecision: Int = 2 {  // Decimal places
        didSet { saveSettings() }
    }
    @Published var formantPreservation: Bool = true {  // Preserve vocal formants
        didSet { saveSettings() }
    }

    // BIO-REACTIVE SETTINGS
    @Published var heartbeatSyncEnabled: Bool = true {
        didSet { saveSettings() }
    }
    @Published var hrvBasedTiming: Bool = true {
        didSet { saveSettings() }
    }
    @Published var breathSyncEnabled: Bool = false {
        didSet { saveSettings() }
    }
    @Published var emotionBasedEffects: Bool = true {
        didSet { saveSettings() }
    }

    // MIDI SETTINGS
    @Published var mpeEnabled: Bool = true {
        didSet { saveSettings() }
    }
    @Published var pitchBendRange: Int = 48 {  // Semitones (±48 = ±4 octaves)
        didSet { saveSettings() }
    }
    @Published var velocityCurve: VelocityCurve = .linear {
        didSet { saveSettings() }
    }

    // TIMELINE PRECISION
    @Published var timelinePrecision: TimelinePrecision = .milliseconds {
        didSet { saveSettings() }
    }
    @Published var sampleAccurateTiming: Bool = true {
        didSet { saveSettings() }
    }

    // MARK: - UserDefaults Keys

    private let defaults = UserDefaults.standard
    private let settingsKey = "professionalSettings"

    // MARK: - Initialization

    init() {
        loadSettings()
        print("⚙️ Professional Settings initialized")
        print("   Video Grid: \(videoGridMode)")
        print("   Chamber Tone: \(chamberToneFrequency) Hz")
        print("   Pitch Shift: \(pitchShiftSemitones) semitones, \(pitchShiftCents) cents")
        print("   Heartbeat Sync: \(heartbeatSyncEnabled ? "ON" : "OFF")")
    }

    // MARK: - Grid Calculations

    func calculateGridInterval(bpm: Double?, heartRate: Double?) -> TimeInterval {
        switch videoGridMode {
        case .heartbeatSync:
            guard let hr = heartRate, hr > 0 else {
                return 0.5  // Fallback: 120 BPM
            }
            let beatInterval = 60.0 / hr
            return beatInterval * heartbeatGridDivision.multiplier

        case .straight:
            let baseBPM = bpm ?? 120.0
            let beatInterval = 60.0 / baseBPM
            return beatInterval * fixedGridDivision.multiplier

        case .adaptive:
            // Blend heartbeat and fixed based on HRV coherence
            guard let hr = heartRate, let tempo = bpm else {
                return 0.5
            }
            let hrInterval = 60.0 / hr
            let tempoInterval = 60.0 / tempo
            return (hrInterval + tempoInterval) / 2.0
        }
    }

    func getGridLines(duration: TimeInterval, bpm: Double?, heartRate: Double?) -> [TimeInterval] {
        let interval = calculateGridInterval(bpm: bpm, heartRate: heartRate)
        var lines: [TimeInterval] = []
        var time: TimeInterval = 0

        while time <= duration {
            lines.append(time)
            time += interval
        }

        return lines
    }

    func snapToGrid(time: TimeInterval, bpm: Double?, heartRate: Double?) -> TimeInterval {
        guard gridSnapEnabled else { return time }

        let interval = calculateGridInterval(bpm: bpm, heartRate: heartRate)
        let nearestGridLine = round(time / interval) * interval

        // Check tolerance
        if abs(time - nearestGridLine) * 1000 <= Double(gridTolerance) {
            return nearestGridLine
        }

        return time
    }

    // MARK: - Tuning Calculations

    func frequencyToNote(frequency: Double) -> (note: String, octave: Int, cents: Double) {
        // Calculate MIDI note from frequency with chamber tone offset
        let referenceFreq = chamberToneFrequency  // A4 reference
        let semitones = 12.0 * log2(frequency / referenceFreq)
        let midiNote = 69 + semitones  // A4 = MIDI 69

        let noteIndex = Int(round(midiNote)) % 12
        let octave = Int(round(midiNote)) / 12 - 1
        let cents = (midiNote - round(midiNote)) * 100.0

        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let noteName = noteNames[noteIndex]

        return (noteName, octave, cents)
    }

    func noteToFrequency(note: String, octave: Int, cents: Double = 0.0) -> Double {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        guard let noteIndex = noteNames.firstIndex(of: note.uppercased()) else {
            return chamberToneFrequency
        }

        let midiNote = Double((octave + 1) * 12 + noteIndex)
        let semitones = midiNote - 69.0 + (cents / 100.0)  // A4 = MIDI 69
        let frequency = chamberToneFrequency * pow(2.0, semitones / 12.0)

        return frequency
    }

    func formatFrequency(_ frequency: Double) -> String {
        String(format: "%.\(tuningPrecision)f Hz", frequency)
    }

    func formatPitchShift() -> String {
        let totalCents = Int(pitchShiftSemitones * 100.0) + pitchShiftCents
        if totalCents == 0 {
            return "±0 cents"
        } else if totalCents > 0 {
            return "+\(totalCents) cents"
        } else {
            return "\(totalCents) cents"
        }
    }

    // MARK: - Persistence

    private func saveSettings() {
        let settings: [String: Any] = [
            "videoGridMode": videoGridMode.rawValue,
            "heartbeatGridDivision": heartbeatGridDivision.rawValue,
            "fixedGridDivision": fixedGridDivision.rawValue,
            "gridSnapEnabled": gridSnapEnabled,
            "gridTolerance": gridTolerance,
            "chamberToneFrequency": chamberToneFrequency,
            "tuningPrecision": tuningPrecision,
            "tuningPreset": tuningPreset.rawValue,
            "microtonalEnabled": microtonalEnabled,
            "pitchShiftSemitones": pitchShiftSemitones,
            "pitchShiftCents": pitchShiftCents,
            "pitchShiftPrecision": pitchShiftPrecision,
            "formantPreservation": formantPreservation,
            "heartbeatSyncEnabled": heartbeatSyncEnabled,
            "hrvBasedTiming": hrvBasedTiming,
            "breathSyncEnabled": breathSyncEnabled,
            "emotionBasedEffects": emotionBasedEffects,
            "mpeEnabled": mpeEnabled,
            "pitchBendRange": pitchBendRange,
            "velocityCurve": velocityCurve.rawValue,
            "timelinePrecision": timelinePrecision.rawValue,
            "sampleAccurateTiming": sampleAccurateTiming
        ]

        defaults.set(settings, forKey: settingsKey)
    }

    private func loadSettings() {
        guard let settings = defaults.dictionary(forKey: settingsKey) else { return }

        if let mode = settings["videoGridMode"] as? String,
           let gridMode = VideoGridMode(rawValue: mode) {
            videoGridMode = gridMode
        }

        if let division = settings["heartbeatGridDivision"] as? String,
           let hbDivision = HeartbeatGridDivision(rawValue: division) {
            heartbeatGridDivision = hbDivision
        }

        if let division = settings["fixedGridDivision"] as? String,
           let fxDivision = FixedGridDivision(rawValue: division) {
            fixedGridDivision = fxDivision
        }

        gridSnapEnabled = settings["gridSnapEnabled"] as? Bool ?? true
        gridTolerance = settings["gridTolerance"] as? Float ?? 50.0
        chamberToneFrequency = settings["chamberToneFrequency"] as? Double ?? 440.0
        tuningPrecision = settings["tuningPrecision"] as? Int ?? 2
        microtonalEnabled = settings["microtonalEnabled"] as? Bool ?? false
        pitchShiftSemitones = settings["pitchShiftSemitones"] as? Double ?? 0.0
        pitchShiftCents = settings["pitchShiftCents"] as? Int ?? 0
        pitchShiftPrecision = settings["pitchShiftPrecision"] as? Int ?? 2
        formantPreservation = settings["formantPreservation"] as? Bool ?? true
        heartbeatSyncEnabled = settings["heartbeatSyncEnabled"] as? Bool ?? true
        hrvBasedTiming = settings["hrvBasedTiming"] as? Bool ?? true
        breathSyncEnabled = settings["breathSyncEnabled"] as? Bool ?? false
        emotionBasedEffects = settings["emotionBasedEffects"] as? Bool ?? true
        mpeEnabled = settings["mpeEnabled"] as? Bool ?? true
        pitchBendRange = settings["pitchBendRange"] as? Int ?? 48
        sampleAccurateTiming = settings["sampleAccurateTiming"] as? Bool ?? true

        if let preset = settings["tuningPreset"] as? String,
           let tuning = TuningPreset(rawValue: preset) {
            tuningPreset = tuning
        }

        if let curve = settings["velocityCurve"] as? String,
           let velCurve = VelocityCurve(rawValue: curve) {
            velocityCurve = velCurve
        }

        if let precision = settings["timelinePrecision"] as? String,
           let tlPrecision = TimelinePrecision(rawValue: precision) {
            timelinePrecision = tlPrecision
        }
    }

    func resetToDefaults() {
        videoGridMode = .heartbeatSync
        heartbeatGridDivision = .everyBeat
        fixedGridDivision = .quarterNote
        gridSnapEnabled = true
        gridTolerance = 50.0
        chamberToneFrequency = 440.0
        tuningPrecision = 2
        tuningPreset = .standard440
        microtonalEnabled = false
        pitchShiftSemitones = 0.0
        pitchShiftCents = 0
        pitchShiftPrecision = 2
        formantPreservation = true
        heartbeatSyncEnabled = true
        hrvBasedTiming = true
        breathSyncEnabled = false
        emotionBasedEffects = true
        mpeEnabled = true
        pitchBendRange = 48
        velocityCurve = .linear
        timelinePrecision = .milliseconds
        sampleAccurateTiming = true

        print("🔄 Settings reset to defaults")
    }
}

// MARK: - Enums

enum VideoGridMode: String, CaseIterable {
    case heartbeatSync = "Heartbeat Sync"  // Variable grid following heartbeat
    case straight = "Straight Grid"  // Fixed musical grid
    case adaptive = "Adaptive"  // Blend of both based on HRV

    var description: String {
        switch self {
        case .heartbeatSync:
            return "Grid follows your heartbeat rhythm - Natural, bio-reactive timing"
        case .straight:
            return "Traditional fixed musical grid - Precise, quantized timing"
        case .adaptive:
            return "Intelligent blend of heartbeat and musical grid - Best of both"
        }
    }

    var icon: String {
        switch self {
        case .heartbeatSync: return "heart.fill"
        case .straight: return "grid"
        case .adaptive: return "brain.head.profile"
        }
    }
}

enum HeartbeatGridDivision: String, CaseIterable {
    case everyBeat = "Every Beat"  // 1:1
    case halfBeat = "Half Beat"  // 2:1
    case quarterBeat = "Quarter Beat"  // 4:1
    case doubleBeat = "Double Beat"  // 1:2

    var multiplier: Double {
        switch self {
        case .everyBeat: return 1.0
        case .halfBeat: return 0.5
        case .quarterBeat: return 0.25
        case .doubleBeat: return 2.0
        }
    }
}

enum FixedGridDivision: String, CaseIterable {
    case whole = "Whole Note"
    case half = "Half Note"
    case quarterNote = "Quarter Note"
    case eighth = "Eighth Note"
    case sixteenth = "Sixteenth Note"
    case triplet = "Triplet"

    var multiplier: Double {
        switch self {
        case .whole: return 4.0
        case .half: return 2.0
        case .quarterNote: return 1.0
        case .eighth: return 0.5
        case .sixteenth: return 0.25
        case .triplet: return 2.0 / 3.0
        }
    }
}

enum TuningPreset: String, CaseIterable {
    case standard440 = "Standard A440 Hz"
    case baroque415 = "Baroque A415 Hz"
    case scientific432 = "Scientific A432 Hz"
    case verdi432 = "Verdi A432 Hz"
    case classical430 = "Classical A430 Hz"
    case modern442 = "Modern A442 Hz"
    case orchestral443 = "Orchestral A443 Hz"
    case berlin443 = "Berlin Philharmonic A443 Hz"
    case custom = "Custom"

    var frequency: Double {
        switch self {
        case .standard440: return 440.0
        case .baroque415: return 415.3
        case .scientific432: return 432.0
        case .verdi432: return 432.0
        case .classical430: return 430.5
        case .modern442: return 442.0
        case .orchestral443: return 443.0
        case .berlin443: return 443.0
        case .custom: return 440.0
        }
    }

    var description: String {
        switch self {
        case .standard440:
            return "International standard (ISO 16) - Modern orchestral pitch"
        case .baroque415:
            return "Baroque period tuning - Half semitone below modern pitch"
        case .scientific432:
            return "Verdi's 'A' - Mathematical harmonic, 8 Hz base"
        case .verdi432:
            return "Giuseppe Verdi's preferred tuning"
        case .classical430:
            return "Classical period tuning - Mozart, Haydn era"
        case .modern442:
            return "Higher modern pitch - Some European orchestras"
        case .orchestral443:
            return "Common orchestral tuning - Brighter sound"
        case .berlin443:
            return "Berlin Philharmonic standard"
        case .custom:
            return "Custom frequency - Full precision control"
        }
    }
}

enum VelocityCurve: String, CaseIterable {
    case linear = "Linear"
    case logarithmic = "Logarithmic"
    case exponential = "Exponential"
    case sCurve = "S-Curve"

    func apply(_ velocity: Int) -> Int {
        let normalized = Float(velocity) / 127.0

        let result: Float
        switch self {
        case .linear:
            result = normalized

        case .logarithmic:
            result = log10(normalized * 9.0 + 1.0)  // 0-1 range

        case .exponential:
            result = pow(normalized, 2.0)

        case .sCurve:
            // Sigmoid curve
            result = 1.0 / (1.0 + exp(-10.0 * (normalized - 0.5)))
        }

        return Int(result * 127.0)
    }
}

enum TimelinePrecision: String, CaseIterable {
    case samples = "Samples"  // Sample-accurate
    case milliseconds = "Milliseconds"
    case musical = "Musical (Beats)"

    var description: String {
        switch self {
        case .samples: return "Sample-accurate (48kHz = 0.02ms per sample)"
        case .milliseconds: return "Millisecond precision"
        case .musical: return "Musical beats/bars"
        }
    }
}
