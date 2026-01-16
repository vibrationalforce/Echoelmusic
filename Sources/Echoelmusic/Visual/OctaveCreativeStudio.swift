// OctaveCreativeStudio.swift
// Echoelmusic - Kreativbaukasten für Oktav-Transposition
//
// Bio → Audio → Licht Mapping nach dem "Excess of Reduction" Prinzip
// Mathematisch: f × 2^n (Oktavierung)
//
// Copyright 2026 Echoelmusic. MIT License.

import SwiftUI
import Combine

// MARK: - Octave Creative Studio Engine

/// Kreativbaukasten für Bio→Audio→Licht Oktav-Transposition
/// Ermöglicht interaktive Anpassung der Frequenz-Mappings
@MainActor
public class OctaveCreativeStudio: ObservableObject {

    // MARK: - Published Parameters

    /// Oktav-Shift für Heart Rate → Audio (Standard: 6)
    @Published public var heartRateOctaves: Int = 6

    /// Oktav-Shift für Breathing → Audio (Standard: 8)
    @Published public var breathingOctaves: Int = 8

    /// Oktav-Shift für HRV → Audio (Standard: 12)
    @Published public var hrvOctaves: Int = 12

    /// Mapping-Kurve für Audio → Licht
    @Published public var mappingCurve: MappingCurve = .logarithmic

    /// Farbtemperatur-Offset (warm/kalt)
    @Published public var colorTemperature: Float = 0.0  // -1 = warm, +1 = kalt

    /// Aktives Preset
    @Published public var activePreset: OctavePreset = .neutral

    /// Live Bio-Daten (für Preview)
    @Published public var liveBioData: LiveBioData = .init()

    /// Berechnete Farbe (Ergebnis der Kette)
    @Published public var resultColor: Color = .white

    /// Berechnete Audio-Frequenz
    @Published public var resultAudioFrequency: Float = 440

    /// Berechnete Licht-Wellenlänge (nm)
    @Published public var resultWavelength: Float = 550

    // MARK: - Mapping Curves

    public enum MappingCurve: String, CaseIterable, Identifiable {
        case linear = "Linear"
        case logarithmic = "Logarithmisch"
        case exponential = "Exponentiell"
        case sCurve = "S-Kurve"
        case sine = "Sinus"
        case stepped = "Gestuft"

        public var id: String { rawValue }

        public var icon: String {
            switch self {
            case .linear: return "line.diagonal"
            case .logarithmic: return "chart.line.uptrend.xyaxis"
            case .exponential: return "arrow.up.right.circle"
            case .sCurve: return "s.circle"
            case .sine: return "waveform"
            case .stepped: return "stairs"
            }
        }

        /// Wendet die Kurve auf einen 0-1 Wert an
        public func apply(_ value: Float) -> Float {
            let clamped = max(0, min(1, value))
            switch self {
            case .linear:
                return clamped
            case .logarithmic:
                return log10(1 + clamped * 9) // 0→0, 1→1, aber schneller am Anfang
            case .exponential:
                return pow(clamped, 2) // Langsamer am Anfang
            case .sCurve:
                // Smooth S-curve (smoothstep)
                return clamped * clamped * (3 - 2 * clamped)
            case .sine:
                return (1 - cos(clamped * .pi)) / 2
            case .stepped:
                return floor(clamped * 8) / 8 // 8 Stufen
            }
        }
    }

    // MARK: - Presets

    public enum OctavePreset: String, CaseIterable, Identifiable {
        case neutral = "Neutral"
        case warm = "Warm"
        case cool = "Kühl"
        case meditative = "Meditativ"
        case energetic = "Energetisch"
        case pulsing = "Pulsierend"
        case cosmic = "Kosmisch"
        case heartSync = "Herz-Sync"

        public var id: String { rawValue }

        public var icon: String {
            switch self {
            case .neutral: return "circle"
            case .warm: return "sun.max.fill"
            case .cool: return "snowflake"
            case .meditative: return "leaf.fill"
            case .energetic: return "bolt.fill"
            case .pulsing: return "heart.fill"
            case .cosmic: return "sparkles"
            case .heartSync: return "heart.circle.fill"
            }
        }

        public var description: String {
            switch self {
            case .neutral: return "Ausgewogenes Mapping ohne Färbung"
            case .warm: return "Betont Rot/Orange, beruhigend"
            case .cool: return "Betont Blau/Violett, fokussierend"
            case .meditative: return "Langsame, sanfte Übergänge"
            case .energetic: return "Schnelle, dynamische Reaktion"
            case .pulsing: return "Rhythmisch zum Herzschlag"
            case .cosmic: return "Weites Spektrum, spacig"
            case .heartSync: return "Farbe folgt Heart Rate direkt"
            }
        }

