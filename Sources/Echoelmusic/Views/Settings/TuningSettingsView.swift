//
//  TuningSettingsView.swift
//  Echoelmusic
//
//  Created: 2025-11-27
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  TUNING & PITCH SETTINGS VIEW
//
//  Vollständige Kontrolle über:
//  - Kammerton (Concert Pitch): 440 Hz, 432 Hz, Custom
//  - Stimmungssystem: Equal Temperament, Pythagorean, Just Intonation, etc.
//  - Tonart (Key): C, D, E, F, G, A, B mit #/b
//  - Master Tuning: Fine-tuning in Cents
//  - Projekt-spezifische Einstellungen
//

import SwiftUI
import Combine

// MARK: - Tuning Settings View

struct TuningSettingsView: View {
    @StateObject private var tuningSystem = MusicalTuningSystem.shared
    @StateObject private var settings = TuningSettings.shared

    @State private var showCustomPitchSheet = false
    @State private var showTuningComparison = false
    @State private var selectedTab: TuningTab = .pitch

    enum TuningTab: String, CaseIterable {
        case pitch = "Kammerton"
        case system = "Stimmung"
        case key = "Tonart"
        case advanced = "Erweitert"
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Picker
                Picker("Tab", selection: $selectedTab) {
                    ForEach(TuningTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        switch selectedTab {
                        case .pitch:
                            concertPitchSection
                        case .system:
                            tuningSystemSection
                        case .key:
                            keySection
                        case .advanced:
                            advancedSection
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Stimmung & Tonhöhe")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Vergleichstabelle") {
                            showTuningComparison = true
                        }
                        Button("Auf Standard zurücksetzen") {
                            resetToDefaults()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showCustomPitchSheet) {
                CustomPitchSheet(settings: settings)
            }
            .sheet(isPresented: $showTuningComparison) {
                TuningComparisonView()
            }
        }
    }

    // MARK: - Concert Pitch Section

