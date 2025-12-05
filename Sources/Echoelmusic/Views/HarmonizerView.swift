import SwiftUI

// MARK: - Super Intelligent Harmonizer View
// Complete UI for the Harmonizer system with voice leading, analysis, and character selection

public struct HarmonizerView: View {
    @StateObject private var harmonizer = SuperIntelligentHarmonizer.shared
    @StateObject private var voiceEngine = VoiceCharacterEngine.shared

    @State private var selectedMode: HarmonyMode = .realTime
    @State private var selectedKey: String = "C"
    @State private var selectedScale: String = "major"
    @State private var voiceCount: Int = 4
    @State private var showCharacterPicker = false
    @State private var showAdvancedSettings = false
    @State private var analysisResult: HarmonicAnalysisResult?

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with mode selection
                    modeSelector

                    // Key and Scale
                    keyScaleSection

                    // Voice Characters
                    voiceCharactersSection

                    // Harmony visualization
                    harmonyVisualization

                    // Voice Leading Rules
                    voiceLeadingSection

                    // Analysis Results
                    if let analysis = analysisResult {
                        analysisSection(analysis)
                    }

                    // Quick Actions
                    quickActionsSection
                }
                .padding()
            }
            .navigationTitle("Harmonizer")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showAdvancedSettings.toggle() }) {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
            .sheet(isPresented: $showCharacterPicker) {
                CharacterPickerView(voiceEngine: voiceEngine)
            }
            .sheet(isPresented: $showAdvancedSettings) {
                AdvancedHarmonizerSettings()
            }
        }
    }

    // MARK: - Mode Selector

    private var modeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Harmonization Mode")
                .font(.headline)

            HStack(spacing: 12) {
                ForEach(HarmonyMode.allCases, id: \.self) { mode in
                    ModeButton(
                        mode: mode,
                        isSelected: selectedMode == mode,
                        action: { selectedMode = mode }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Key/Scale Section

    private var keyScaleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Key & Scale")
                .font(.headline)

            HStack(spacing: 20) {
                // Key Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Key")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Picker("Key", selection: $selectedKey) {
                        ForEach(["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"], id: \.self) { key in
                            Text(key).tag(key)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)
                }

                // Scale Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Scale")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Picker("Scale", selection: $selectedScale) {
                        ForEach(["major", "minor", "dorian", "phrygian", "lydian", "mixolydian", "locrian", "harmonic minor", "melodic minor"], id: \.self) { scale in
                            Text(scale.capitalized).tag(scale)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 150)
                }

                Spacer()

                // Voice Count
                VStack(alignment: .leading, spacing: 8) {
                    Text("Voices: \(voiceCount)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Stepper("", value: $voiceCount, in: 2...8)
                        .labelsHidden()
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Voice Characters Section

    private var voiceCharactersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Voice Characters")
                    .font(.headline)

                Spacer()

                Button("Browse All") {
                    showCharacterPicker = true
                }
                .font(.subheadline)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                ForEach(0..<voiceCount, id: \.self) { voice in
                    VoiceCharacterCard(
                        voiceIndex: voice,
                        character: voiceEngine.selectedCharacters[safe: voice] ?? .original
                    )
                }
            }
        }
    }

    // MARK: - Harmony Visualization

    private var harmonyVisualization: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Harmony Space")
                .font(.headline)

            GeometryReader { geometry in
                ZStack {
                    // Tonnetz visualization
                    TonnetzView(
                        currentChord: harmonizer.currentChord,
                        key: selectedKey
                    )

                    // Voice positions
                    ForEach(0..<voiceCount, id: \.self) { voice in
                        VoicePositionMarker(
                            voiceIndex: voice,
                            position: harmonizer.voicePositions[safe: voice] ?? .zero
                        )
                    }
                }
            }
            .frame(height: 200)
            .background(Color.black.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Voice Leading Section

    private var voiceLeadingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Voice Leading Rules")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                VoiceLeadingToggle(title: "Avoid Parallel 5ths", isOn: .constant(true))
                VoiceLeadingToggle(title: "Avoid Parallel 8ves", isOn: .constant(true))
                VoiceLeadingToggle(title: "Resolve Leading Tone", isOn: .constant(true))
                VoiceLeadingToggle(title: "Smooth Voice Motion", isOn: .constant(true))
                VoiceLeadingToggle(title: "Proper Spacing", isOn: .constant(true))
                VoiceLeadingToggle(title: "Range Limits", isOn: .constant(true))
            }
        }
    }

    // MARK: - Analysis Section

    private func analysisSection(_ analysis: HarmonicAnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Harmonic Analysis")
                .font(.headline)

            VStack(spacing: 12) {
                HStack {
                    AnalysisItem(label: "Roman Numeral", value: analysis.romanNumeral)
                    Spacer()
                    AnalysisItem(label: "Function", value: analysis.function)
                }

                HStack {
                    AnalysisItem(label: "Chord Quality", value: analysis.quality)
                    Spacer()
                    AnalysisItem(label: "Tension", value: String(format: "%.1f", analysis.tension))
                }

                if !analysis.suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Suggestions")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        ForEach(analysis.suggestions, id: \.self) { suggestion in
                            HStack {
                                Image(systemName: "lightbulb")
                                    .foregroundStyle(.yellow)
                                Text(suggestion)
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.headline)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                QuickActionButton(title: "Auto-Harmonize", icon: "wand.and.stars") {
                    Task { await autoHarmonize() }
                }

                QuickActionButton(title: "Generate Progression", icon: "arrow.triangle.branch") {
                    Task { await generateProgression() }
                }

                QuickActionButton(title: "Analyze", icon: "waveform.badge.magnifyingglass") {
                    Task { await analyze() }
                }

                QuickActionButton(title: "Voice Leading Check", icon: "checkmark.seal") {
                    Task { await checkVoiceLeading() }
                }

                QuickActionButton(title: "Reharmonize", icon: "arrow.triangle.2.circlepath") {
                    Task { await reharmonize() }
                }

                QuickActionButton(title: "Export MIDI", icon: "square.and.arrow.up") {
                    exportMIDI()
                }
            }
        }
    }

    // MARK: - Actions

    private func autoHarmonize() async {
        // Trigger auto-harmonization
    }

    private func generateProgression() async {
        // Generate chord progression
    }

    private func analyze() async {
        // Run harmonic analysis
    }

    private func checkVoiceLeading() async {
        // Check voice leading rules
    }

    private func reharmonize() async {
        // Reharmonize current progression
    }

    private func exportMIDI() {
        // Export to MIDI
    }
}