        public var heartRateOctaves: Int {
            switch self {
            case .neutral, .cool: return 6
            case .warm, .meditative: return 5
            case .energetic, .pulsing: return 7
            case .cosmic: return 8
            case .heartSync: return 6
            }
        }

        public var breathingOctaves: Int {
            switch self {
            case .neutral: return 8
            case .warm, .meditative: return 7
            case .cool, .energetic: return 9
            case .pulsing: return 8
            case .cosmic: return 10
            case .heartSync: return 8
            }
        }

        public var hrvOctaves: Int {
            switch self {
            case .neutral: return 12
            case .warm: return 10
            case .cool: return 14
            case .meditative: return 11
            case .energetic: return 13
            case .pulsing: return 12
            case .cosmic: return 15
            case .heartSync: return 12
            }
        }

        public var mappingCurve: MappingCurve {
            switch self {
            case .neutral, .heartSync: return .logarithmic
            case .warm, .meditative: return .sCurve
            case .cool: return .linear
            case .energetic: return .exponential
            case .pulsing: return .sine
            case .cosmic: return .logarithmic
            }
        }

        public var colorTemperature: Float {
            switch self {
            case .neutral, .pulsing, .heartSync: return 0
            case .warm: return -0.6
            case .cool: return 0.6
            case .meditative: return -0.3
            case .energetic: return 0.2
            case .cosmic: return 0.4
            }
        }
    }

    // MARK: - Live Bio Data

    public struct LiveBioData {
        public var heartRate: Float = 70      // BPM
        public var breathingRate: Float = 12  // Atemzüge/min
        public var hrvFrequency: Float = 0.1  // Hz (0.04-0.4 Hz Band)
        public var coherence: Float = 0.5     // 0-1

        public init() {}

        public init(heartRate: Float, breathingRate: Float, hrvFrequency: Float, coherence: Float) {
            self.heartRate = heartRate
            self.breathingRate = breathingRate
            self.hrvFrequency = hrvFrequency
            self.coherence = coherence
        }
    }

    // MARK: - Constants

    private struct Constants {
        // Audio-Bereich
        static let audioMin: Float = 20       // Hz
        static let audioMax: Float = 20000    // Hz

        // Licht-Bereich (sichtbar)
        static let lightMinTHz: Float = 400   // THz (Rot, 750nm)
        static let lightMaxTHz: Float = 750   // THz (Violett, 400nm)

        // Wellenlängen
        static let redWavelength: Float = 700
        static let violetWavelength: Float = 400
    }

    // MARK: - Initialization

    public init() {
        startBioSimulation()
    }

    // MARK: - Preset Application

    public func applyPreset(_ preset: OctavePreset) {
        withAnimation(.easeInOut(duration: 0.5)) {
            activePreset = preset
            heartRateOctaves = preset.heartRateOctaves
            breathingOctaves = preset.breathingOctaves
            hrvOctaves = preset.hrvOctaves
            mappingCurve = preset.mappingCurve
            colorTemperature = preset.colorTemperature
        }
        updateResult()
    }

    // MARK: - Core Calculations
    // Verwendet UnifiedVisualSoundEngine.OctaveTransposition für Basis-Physik
    // Erweitert um: konfigurierbare Oktaven, Mapping-Kurven, Temperatur-Offset

    /// Bio-Frequenz → Audio-Frequenz (f × 2^n) mit konfigurierbaren Oktaven
    public func bioToAudio(bioFrequency: Float, octaves: Int) -> Float {
        // Basis-Formel identisch zu OctaveTransposition, aber mit variablen Oktaven
        return bioFrequency * pow(2.0, Float(octaves))
    }

    /// Heart Rate (BPM) → Audio-Frequenz mit konfigurierbarem Oktav-Shift
    public func heartRateToAudio() -> Float {
        let heartFrequency = liveBioData.heartRate / 60.0  // BPM → Hz
        return bioToAudio(bioFrequency: heartFrequency, octaves: heartRateOctaves)
    }

    /// Breathing Rate → Audio-Frequenz mit konfigurierbarem Oktav-Shift
    public func breathingToAudio() -> Float {
        let breathFrequency = liveBioData.breathingRate / 60.0  // Atemzüge/min → Hz
        return bioToAudio(bioFrequency: breathFrequency, octaves: breathingOctaves)
    }

