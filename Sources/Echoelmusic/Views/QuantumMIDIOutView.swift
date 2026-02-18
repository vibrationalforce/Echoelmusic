// QuantumMIDIOutView.swift
// Echoelmusic - Super Intelligent Quantum MIDI Out Control View
// λ∞ Ralph Wiggum Apple Ökosystem Environment Lambda Loop Mode
//
// "I'm a unitard!" - Ralph Wiggum, watching MIDI flow
//
// Created 2026-01-21 - Phase 10000.3 SUPER INTELLIGENT QUANTUM MIDI

import SwiftUI

/// SwiftUI control view for the Super Intelligent Quantum MIDI Out Engine
@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
public struct QuantumMIDIOutView: View {
    @ObservedObject var midiOut: QuantumMIDIOut
    @State private var showSettings = false
    @State private var showInstruments = false
    @State private var selectedOctave: Int = 4
    @State private var lastPlayedNote: UInt8 = 60

    public init(midiOut: QuantumMIDIOut) {
        self.midiOut = midiOut
    }

    public var body: some View {
        ZStack {
            // Background gradient based on coherence
            backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView

                // Main content
                ScrollView {
                    VStack(spacing: 20) {
                        // Status panel
                        statusPanel

                        // Quantum state visualization
                        quantumStateVisualization

                        // Keyboard
                        keyboardSection

                        // Quick chord buttons
                        chordSection

                        // Bio input display
                        bioInputDisplay

                        // Controls
                        controlsSection
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            QuantumMIDISettingsView(midiOut: midiOut)
        }
        .sheet(isPresented: $showInstruments) {
            InstrumentRoutingView(midiOut: midiOut)
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        let hue = 0.6 + Double(midiOut.globalCoherence) * 0.2

        return LinearGradient(
            colors: [
                Color(hue: hue, saturation: 0.3, brightness: 0.15),
                Color(hue: hue + 0.1, saturation: 0.2, brightness: 0.1),
                Color.black
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("⚛️ Quantum MIDI Out")
                    .font(.headline)
                Text(midiOut.intelligenceMode.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Settings button
            Button { showInstruments = true } label: {
                Image(systemName: "pianokeys")
                    .font(.title2)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
            }

            Button { showSettings = true } label: {
                Image(systemName: "gear")
                    .font(.title2)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    // MARK: - Status Panel

    private var statusPanel: some View {
        HStack(spacing: 16) {
            // Active/Inactive indicator
            VStack {
                Circle()
                    .fill(midiOut.isActive ? Color.green : Color.gray)
                    .frame(width: 12, height: 12)
                Text(midiOut.isActive ? "Active" : "Inactive")
                    .font(.caption2)
            }

            Divider()
                .frame(height: 40)

            // Voice count
            VStack {
                Text("\(midiOut.voiceCount)")
                    .font(.title2.monospacedDigit())
                    .fontWeight(.bold)
                Text("Voices")
                    .font(.caption2)
            }

            Divider()
                .frame(height: 40)

            // Entanglement pairs
            VStack {
                Text("\(midiOut.entanglementPairs)")
                    .font(.title2.monospacedDigit())
                    .fontWeight(.bold)
                    .foregroundColor(.purple)
                Text("Entangled")
                    .font(.caption2)
            }

            Divider()
                .frame(height: 40)

            // Superposition voices
            VStack {
                Text("\(midiOut.superpositionVoices)")
                    .font(.title2.monospacedDigit())
                    .fontWeight(.bold)
                    .foregroundColor(.cyan)
                Text("Superposition")
                    .font(.caption2)
            }

            Spacer()

            // Start/Stop button
            Button {
                Task {
                    if midiOut.isActive {
                        midiOut.stop()
                    } else {
                        try? await midiOut.start()
                    }
                }
            } label: {
                Image(systemName: midiOut.isActive ? "stop.fill" : "play.fill")
                    .font(.title)
                    .foregroundColor(midiOut.isActive ? .red : .green)
                    .padding()
                    .background(Circle().fill(.ultraThinMaterial))
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

    // MARK: - Quantum State Visualization

    private var quantumStateVisualization: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quantum State")
                .font(.caption.bold())
                .foregroundColor(.secondary)

            HStack(spacing: 4) {
                ForEach(midiOut.activeVoices.prefix(16)) { voice in
                    VoiceIndicator(voice: voice)
                }

                // Empty slots
                ForEach(0..<max(0, 16 - midiOut.activeVoices.count), id: \.self) { _ in
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        .frame(width: 20, height: 20)
                }
            }

            // Coherence bar
            HStack {
                Text("Coherence")
                    .font(.caption)
                    .foregroundColor(.secondary)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.gray.opacity(0.3))

                        Capsule()
                            .fill(coherenceGradient)
                            .frame(width: geometry.size.width * CGFloat(midiOut.globalCoherence))
                    }
                }
                .frame(height: 8)

                Text("\(Int(midiOut.globalCoherence * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

    private var coherenceGradient: LinearGradient {
        LinearGradient(
            colors: [.blue, .cyan, .green],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: - Keyboard Section

    private var keyboardSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Keyboard")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                Spacer()

                // Octave selector
                HStack(spacing: 4) {
                    Button { selectedOctave = max(0, selectedOctave - 1) } label: {
                        Image(systemName: "minus")
                            .padding(4)
                            .background(Circle().fill(.ultraThinMaterial))
                    }

                    Text("C\(selectedOctave)")
                        .font(.caption.monospacedDigit())
                        .frame(width: 30)

                    Button { selectedOctave = min(8, selectedOctave + 1) } label: {
                        Image(systemName: "plus")
                            .padding(4)
                            .background(Circle().fill(.ultraThinMaterial))
                    }
                }
            }

            // Simple piano keyboard
            PianoKeyboard(
                octave: selectedOctave,
                onNoteOn: { note in
                    lastPlayedNote = note
                    midiOut.noteOn(note: note)
                },
                onNoteOff: { note in
                    midiOut.noteOff(note: note)
                }
            )
            .frame(height: 80)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

    // MARK: - Chord Section

    private var chordSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quantum Chords")
                .font(.caption.bold())
                .foregroundColor(.secondary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(QuantumChordType.allCases.prefix(8)) { chord in
                    Button {
                        midiOut.playQuantumChord(root: lastPlayedNote, type: chord)
                    } label: {
                        Text(chord.rawValue)
                            .font(.caption)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 4)
                            .frame(maxWidth: .infinity)
                            .background(chordColor(for: chord))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Special quantum chords
            HStack(spacing: 8) {
                ForEach([QuantumChordType.fibonacci, .goldenRatio, .quantumSuperposition, .sacredGeometry], id: \.self) { chord in
                    Button {
                        midiOut.playQuantumChord(root: lastPlayedNote, type: chord)
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: symbolForChord(chord))
                                .font(.title3)
                            Text(chord.rawValue)
                                .font(.caption2)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        .background(chordColor(for: chord))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

    private func chordColor(for chord: QuantumChordType) -> Color {
        switch chord {
        case .majorTriad, .major7: return .blue.opacity(0.3)
        case .minorTriad, .minor7: return .purple.opacity(0.3)
        case .diminished, .halfDiminished: return .red.opacity(0.3)
        case .augmented: return .orange.opacity(0.3)
        case .dominant7: return .yellow.opacity(0.3)
        case .fibonacci: return .green.opacity(0.4)
        case .goldenRatio: return .yellow.opacity(0.4)
        case .quantumSuperposition: return .cyan.opacity(0.4)
        case .sacredGeometry: return .purple.opacity(0.4)
        case .schumannResonance: return .teal.opacity(0.4)
        }
    }

    private func symbolForChord(_ chord: QuantumChordType) -> String {
        switch chord {
        case .fibonacci: return "leaf"
        case .goldenRatio: return "aspectratio"
        case .quantumSuperposition: return "atom"
        case .sacredGeometry: return "hexagon"
        case .schumannResonance: return "waveform"
        default: return "music.note"
        }
    }

    // MARK: - Bio Input Display

    private var bioInputDisplay: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bio Input")
                .font(.caption.bold())
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                BioMetricView(
                    icon: "heart.fill",
                    label: "Heart Rate",
                    value: "\(Int(midiOut.bioInput.heartRate))",
                    unit: "BPM",
                    color: .red
                )

                BioMetricView(
                    icon: "waveform.path.ecg",
                    label: "HRV",
                    value: "\(Int(midiOut.bioInput.hrvMs))",
                    unit: "ms",
                    color: .orange
                )

                BioMetricView(
                    icon: "sparkles",
                    label: "Coherence",
                    value: "\(Int(midiOut.bioInput.coherence * 100))",
                    unit: "%",
                    color: .cyan
                )

                BioMetricView(
                    icon: "wind",
                    label: "Breath",
                    value: "\(Int(midiOut.bioInput.breathPhase * 100))",
                    unit: "%",
                    color: .green
                )
            }

            // Lambda state
            HStack {
                Text("λ State:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(lambdaStateName(midiOut.bioInput.lambdaState))
                    .font(.caption.bold())
                    .foregroundColor(lambdaStateColor(midiOut.bioInput.lambdaState))

                Spacer()

                // Quantum phase indicator
                Text("Phase: \(String(format: "%.2f", midiOut.bioInput.quantumPhase))π")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

    private func lambdaStateName(_ state: QuantumBioInput.LambdaState) -> String {
        switch state {
        case .dormant: return "Dormant"
        case .awakening: return "Awakening"
        case .aware: return "Aware"
        case .flowing: return "Flowing"
        case .coherent: return "Coherent"
        case .transcendent: return "Transcendent"
        case .unified: return "Unified"
        case .lambdaInfinity: return "λ∞"
        }
    }

    private func lambdaStateColor(_ state: QuantumBioInput.LambdaState) -> Color {
        switch state {
        case .dormant: return .gray
        case .awakening: return .yellow
        case .aware: return .green
        case .flowing: return .cyan
        case .coherent: return .blue
        case .transcendent: return .purple
        case .unified: return .pink
        case .lambdaInfinity: return .white
        }
    }

    // MARK: - Controls Section

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.caption.bold())
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                Button {
                    midiOut.generateBioReactivePhrase()
                } label: {
                    VStack {
                        Image(systemName: "wand.and.stars")
                            .font(.title2)
                        Text("Generate Phrase")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                }
                .disabled(!midiOut.isActive)

                Button {
                    midiOut.playAcrossAllInstruments(note: lastPlayedNote)
                } label: {
                    VStack {
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.title2)
                        Text("All Instruments")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                }
                .disabled(!midiOut.isActive)

                Button {
                    midiOut.allNotesOff()
                } label: {
                    VStack {
                        Image(systemName: "speaker.slash.fill")
                            .font(.title2)
                            .foregroundColor(.red)
                        Text("All Notes Off")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

// MARK: - Voice Indicator

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
struct VoiceIndicator: View {
    let voice: QuantumMIDIVoice

    var body: some View {
        Circle()
            .fill(voiceColor)
            .frame(width: 20, height: 20)
            .overlay {
                if voice.quantumState.entangledVoiceId != nil {
                    Image(systemName: "link")
                        .font(.system(size: 8))
                        .foregroundColor(.white)
                }
            }
            .scaleEffect(voice.isActive ? 1.0 : 0.8)
            .animation(.easeInOut(duration: 0.1), value: voice.isActive)
    }

    private var voiceColor: Color {
        if voice.quantumState.superposition > 0.5 {
            return .cyan
        } else if voice.quantumState.entangledVoiceId != nil {
            return .purple
        } else {
            return Color(hue: Double(voice.midiNote % 12) / 12.0, saturation: 0.7, brightness: 0.8)
        }
    }
}

// MARK: - Piano Keyboard

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
struct PianoKeyboard: View {
    let octave: Int
    let onNoteOn: (UInt8) -> Void
    let onNoteOff: (UInt8) -> Void

    private let whiteKeys = [0, 2, 4, 5, 7, 9, 11]  // C, D, E, F, G, A, B
    private let blackKeys = [1, 3, 6, 8, 10]  // C#, D#, F#, G#, A#

    var body: some View {
        GeometryReader { geometry in
            let keyWidth = geometry.size.width / 7
            let blackKeyWidth = keyWidth * 0.6

            ZStack(alignment: .topLeading) {
                // White keys
                HStack(spacing: 2) {
                    ForEach(0..<7, id: \.self) { index in
                        let note = UInt8((octave + 1) * 12 + whiteKeys[index])
                        QuantumPianoKey(isBlack: false)
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { _ in onNoteOn(note) }
                                    .onEnded { _ in onNoteOff(note) }
                            )
                    }
                }

                // Black keys
                ForEach(0..<5, id: \.self) { index in
                    let note = UInt8((octave + 1) * 12 + blackKeys[index])
                    let offset = blackKeyOffset(for: index, keyWidth: keyWidth)

                    QuantumPianoKey(isBlack: true)
                        .frame(width: blackKeyWidth, height: geometry.size.height * 0.6)
                        .offset(x: offset)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in onNoteOn(note) }
                                .onEnded { _ in onNoteOff(note) }
                        )
                }
            }
        }
    }

    private func blackKeyOffset(for index: Int, keyWidth: CGFloat) -> CGFloat {
        let positions: [CGFloat] = [0.7, 1.8, 3.7, 4.75, 5.8]
        return positions[index] * keyWidth
    }
}

// MARK: - Quantum Piano Key

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
struct QuantumPianoKey: View {
    let isBlack: Bool
    @State private var isPressed = false

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(isPressed ?
                  (isBlack ? Color.gray : Color.blue.opacity(0.3)) :
                    (isBlack ? Color.black : Color.white))
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.gray.opacity(0.5), lineWidth: 1)
            }
    }
}

// MARK: - Bio Metric View

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
struct BioMetricView: View {
    let icon: String
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)

            Text(value)
                .font(.headline.monospacedDigit())

            Text(unit)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Settings View

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
struct QuantumMIDISettingsView: View {
    @ObservedObject var midiOut: QuantumMIDIOut
    @Environment(\.dismiss) var dismiss

    var body: some View {
        EchoelNavigationStack {
            Form {
                Section("Intelligence Mode") {
                    Picker("Mode", selection: $midiOut.intelligenceMode) {
                        ForEach(QuantumIntelligenceMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                }

                Section("Polyphony") {
                    Stepper("Voices: \(midiOut.polyphony)", value: Binding(
                        get: { midiOut.polyphony },
                        set: { _ in }  // Read-only for now
                    ), in: 1...64)
                }

                Section("MIDI Options") {
                    Toggle("MPE Enabled", isOn: $midiOut.routing.mpeEnabled)
                    Toggle("MIDI 2.0 Enabled", isOn: $midiOut.routing.midi2Enabled)
                }

                Section("Presets") {
                    Button("Meditation") { midiOut.loadMeditationPreset() }
                    Button("Orchestral") { midiOut.loadOrchestralPreset() }
                    Button("Quantum Transcendent") { midiOut.loadQuantumTranscendentPreset() }
                    Button("Sacred Geometry") { midiOut.loadSacredGeometryPreset() }
                }

                Section {
                    Text("Super Intelligent Quantum MIDI Out generates bio-reactive, coherence-aware MIDI output with entanglement support.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Quantum MIDI Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Instrument Routing View

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
struct InstrumentRoutingView: View {
    @ObservedObject var midiOut: QuantumMIDIOut
    @Environment(\.dismiss) var dismiss

    private let categories: [(String, [QuantumMIDIVoice.InstrumentTarget])] = [
        ("Orchestral Strings", [.violins, .violas, .cellos, .basses]),
        ("Brass", [.trumpets, .frenchHorns, .trombones, .tuba]),
        ("Woodwinds", [.flutes, .oboes, .clarinets, .bassoons]),
        ("Choir", [.sopranos, .altos, .tenors, .choirBasses]),
        ("Keys & Percussion", [.piano, .harp, .celesta, .timpani]),
        ("Synthesizers", [.subtractive, .fm, .wavetable, .granular, .additive, .physicalModeling]),
        ("Bio-Reactive", [.genetic, .organic, .bioReactive, .echoSynth]),
        ("Global", [.sitar, .erhu, .koto, .shakuhachi, .oud, .ney, .djembe, .kalimba, .didgeridoo]),
        ("Quantum", [.quantumField, .entangledPair, .superpositionVoice])
    ]

    var body: some View {
        EchoelNavigationStack {
            List {
                ForEach(categories, id: \.0) { category, instruments in
                    Section(category) {
                        ForEach(instruments, id: \.self) { instrument in
                            Toggle(
                                instrument.rawValue,
                                isOn: Binding(
                                    get: { midiOut.routing.enabledInstruments.contains(instrument) },
                                    set: { enabled in
                                        if enabled {
                                            midiOut.routing.enabledInstruments.insert(instrument)
                                        } else {
                                            midiOut.routing.enabledInstruments.remove(instrument)
                                        }
                                    }
                                )
                            )
                        }
                    }
                }

                Section {
                    Button("Enable All") { midiOut.routing.enableAll() }
                    Button("Enable Orchestral Only") {
                        midiOut.routing.enabledInstruments.removeAll()
                        midiOut.routing.enableOrchestral()
                    }
                    Button("Enable Synthesizers Only") {
                        midiOut.routing.enabledInstruments.removeAll()
                        midiOut.routing.enableSynthesizers()
                    }
                }
            }
            .navigationTitle("Instrument Routing")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
struct QuantumMIDIOutView_Previews: PreviewProvider {
    static var previews: some View {
        QuantumMIDIOutView(midiOut: QuantumMIDIOut())
    }
}
#endif