// MARK: - Supporting Views

struct ModeButton: View {
    let mode: HarmonyMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: mode.icon)
                    .font(.title2)
                Text(mode.title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? Color.accentColor : Color(.systemGray5))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

struct VoiceCharacterCard: View {
    let voiceIndex: Int
    let character: VoiceCharacter

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: character.icon)
                .font(.title)
                .foregroundStyle(voiceColors[voiceIndex % voiceColors.count])

            Text("Voice \(voiceIndex + 1)")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(character.name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var voiceColors: [Color] {
        [.blue, .green, .orange, .purple, .pink, .cyan, .yellow, .red]
    }
}

struct VoiceLeadingToggle: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

struct AnalysisItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
    }
}

struct TonnetzView: View {
    let currentChord: String?
    let key: String

    var body: some View {
        Canvas { context, size in
            // Draw Tonnetz grid
            let nodeSpacing: CGFloat = 40
            let rows = Int(size.height / nodeSpacing)
            let cols = Int(size.width / nodeSpacing)

            for row in 0..<rows {
                for col in 0..<cols {
                    let x = CGFloat(col) * nodeSpacing + nodeSpacing / 2
                    let y = CGFloat(row) * nodeSpacing + nodeSpacing / 2

                    // Draw node
                    let path = Circle().path(in: CGRect(x: x - 4, y: y - 4, width: 8, height: 8))
                    context.fill(path, with: .color(.white.opacity(0.3)))
                }
            }
        }
    }
}

struct VoicePositionMarker: View {
    let voiceIndex: Int
    let position: CGPoint

    var body: some View {
        Circle()
            .fill(voiceColors[voiceIndex % voiceColors.count])
            .frame(width: 16, height: 16)
            .position(position)
    }

    private var voiceColors: [Color] {
        [.blue, .green, .orange, .purple, .pink, .cyan, .yellow, .red]
    }
}