    /// HRV → Audio-Frequenz mit konfigurierbarem Oktav-Shift
    public func hrvToAudio() -> Float {
        return bioToAudio(bioFrequency: liveBioData.hrvFrequency, octaves: hrvOctaves)
    }

    /// Audio-Frequenz → Licht-Frequenz (THz) mit Kurve + Temperatur
    public func audioToLight(audioFrequency: Float) -> Float {
        // Position im Audio-Spektrum (0-1)
        let audioOctaves = log2(Constants.audioMax / Constants.audioMin)
        let position = log2(max(audioFrequency, Constants.audioMin) / Constants.audioMin) / audioOctaves
        let clampedPosition = max(0, min(1, position))

        // Mapping-Kurve anwenden (OctaveCreativeStudio-spezifisch)
        let curvedPosition = mappingCurve.apply(clampedPosition)

        // Farbtemperatur-Offset anwenden (OctaveCreativeStudio-spezifisch)
        let temperatureOffset = colorTemperature * 0.2
        let adjustedPosition = max(0, min(1, curvedPosition + temperatureOffset))

        // Auf Licht-Spektrum mappen
        return Constants.lightMinTHz * pow(Constants.lightMaxTHz / Constants.lightMinTHz, adjustedPosition)
    }

    /// Licht-Frequenz (THz) → Wellenlänge (nm)
    /// Delegiert an UnifiedVisualSoundEngine für konsistente Physik
    public func frequencyToWavelength(thz: Float) -> Float {
        return UnifiedVisualSoundEngine.OctaveTransposition.frequencyToWavelength(thz: thz)
    }

    /// Wellenlänge (nm) → RGB
    /// Delegiert an UnifiedVisualSoundEngine für konsistentes CIE 1931 Mapping
    public func wavelengthToRGB(wavelength: Float) -> (r: Float, g: Float, b: Float) {
        return UnifiedVisualSoundEngine.OctaveTransposition.wavelengthToRGB(wavelength: wavelength)
    }

    /// Vollständige Kette: Bio → Audio → Licht → Farbe
    public func calculateResultColor() -> Color {
        // Hauptfrequenz aus Heart Rate (primär)
        let audioFreq = heartRateToAudio()
        let lightFreq = audioToLight(audioFrequency: audioFreq)
        let wavelength = frequencyToWavelength(thz: lightFreq)
        let rgb = wavelengthToRGB(wavelength: wavelength)

        // Coherence beeinflusst Sättigung
        let saturation = 0.5 + liveBioData.coherence * 0.5

        return Color(
            red: Double(rgb.r * saturation),
            green: Double(rgb.g * saturation),
            blue: Double(rgb.b * saturation)
        )
    }

    /// Aktualisiert alle berechneten Werte
    public func updateResult() {
        resultAudioFrequency = heartRateToAudio()
        let lightFreq = audioToLight(audioFrequency: resultAudioFrequency)
        resultWavelength = frequencyToWavelength(thz: lightFreq)
        resultColor = calculateResultColor()
    }

    // MARK: - Bio Simulation

    private var simulationTimer: Timer?
    private var simulationTime: Double = 0

    private func startBioSimulation() {
        simulationTimer = Timer.scheduledTimer(withTimeInterval: 1/30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.simulateBioData()
            }
        }
    }

    private func simulateBioData() {
        simulationTime += 1/30.0

        // Simulierte Bio-Daten mit realistischen Variationen
        let baseHR: Float = 70
        let hrVariation = sin(Float(simulationTime) * 0.5) * 10 + sin(Float(simulationTime) * 0.1) * 5
        liveBioData.heartRate = baseHR + hrVariation

        let baseBreath: Float = 12
        let breathVariation = sin(Float(simulationTime) * 0.2) * 3
        liveBioData.breathingRate = baseBreath + breathVariation

        // HRV oszilliert im 0.1 Hz Bereich (Resonanzfrequenz)
        liveBioData.hrvFrequency = 0.1 + sin(Float(simulationTime) * 0.3) * 0.05

        // Coherence steigt langsam und variiert
        let baseCoherence: Float = 0.5
        let coherenceWave = sin(Float(simulationTime) * 0.15) * 0.3
        liveBioData.coherence = max(0, min(1, baseCoherence + coherenceWave))

        updateResult()
    }

    deinit {
        simulationTimer?.invalidate()
    }
}

// MARK: - SwiftUI View