    private var concertPitchSection: some View {
        VStack(spacing: 20) {
            // Current Pitch Display
            GroupBox {
                VStack(spacing: 16) {
                    Text("Aktueller Kammerton")
                        .font(.headline)

                    Text("A4 = \(String(format: "%.2f", settings.concertPitch)) Hz")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.accentColor)

                    if settings.masterTuneCents != 0 {
                        Text("Master Tune: \(settings.masterTuneCents > 0 ? "+" : "")\(String(format: "%.1f", settings.masterTuneCents)) Cent")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
            }

            // Preset Buttons
            GroupBox("Voreinstellungen") {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(MusicalTuningSystem.ConcertPitchPreset.allCases.filter { $0 != .custom }, id: \.self) { preset in
                        Button {
                            withAnimation {
                                settings.applyPreset(preset)
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Text("\(String(format: "%.1f", preset.frequency)) Hz")
                                    .font(.headline)
                                Text(presetName(preset))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(settings.selectedPreset == preset
                                        ? Color.accentColor.opacity(0.2)
                                        : Color.gray.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(settings.selectedPreset == preset
                                        ? Color.accentColor
                                        : Color.clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // Custom Button
                    Button {
                        showCustomPitchSheet = true
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.title2)
                            Text("Benutzerdefiniert")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(settings.selectedPreset == .custom
                                    ? Color.accentColor.opacity(0.2)
                                    : Color.gray.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding()
            }

            // History Note
            if let preset = settings.selectedPreset, preset != .custom {
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Historischer Kontext", systemImage: "book")
                            .font(.headline)
                        Text(preset.history)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
            }
        }
    }

    // MARK: - Tuning System Section

    private var tuningSystemSection: some View {
        VStack(spacing: 20) {
            // Current System
            GroupBox {
                VStack(spacing: 12) {
                    Text("Stimmungssystem")
                        .font(.headline)

                    Text(tuningSystem.currentTuning.rawValue)
                        .font(.title2.bold())
                        .foregroundColor(.accentColor)

                    Text(tuningSystem.currentTuning.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }

            // System Selection
            GroupBox("Stimmungssystem wählen") {
                VStack(spacing: 8) {
                    ForEach(MusicalTuningSystem.TuningSystem.allCases, id: \.self) { system in
                        Button {
                            withAnimation {
                                tuningSystem.applyTuning(system)
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(system.rawValue)
                                        .font(.subheadline.bold())
                                    Text(shortDescription(system))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if tuningSystem.currentTuning == system {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(tuningSystem.currentTuning == system
                                        ? Color.accentColor.opacity(0.1)
                                        : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)

                        if system != MusicalTuningSystem.TuningSystem.allCases.last {
                            Divider()
                        }
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Key Section

    private var keySection: some View {
        VStack(spacing: 20) {
            // Current Key
            GroupBox {
                VStack(spacing: 12) {
                    Text("Tonart")
                        .font(.headline)

                    HStack(spacing: 4) {
                        Text(settings.rootNote.name)
                            .font(.system(size: 64, weight: .bold, design: .rounded))

                        Text(settings.scaleMode.rawValue)
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .foregroundColor(.accentColor)

                    Text(settings.keyDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }

            // Root Note Selection
            GroupBox("Grundton") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                    ForEach(TuningSettings.RootNote.allCases, id: \.self) { note in
                        Button {
                            withAnimation {
                                settings.rootNote = note
                            }
                        } label: {
                            Text(note.name)
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(settings.rootNote == note
                                            ? Color.accentColor
                                            : Color.gray.opacity(0.2))
                                )
                                .foregroundColor(settings.rootNote == note ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }

            // Scale Mode Selection
            GroupBox("Skala / Modus") {
                VStack(spacing: 8) {
                    ForEach(TuningSettings.ScaleMode.allCases, id: \.self) { mode in
                        Button {
                            withAnimation {
                                settings.scaleMode = mode
                            }
                        } label: {
                            HStack {
                                Text(mode.rawValue)
                                    .font(.subheadline)
                                Spacer()
                                if settings.scaleMode == mode {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(settings.scaleMode == mode
                                        ? Color.accentColor.opacity(0.1)
                                        : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Advanced Section

    private var advancedSection: some View {
        VStack(spacing: 20) {
            // Master Tune
            GroupBox("Master Tune (Feinabstimmung)") {
                VStack(spacing: 16) {
                    Text("\(settings.masterTuneCents > 0 ? "+" : "")\(String(format: "%.1f", settings.masterTuneCents)) Cent")
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(settings.masterTuneCents == 0 ? .primary : .accentColor)

                    Slider(value: $settings.masterTuneCents, in: -100...100, step: 0.1)
                        .accentColor(.accentColor)

                    HStack {
                        Button("-1") { settings.masterTuneCents -= 1 }
                        Button("-0.1") { settings.masterTuneCents -= 0.1 }
                        Spacer()
                        Button("0") { settings.masterTuneCents = 0 }
                            .foregroundColor(.red)
                        Spacer()
                        Button("+0.1") { settings.masterTuneCents += 0.1 }
                        Button("+1") { settings.masterTuneCents += 1 }
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)

                    Text("1 Cent = 1/100 Halbton")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding()
            }

            // Transpose
            GroupBox("Transponierung") {
                VStack(spacing: 16) {
                    Text("\(settings.transpose > 0 ? "+" : "")\(settings.transpose) Halbtöne")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))

                    Stepper("", value: $settings.transpose, in: -24...24)
                        .labelsHidden()

                    HStack {
                        ForEach([-12, -7, -5, 0, 5, 7, 12], id: \.self) { semitones in
                            Button(semitones > 0 ? "+\(semitones)" : "\(semitones)") {
                                settings.transpose = semitones
                            }
                            .buttonStyle(.bordered)
                            .tint(settings.transpose == semitones ? .accentColor : nil)
                        }
                    }
                    .font(.caption)
                }
                .padding()
            }

            // Reference Frequency Info
            GroupBox("Berechnete Frequenzen") {
                VStack(alignment: .leading, spacing: 8) {
                    frequencyRow("A4", frequency: settings.effectivePitch)
                    frequencyRow("C4 (Middle C)", frequency: settings.effectivePitch * pow(2, -9.0/12.0))
                    frequencyRow("A3", frequency: settings.effectivePitch / 2)
                    frequencyRow("A5", frequency: settings.effectivePitch * 2)

                    Divider()

                    Text("Effektiver Kammerton: \(String(format: "%.4f", settings.effectivePitch)) Hz")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }

            // Apply to Project Toggle
            GroupBox("Projekt-Einstellungen") {
                VStack(spacing: 12) {
                    Toggle("Auf aktuelles Projekt anwenden", isOn: $settings.applyToCurrentProject)

                    Toggle("Als Standard für neue Projekte speichern", isOn: $settings.saveAsDefault)

                    if settings.applyToCurrentProject {
                        Text("Alle MIDI- und Audio-Ausgaben werden entsprechend angepasst")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Helpers

    private func frequencyRow(_ note: String, frequency: Double) -> some View {
        HStack {
            Text(note)
                .font(.subheadline.bold())
            Spacer()
            Text("\(String(format: "%.2f", frequency)) Hz")
                .font(.subheadline.monospaced())
                .foregroundColor(.secondary)
        }
    }

    private func presetName(_ preset: MusicalTuningSystem.ConcertPitchPreset) -> String {
        switch preset {
        case .modern440: return "Modern"
        case .baroque415: return "Barock"
        case .classical430: return "Klassik"
        case .verdi432: return "Verdi"
        case .scientific256C: return "Scientific"
        case .custom: return "Custom"
        }
    }

    private func shortDescription(_ system: MusicalTuningSystem.TuningSystem) -> String {
        switch system {
        case .equalTemperament: return "Alle Halbtöne gleich"
        case .pythagorean: return "Reine Quinten"
        case .justIntonationMajor: return "Reine Dur-Intervalle"
        case .justIntonationMinor: return "Reine Moll-Intervalle"
        case .concert432: return "432 Hz Basis"
        case .scientific256C: return "C = 256 Hz"
        case .goldenRatio: return "φ-basierte Intervalle"
        case .meantoneQuarter: return "Reine Terzen"
        case .wellTempered: return "Alle Tonarten spielbar"
        case .kirnberger: return "Kompromiss-Stimmung"
        case .custom: return "Benutzerdefiniert"
        }
    }

    private func resetToDefaults() {
        settings.concertPitch = 440.0
        settings.masterTuneCents = 0
        settings.transpose = 0
        settings.rootNote = .c
        settings.scaleMode = .major
        tuningSystem.applyTuning(.equalTemperament)
    }
}

// MARK: - Custom Pitch Sheet

struct CustomPitchSheet: View {
    @ObservedObject var settings: TuningSettings
    @Environment(\.dismiss) private var dismiss

    @State private var customPitch: Double = 440.0

    var body: some View {
        NavigationView {
            Form {
                Section("Benutzerdefinierter Kammerton") {
                    HStack {
                        Text("A4 =")
                        TextField("Hz", value: $customPitch, format: .number)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                        Text("Hz")
                    }

                    Slider(value: $customPitch, in: 400...480, step: 0.01)

                    Text("Bereich: 400 - 480 Hz")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Schnellauswahl") {
                    Button("430 Hz (Klassik)") { customPitch = 430.0 }
                    Button("432 Hz (Verdi)") { customPitch = 432.0 }
                    Button("435 Hz (Französisch 1858)") { customPitch = 435.0 }
                    Button("440 Hz (ISO Standard)") { customPitch = 440.0 }
                    Button("442 Hz (Europäische Orchester)") { customPitch = 442.0 }
                    Button("444 Hz (Hoch)") { customPitch = 444.0 }
                }
            }
            .navigationTitle("Kammerton")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Übernehmen") {
                        settings.concertPitch = customPitch
                        settings.selectedPreset = .custom
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            customPitch = settings.concertPitch
        }
    }
}

// MARK: - Tuning Comparison View

struct TuningComparisonView: View {
    @StateObject private var tuningSystem = MusicalTuningSystem.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section("Frequenzvergleich für A4") {
                    ForEach(MusicalTuningSystem.TuningSystem.allCases, id: \.self) { system in
                        HStack {
                            Text(system.rawValue)
                                .font(.caption)
                            Spacer()
                            Text("\(String(format: "%.2f", system.defaultConcertPitch)) Hz")
                                .font(.caption.monospaced())
                        }
                    }
                }

                Section("Intervall-Verhältnisse (C-Dur)") {
                    let notes = ["C", "D", "E", "F", "G", "A", "B"]
                    let ratios = tuningSystem.getRatios(for: tuningSystem.currentTuning)

                    ForEach(Array(notes.enumerated()), id: \.offset) { index, note in
                        if index < ratios.count {
                            HStack {
                                Text(note)
                                    .font(.headline)
                                    .frame(width: 30)
                                Spacer()
                                Text(String(format: "%.4f", ratios[[0, 2, 4, 5, 7, 9, 11][index]]))
                                    .font(.caption.monospaced())
                            }
                        }
                    }
                }
            }
            .navigationTitle("Stimmungsvergleich")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Tuning Settings Model (Global)

@MainActor
class TuningSettings: ObservableObject {
    static let shared = TuningSettings()

    // Concert Pitch
    @Published var concertPitch: Double = 440.0 {
        didSet {
            MusicalTuningSystem.shared.concertPitch = concertPitch
        }
    }

    @Published var selectedPreset: MusicalTuningSystem.ConcertPitchPreset = .modern440

    // Master Tune (in cents)
    @Published var masterTuneCents: Double = 0 {
        didSet {
            MusicalTuningSystem.shared.masterTune = masterTuneCents
        }
    }

    // Transpose (in semitones)
    @Published var transpose: Int = 0

    // Key
    @Published var rootNote: RootNote = .c
    @Published var scaleMode: ScaleMode = .major

    // Project Settings
    @Published var applyToCurrentProject: Bool = true
    @Published var saveAsDefault: Bool = false

    // Track-specific tuning storage
    @Published var trackTunings: [UUID: TrackTuningSettings] = [:]

    // Computed
    var effectivePitch: Double {
        concertPitch * pow(2.0, masterTuneCents / 1200.0)
    }

    var keyDescription: String {
        "\(rootNote.name) \(scaleMode.rawValue)"
    }

    // Root Notes
    enum RootNote: String, CaseIterable {
        case c = "C"
        case cSharp = "C#"
        case d = "D"
        case dSharp = "D#"
        case e = "E"
        case f = "F"
        case fSharp = "F#"
        case g = "G"
        case gSharp = "G#"
        case a = "A"
        case aSharp = "A#"
        case b = "B"

        var name: String { rawValue }

        var midiOffset: Int {
            switch self {
            case .c: return 0
            case .cSharp: return 1
            case .d: return 2
            case .dSharp: return 3
            case .e: return 4
            case .f: return 5
            case .fSharp: return 6
            case .g: return 7
            case .gSharp: return 8
            case .a: return 9
            case .aSharp: return 10
            case .b: return 11
            }
        }
    }

    // Scale Modes
    enum ScaleMode: String, CaseIterable {
        case major = "Dur"
        case minor = "Moll"
        case harmonicMinor = "Harmonisch Moll"
        case melodicMinor = "Melodisch Moll"
        case dorian = "Dorisch"
        case phrygian = "Phrygisch"
        case lydian = "Lydisch"
        case mixolydian = "Mixolydisch"
        case locrian = "Lokrisch"
        case pentatonicMajor = "Pentatonik Dur"
        case pentatonicMinor = "Pentatonik Moll"
        case blues = "Blues"
        case chromatic = "Chromatisch"
    }

    func applyPreset(_ preset: MusicalTuningSystem.ConcertPitchPreset) {
        selectedPreset = preset
        concertPitch = preset.frequency
    }

    // Track-specific methods
    func getTuning(for trackId: UUID) -> TrackTuningSettings {
        return trackTunings[trackId] ?? TrackTuningSettings()
    }

    func setTuning(_ tuning: TrackTuningSettings, for trackId: UUID) {
        trackTunings[trackId] = tuning
    }

    func effectivePitch(for trackId: UUID) -> Double {
        let trackTuning = getTuning(for: trackId)
        if trackTuning.useGlobalSettings {
            return effectivePitch
        }
        return trackTuning.concertPitch * pow(2.0, trackTuning.fineTuneCents / 1200.0)
    }

    private init() {}
}

// MARK: - Track-Specific Tuning Settings

struct TrackTuningSettings: Codable, Equatable {
    var useGlobalSettings: Bool = true
    var concertPitch: Double = 440.0
    var fineTuneCents: Double = 0.0
    var transpose: Int = 0
    var tuningSystem: String = "Equal Temperament (12-TET)"
    var rootNote: String = "C"
    var scaleMode: String = "Dur"

    var effectivePitch: Double {
        concertPitch * pow(2.0, fineTuneCents / 1200.0)
    }

    static var global: TrackTuningSettings {
        var settings = TrackTuningSettings()
        settings.useGlobalSettings = true
        return settings
    }
}

// MARK: - Track Tuning Settings View (Per-Track)

struct TrackTuningSettingsView: View {
    let trackId: UUID
    let trackName: String
    @StateObject private var globalSettings = TuningSettings.shared
    @State private var trackSettings: TrackTuningSettings

    init(trackId: UUID, trackName: String) {
        self.trackId = trackId
        self.trackName = trackName
        _trackSettings = State(initialValue: TuningSettings.shared.getTuning(for: trackId))
    }

    var body: some View {
        Form {
            // Header
            Section {
                HStack {
                    Image(systemName: "tuningfork")
                        .font(.largeTitle)
                        .foregroundColor(.accentColor)
                    VStack(alignment: .leading) {
                        Text("Stimmung für")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(trackName)
                            .font(.headline)
                    }
                }
            }

            // Global vs Custom
            Section("Einstellungs-Quelle") {
                Toggle("Globale Einstellungen verwenden", isOn: $trackSettings.useGlobalSettings)

                if trackSettings.useGlobalSettings {
                    HStack {
                        Text("Aktuell")
                        Spacer()
                        Text("A4 = \(String(format: "%.2f", globalSettings.effectivePitch)) Hz")
                            .foregroundColor(.secondary)
                    }
                }
            }

            if !trackSettings.useGlobalSettings {
                // Custom Concert Pitch
                Section("Kammerton (Spur-spezifisch)") {
                    HStack {
                        Text("A4 =")
                        TextField("Hz", value: $trackSettings.concertPitch, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                        Text("Hz")
                        Spacer()
                    }

                    // Quick presets
                    HStack {
                        ForEach([415.0, 432.0, 440.0, 442.0, 444.0], id: \.self) { freq in
                            Button("\(Int(freq))") {
                                trackSettings.concertPitch = freq
                            }
                            .buttonStyle(.bordered)
                            .tint(trackSettings.concertPitch == freq ? .accentColor : nil)
                        }
                    }
                    .font(.caption)
                }

                // Fine Tune
                Section("Feinabstimmung") {
                    VStack(spacing: 12) {
                        Text("\(trackSettings.fineTuneCents > 0 ? "+" : "")\(String(format: "%.1f", trackSettings.fineTuneCents)) Cent")
                            .font(.title2.bold().monospaced())

                        Slider(value: $trackSettings.fineTuneCents, in: -100...100, step: 0.1)

                        HStack {
                            Button("-10") { trackSettings.fineTuneCents = max(-100, trackSettings.fineTuneCents - 10) }
                            Button("-1") { trackSettings.fineTuneCents = max(-100, trackSettings.fineTuneCents - 1) }
                            Spacer()
                            Button("0") { trackSettings.fineTuneCents = 0 }
                                .foregroundColor(.red)
                            Spacer()
                            Button("+1") { trackSettings.fineTuneCents = min(100, trackSettings.fineTuneCents + 1) }
                            Button("+10") { trackSettings.fineTuneCents = min(100, trackSettings.fineTuneCents + 10) }
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    }
                }

                // Transpose
                Section("Transponierung (Spur-spezifisch)") {
                    Stepper("\(trackSettings.transpose > 0 ? "+" : "")\(trackSettings.transpose) Halbtöne",
                            value: $trackSettings.transpose, in: -24...24)

                    HStack {
                        ForEach([-12, -7, -5, 0, 5, 7, 12], id: \.self) { semitones in
                            Button(semitones > 0 ? "+\(semitones)" : "\(semitones)") {
                                trackSettings.transpose = semitones
                            }
                            .buttonStyle(.bordered)
                            .tint(trackSettings.transpose == semitones ? .accentColor : nil)
                        }
                    }
                    .font(.caption)
                }

                // Result
                Section("Effektive Tonhöhe") {
                    HStack {
                        Text("A4")
                            .font(.headline)
                        Spacer()
                        Text("\(String(format: "%.4f", trackSettings.effectivePitch)) Hz")
                            .font(.headline.monospaced())
                            .foregroundColor(.accentColor)
                    }

                    if trackSettings.transpose != 0 {
                        HStack {
                            Text("Mit Transponierung")
                                .font(.caption)
                            Spacer()
                            Text("\(String(format: "%.4f", trackSettings.effectivePitch * pow(2.0, Double(trackSettings.transpose) / 12.0))) Hz")
                                .font(.caption.monospaced())
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            // Copy/Paste
            Section {
                Button("Von globalen Einstellungen kopieren") {
                    trackSettings.concertPitch = globalSettings.concertPitch
                    trackSettings.fineTuneCents = globalSettings.masterTuneCents
                    trackSettings.transpose = globalSettings.transpose
                    trackSettings.useGlobalSettings = false
                }

                Button("Auf Standardwerte zurücksetzen") {
                    trackSettings = TrackTuningSettings()
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("Spur-Stimmung")
        .onChange(of: trackSettings) { _, newValue in
            globalSettings.setTuning(newValue, for: trackId)
        }
    }
}

// MARK: - Compact Track Tuning Badge (for Track Header)

struct TrackTuningBadge: View {
    let trackId: UUID
    @StateObject private var settings = TuningSettings.shared

    var body: some View {
        let tuning = settings.getTuning(for: trackId)

        Group {
            if tuning.useGlobalSettings {
                // Global indicator
                Label("Global", systemImage: "globe")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                // Custom tuning indicator
                HStack(spacing: 4) {
                    Image(systemName: "tuningfork")
                        .font(.caption2)

                    Text("\(Int(tuning.concertPitch))")
                        .font(.caption2.bold())

                    if tuning.fineTuneCents != 0 {
                        Text("\(tuning.fineTuneCents > 0 ? "+" : "")\(Int(tuning.fineTuneCents))¢")
                            .font(.caption2)
                    }

                    if tuning.transpose != 0 {
                        Text("\(tuning.transpose > 0 ? "+" : "")\(tuning.transpose)")
                            .font(.caption2)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.accentColor.opacity(0.2)))
                .foregroundColor(.accentColor)
            }
        }
    }
}

// MARK: - Quick Tuning Popup (for Track Inspector)

struct QuickTuningPopup: View {
    let trackId: UUID
    @Binding var isPresented: Bool
    @StateObject private var globalSettings = TuningSettings.shared
    @State private var trackSettings: TrackTuningSettings

    init(trackId: UUID, isPresented: Binding<Bool>) {
        self.trackId = trackId
        _isPresented = isPresented
        _trackSettings = State(initialValue: TuningSettings.shared.getTuning(for: trackId))
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Schnell-Stimmung")
                    .font(.headline)
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Toggle Global
            Toggle("Global", isOn: $trackSettings.useGlobalSettings)

            if !trackSettings.useGlobalSettings {
                // Quick Pitch
                HStack {
                    Text("A4 =")
                    Picker("", selection: $trackSettings.concertPitch) {
                        Text("415").tag(415.0)
                        Text("432").tag(432.0)
                        Text("440").tag(440.0)
                        Text("442").tag(442.0)
                    }
                    .pickerStyle(.segmented)
                    Text("Hz")
                }

                // Quick Transpose
                HStack {
                    Text("Transpose:")
                    Stepper("\(trackSettings.transpose)", value: $trackSettings.transpose, in: -12...12)
                }

                // Fine Tune
                HStack {
                    Text("Fine:")
                    Slider(value: $trackSettings.fineTuneCents, in: -50...50)
                    Text("\(Int(trackSettings.fineTuneCents))¢")
                        .frame(width: 40)
                }
            }

            // Result
            HStack {
                Text("Effektiv:")
                Spacer()
                Text("\(String(format: "%.2f", trackSettings.useGlobalSettings ? globalSettings.effectivePitch : trackSettings.effectivePitch)) Hz")
                    .bold()
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 280)
        .background(RoundedRectangle(cornerRadius: 12).fill(.regularMaterial))
        .onChange(of: trackSettings) { _, newValue in
            globalSettings.setTuning(newValue, for: trackId)
        }
    }
}

// MARK: - Preview

#Preview {
    TuningSettingsView()
}