struct CharacterPickerView: View {
    @ObservedObject var voiceEngine: VoiceCharacterEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Original") {
                    CharacterRow(character: .original)
                }

                Section("Choir") {
                    ForEach(VoiceCharacter.choirCharacters, id: \.name) { character in
                        CharacterRow(character: character)
                    }
                }

                Section("Synthesizers") {
                    ForEach(VoiceCharacter.synthCharacters, id: \.name) { character in
                        CharacterRow(character: character)
                    }
                }

                Section("Acoustic Instruments") {
                    ForEach(VoiceCharacter.acousticCharacters, id: \.name) { character in
                        CharacterRow(character: character)
                    }
                }
            }
            .navigationTitle("Voice Characters")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct CharacterRow: View {
    let character: VoiceCharacter

    var body: some View {
        HStack {
            Image(systemName: character.icon)
                .frame(width: 30)
                .foregroundStyle(.accentColor)

            VStack(alignment: .leading) {
                Text(character.name)
                    .font(.headline)
                Text(character.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AdvancedHarmonizerSettings: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Voice Leading") {
                    Toggle("Strict Counterpoint", isOn: .constant(false))
                    Toggle("Allow Parallel Motion", isOn: .constant(false))
                    Stepper("Max Voice Distance: 12", value: .constant(12), in: 4...24)
                }

                Section("Analysis") {
                    Toggle("Real-time Analysis", isOn: .constant(true))
                    Toggle("Show Tension Graph", isOn: .constant(true))
                    Toggle("Neo-Riemannian Mode", isOn: .constant(false))
                }

                Section("Generation") {
                    Picker("Style", selection: .constant("Classical")) {
                        Text("Classical").tag("Classical")
                        Text("Jazz").tag("Jazz")
                        Text("Pop").tag("Pop")
                        Text("Film").tag("Film")
                    }

                    Slider(value: .constant(0.5), in: 0...1) {
                        Text("Complexity")
                    }
                }
            }
            .navigationTitle("Advanced Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Types

enum HarmonyMode: String, CaseIterable {
    case realTime = "realTime"
    case generate = "generate"
    case analyze = "analyze"
    case reharmonize = "reharmonize"

    var title: String {
        switch self {
        case .realTime: return "Real-Time"
        case .generate: return "Generate"
        case .analyze: return "Analyze"
        case .reharmonize: return "Reharmonize"
        }
    }

    var icon: String {
        switch self {
        case .realTime: return "waveform"
        case .generate: return "sparkles"
        case .analyze: return "magnifyingglass"
        case .reharmonize: return "arrow.triangle.2.circlepath"
        }
    }
}

struct VoiceCharacter {
    let name: String
    let category: String
    let icon: String

    static let original = VoiceCharacter(name: "Original", category: "Unprocessed", icon: "waveform")

    static let choirCharacters: [VoiceCharacter] = [
        VoiceCharacter(name: "Soprano", category: "Choir", icon: "person.wave.2"),
        VoiceCharacter(name: "Alto", category: "Choir", icon: "person.wave.2"),
        VoiceCharacter(name: "Tenor", category: "Choir", icon: "person.wave.2"),
        VoiceCharacter(name: "Bass", category: "Choir", icon: "person.wave.2"),
        VoiceCharacter(name: "Boys Choir", category: "Choir", icon: "figure.2"),
        VoiceCharacter(name: "Gospel", category: "Choir", icon: "music.mic"),
    ]

    static let synthCharacters: [VoiceCharacter] = [
        VoiceCharacter(name: "Supersaw", category: "Synth", icon: "waveform.path"),
        VoiceCharacter(name: "Pad", category: "Synth", icon: "rectangle.fill"),
        VoiceCharacter(name: "Lead", category: "Synth", icon: "bolt.fill"),
        VoiceCharacter(name: "Bass", category: "Synth", icon: "speaker.wave.3"),
        VoiceCharacter(name: "Vocoder", category: "Synth", icon: "waveform.circle"),
    ]

    static let acousticCharacters: [VoiceCharacter] = [
        VoiceCharacter(name: "Strings", category: "Acoustic", icon: "guitars"),
        VoiceCharacter(name: "Brass", category: "Acoustic", icon: "horn"),
        VoiceCharacter(name: "Woodwinds", category: "Acoustic", icon: "wind"),
        VoiceCharacter(name: "Piano", category: "Acoustic", icon: "pianokeys"),
    ]
}

struct HarmonicAnalysisResult {
    let romanNumeral: String
    let function: String
    let quality: String
    let tension: Double
    let suggestions: [String]
}

// MARK: - Extensions

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Mock Types for Compilation

class SuperIntelligentHarmonizer: ObservableObject {
    static let shared = SuperIntelligentHarmonizer()
    @Published var currentChord: String? = nil
    @Published var voicePositions: [CGPoint] = []
}

class VoiceCharacterEngine: ObservableObject {
    static let shared = VoiceCharacterEngine()
    @Published var selectedCharacters: [VoiceCharacter] = []
}

#Preview {
    HarmonizerView()
}