public struct OctaveCreativeStudioView: View {
    @StateObject private var studio = OctaveCreativeStudio()
    @State private var showingInfo = false

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header mit Live-Farbe
                headerSection

                // Preset-Auswahl
                presetSection

                // Oktav-Slider
                octaveSection

                // Mapping-Kurve
                curveSection

                // Farbtemperatur
                temperatureSection

                // Live-Daten Anzeige
                liveDataSection

                // Info-Bereich
                infoSection
            }
            .padding()
        }
        .navigationTitle("Oktav-Kreativstudio")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 16) {
            // Große Farbvorschau
            ZStack {
                // Hintergrund-Glow
                Circle()
                    .fill(studio.resultColor)
                    .blur(radius: 40)
                    .opacity(0.6)

                // Hauptkreis
                Circle()
                    .fill(studio.resultColor)
                    .frame(width: 150, height: 150)
                    .shadow(color: studio.resultColor.opacity(0.8), radius: 20)

                // Pulsierender Ring
                Circle()
                    .stroke(studio.resultColor, lineWidth: 3)
                    .frame(width: 180, height: 180)
                    .opacity(Double(studio.liveBioData.coherence))
                    .scaleEffect(1.0 + CGFloat(sin(studio.liveBioData.heartRate / 60.0 * .pi * 2) * 0.05))
            }
            .frame(height: 200)
            .animation(.easeInOut(duration: 0.5), value: studio.resultColor)

            // Frequenz-Kette Anzeige
            HStack(spacing: 8) {
                frequencyBadge(
                    label: "HR",
                    value: "\(Int(studio.liveBioData.heartRate)) BPM",
                    sublabel: "\(String(format: "%.1f", studio.liveBioData.heartRate / 60)) Hz"
                )

                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)

                frequencyBadge(
                    label: "Audio",
                    value: "\(Int(studio.resultAudioFrequency)) Hz",
                    sublabel: noteName(for: studio.resultAudioFrequency)
                )

                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)

                frequencyBadge(
                    label: "Licht",
                    value: "\(Int(studio.resultWavelength)) nm",
                    sublabel: colorName(for: studio.resultWavelength)
                )
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private func frequencyBadge(label: String, value: String, sublabel: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
            Text(sublabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 80)
    }

    // MARK: - Presets

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Presets", systemImage: "slider.horizontal.3")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(OctaveCreativeStudio.OctavePreset.allCases) { preset in
                        presetButton(preset)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private func presetButton(_ preset: OctaveCreativeStudio.OctavePreset) -> some View {
        Button {
            studio.applyPreset(preset)
        } label: {
            VStack(spacing: 8) {
                Image(systemName: preset.icon)
                    .font(.title2)
                Text(preset.rawValue)
                    .font(.caption)
            }
            .frame(width: 80, height: 70)
            .background(
                studio.activePreset == preset
                    ? studio.resultColor.opacity(0.3)
                    : Color.secondary.opacity(0.1),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(studio.activePreset == preset ? studio.resultColor : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Octave Sliders

    private var octaveSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Oktav-Transposition (f × 2ⁿ)", systemImage: "arrow.up.arrow.down")
                .font(.headline)

            octaveSlider(
                label: "Heart Rate → Audio",
                value: $studio.heartRateOctaves,
                range: 1...12,
                color: .red,
                description: "HR \(Int(studio.liveBioData.heartRate / 60)) Hz → \(Int(studio.heartRateToAudio())) Hz"
            )

            octaveSlider(
                label: "Breathing → Audio",
                value: $studio.breathingOctaves,
                range: 1...15,
                color: .cyan,
                description: "Atem \(String(format: "%.2f", studio.liveBioData.breathingRate / 60)) Hz → \(Int(studio.breathingToAudio())) Hz"
            )

            octaveSlider(
                label: "HRV → Audio",
                value: $studio.hrvOctaves,
                range: 1...18,
                color: .purple,
                description: "HRV \(String(format: "%.2f", studio.liveBioData.hrvFrequency)) Hz → \(Int(studio.hrvToAudio())) Hz"
            )
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func octaveSlider(
        label: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        color: Color,
        description: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text("+\(value.wrappedValue) Oktaven")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(color)
            }

            Slider(
                value: Binding(
                    get: { Double(value.wrappedValue) },
                    set: { value.wrappedValue = Int($0) }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: 1
            )
            .tint(color)
            .onChange(of: value.wrappedValue) { _, _ in
                studio.updateResult()
            }

            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Curve Selection

    private var curveSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Mapping-Kurve", systemImage: "chart.line.uptrend.xyaxis")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(OctaveCreativeStudio.MappingCurve.allCases) { curve in
                    curveButton(curve)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func curveButton(_ curve: OctaveCreativeStudio.MappingCurve) -> some View {
        Button {
            withAnimation {
                studio.mappingCurve = curve
                studio.updateResult()
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: curve.icon)
                    .font(.title3)
                Text(curve.rawValue)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                studio.mappingCurve == curve
                    ? studio.resultColor.opacity(0.3)
                    : Color.secondary.opacity(0.1),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(studio.mappingCurve == curve ? studio.resultColor : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Temperature

    private var temperatureSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Farbtemperatur", systemImage: "thermometer.medium")
                .font(.headline)

            HStack {
                Image(systemName: "sun.max.fill")
                    .foregroundStyle(.orange)

                Slider(value: $studio.colorTemperature, in: -1...1)
                    .tint(studio.colorTemperature < 0 ? .orange : .cyan)
                    .onChange(of: studio.colorTemperature) { _, _ in
                        studio.updateResult()
                    }

                Image(systemName: "snowflake")
                    .foregroundStyle(.cyan)
            }

            Text(temperatureLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var temperatureLabel: String {
        if studio.colorTemperature < -0.3 {
            return "Warm (Rot/Orange betont)"
        } else if studio.colorTemperature > 0.3 {
            return "Kühl (Blau/Violett betont)"
        } else {
            return "Neutral"
        }
    }

    // MARK: - Live Data

    private var liveDataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Live Bio-Daten (Simulation)", systemImage: "waveform.path.ecg")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                bioDataCard(
                    icon: "heart.fill",
                    label: "Heart Rate",
                    value: "\(Int(studio.liveBioData.heartRate))",
                    unit: "BPM",
                    color: .red
                )

                bioDataCard(
                    icon: "wind",
                    label: "Breathing",
                    value: "\(Int(studio.liveBioData.breathingRate))",
                    unit: "/min",
                    color: .cyan
                )

                bioDataCard(
                    icon: "waveform.path",
                    label: "HRV Freq",
                    value: String(format: "%.2f", studio.liveBioData.hrvFrequency),
                    unit: "Hz",
                    color: .purple
                )

                bioDataCard(
                    icon: "sparkles",
                    label: "Coherence",
                    value: "\(Int(studio.liveBioData.coherence * 100))",
                    unit: "%",
                    color: .green
                )
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func bioDataCard(icon: String, label: String, value: String, unit: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.title3.monospacedDigit().bold())
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Info

    private var infoSection: some View {
        DisclosureGroup("Wie funktioniert's?") {
            VStack(alignment: .leading, spacing: 12) {
                infoRow(
                    icon: "1.circle.fill",
                    title: "Bio → Audio",
                    text: "Biometrische Signale (0.1-3 Hz) werden durch Oktavierung (f × 2ⁿ) in den hörbaren Bereich (20-20.000 Hz) transponiert."
                )

                infoRow(
                    icon: "2.circle.fill",
                    title: "Audio → Licht",
                    text: "Die 10 Oktaven des Hörbereichs werden auf die ~1 Oktave des sichtbaren Lichts (400-750 THz) gemappt."
                )

                infoRow(
                    icon: "3.circle.fill",
                    title: "Licht → Farbe",
                    text: "Die Licht-Wellenlänge (380-780 nm) wird nach CIE 1931 in RGB-Farben umgerechnet."
                )

                Divider()

                Text("Basierend auf dem \"Excess of Reduction\" Prinzip: Mathematisch korrekte Oktav-Transposition für kreatives Mapping - keine pseudowissenschaftlichen Heilversprechen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func infoRow(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(studio.resultColor)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private func noteName(for frequency: Float) -> String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let a4 = 440.0
        let semitones = 12 * log2(Double(frequency) / a4)
        let noteIndex = Int(round(semitones)) + 9 // A4 is index 9
        let octave = (noteIndex / 12) + 4
        let note = noteNames[((noteIndex % 12) + 12) % 12]
        return "\(note)\(octave)"
    }

    private func colorName(for wavelength: Float) -> String {
        switch wavelength {
        case ..<420: return "Violett"
        case 420..<490: return "Blau"
        case 490..<510: return "Cyan"
        case 510..<580: return "Grün"
        case 580..<600: return "Gelb"
        case 600..<645: return "Orange"
        default: return "Rot"
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        OctaveCreativeStudioView()
    }
}
