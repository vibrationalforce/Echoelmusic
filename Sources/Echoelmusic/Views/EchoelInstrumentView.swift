#if canImport(SwiftUI) && canImport(AVFoundation)
import SwiftUI
import AVFoundation

/// Full-screen touch synth instrument.
/// Black touch surface = the instrument. Bottom bar = minimal controls.
/// Touch → EchoelSynth.noteOn() directly (6-9ms latency via AVAudioSourceNode).
struct EchoelInstrumentView: View {

    @Environment(AudioEngine.self) var audioEngine

    // MARK: - State

    // Scale & Key
    @State private var currentScale: TouchMusicalScale = .pentatonicMinor
    @State private var rootNote: UInt8 = 48 // C3
    @State private var rootNoteName: String = "C"

    // Sound preset
    @State private var currentSound: SoundPreset = .silk

    /// Curated sound presets — each one carefully tuned for maximum quality.
    enum SoundPreset: String, CaseIterable {
        case silk = "Silk"
        case ocean = "Ocean"
        case forest = "Forest"
        case ember = "Ember"
        case midnight = "Midnight"

        /// Apply this preset's synth configuration
        @MainActor func apply() {
            var cfg = EchoelSynthConfig()
            switch self {

            case .silk:
                // Lush supersaw pad — Juno-60 inspired ensemble.
                // 7 detuned voices with slow beating. Tape-style chorus.
                // Gentle filter sweep opens on sustain for evolving warmth.
                // Long release tail lets notes blend into each other.
                cfg.engine = .pad
                cfg.padVoiceCount = 7; cfg.padSpread = 20.0
                cfg.padChorusRate = 0.12; cfg.padChorusDepth = 0.8
                cfg.filterMode = .lowpass; cfg.filterCutoff = 3500.0; cfg.filterResonance = 0.05
                cfg.filterEnvAmount = 1500.0; cfg.filterEnvDecay = 2.5
                cfg.attack = 0.6; cfg.decay = 2.5; cfg.sustain = 0.92; cfg.release = 4.0
                cfg.chorusAmount = 0.6; cfg.stereoWidth = 0.8
                cfg.vibratoRate = 1.5; cfg.vibratoDepth = 0.008

            case .ocean:
                // Deep evolving wavetable. Tidal harmonic morphing.
                // Very slow modulation speed — feels like breathing.
                // -1 octave gives chest-resonance sub-bass warmth.
                // Maximum stereo width, extra long release for ambient wash.
                cfg.engine = .wavetable
                cfg.wtPosition = 0.35; cfg.wtModSpeed = 0.018
                cfg.filterMode = .lowpass; cfg.filterCutoff = 1400.0; cfg.filterResonance = 0.12
                cfg.filterEnvAmount = 3200.0; cfg.filterEnvDecay = 5.0
                cfg.attack = 1.5; cfg.decay = 5.0; cfg.sustain = 0.8; cfg.release = 8.0
                cfg.chorusAmount = 0.75; cfg.stereoWidth = 1.0
                cfg.vibratoRate = 0.05; cfg.vibratoDepth = 0.04
                cfg.octave = -1

            case .forest:
                // Karplus-Strong physical modeling — wood/string resonance.
                // High decay coefficient (0.998) for long, singing sustain.
                // Moderate brightness with gentle high-end rolloff.
                // Subtle chorus adds spatial depth without muddiness.
                cfg.engine = .pluck
                cfg.pluckDamping = 0.3; cfg.pluckDecay = 0.998; cfg.pluckBrightness = 0.55
                cfg.pluckStretch = 0.06
                cfg.filterMode = .lowpass; cfg.filterCutoff = 4500.0; cfg.filterResonance = 0.1
                cfg.filterEnvAmount = 2000.0; cfg.filterEnvDecay = 0.4
                cfg.attack = 0.001; cfg.decay = 2.8; cfg.sustain = 0.0; cfg.release = 3.0
                cfg.chorusAmount = 0.3; cfg.stereoWidth = 0.75
                cfg.vibratoRate = 1.0; cfg.vibratoDepth = 0.006

            case .ember:
                // Analog warmth with musical saturation.
                // 4 voices slightly detuned for fatness. Saw-leaning waveform.
                // Fast filter env snaps open then decays — percussive character.
                // Drive adds even harmonics, not harshness.
                cfg.engine = .analog
                cfg.analogDetune = 15.0; cfg.analogVoices = 4; cfg.analogWaveform = 0.25
                cfg.analogPWM = 0.45
                cfg.filterMode = .lowpass; cfg.filterCutoff = 2600.0; cfg.filterResonance = 0.2
                cfg.filterEnvAmount = 5500.0; cfg.filterEnvDecay = 0.18
                cfg.attack = 0.003; cfg.decay = 0.7; cfg.sustain = 0.45; cfg.release = 1.0
                cfg.chorusAmount = 0.25; cfg.drive = 0.25; cfg.stereoWidth = 0.55
                cfg.vibratoRate = 3.5; cfg.vibratoDepth = 0.012

            case .midnight:
                // Deep analog — Prophet-5 / OB-Xa character.
                // 5 voices, heavy detuning for massive unison spread.
                // Low cutoff creates warm, intimate proximity.
                // Gentle drive adds analog floor noise character.
                // Slow vibrato adds human expression.
                cfg.engine = .analog
                cfg.analogDetune = 28.0; cfg.analogVoices = 5; cfg.analogWaveform = 0.0
                cfg.filterMode = .lowpass; cfg.filterCutoff = 1600.0; cfg.filterResonance = 0.15
                cfg.filterEnvAmount = 3000.0; cfg.filterEnvDecay = 0.8
                cfg.attack = 0.03; cfg.decay = 1.2; cfg.sustain = 0.6; cfg.release = 2.2
                cfg.chorusAmount = 0.55; cfg.drive = 0.05; cfg.stereoWidth = 0.75
                cfg.vibratoRate = 2.0; cfg.vibratoDepth = 0.014
            }
            EchoelSynth.shared.config = cfg
        }
    }

    /// Represents one active finger on the instrument surface
    struct ActiveTouchPoint: Identifiable {
        let id: String
        let location: CGPoint
        let midiNote: Int
        let noteName: String
    }

    // Active touches for note matrix visualization
    @State private var activeTouches: [ActiveTouchPoint] = []

    // MARK: - Root Note Options

    private static let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background — near-black
                Color(red: 0.04, green: 0.04, blue: 0.04)
                    .ignoresSafeArea()

                // Note matrix — full-screen grid showing scale degrees
                noteMatrix(in: geometry.size)

                // Multi-touch instrument surface (UIKit, polyphonic)
                #if canImport(UIKit)
                MultiTouchInstrumentView(
                    scale: currentScale,
                    rootNote: rootNote
                ) { touches in
                    activeTouches = touches.map { t in
                        ActiveTouchPoint(
                            id: "\(t.id)",
                            location: t.location,
                            midiNote: t.midiNote,
                            noteName: t.noteName
                        )
                    }
                }
                #endif

                // Touch visualization — one circle per finger
                ForEach(activeTouches) { touch in
                    touchIndicator(at: touch.location, noteName: touch.noteName)
                }

                // Bottom bar
                VStack {
                    Spacer()
                    bottomBar
                }
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .persistentSystemOverlays(.hidden)
        .statusBarHidden()
        .onAppear {
            currentSound.apply()
        }
    }

    // MARK: - Note Matrix (full-screen grid showing the tonal space)

    private func noteMatrix(in size: CGSize) -> some View {
        let intervals = currentScale.intervals
        let notesPerOctave = intervals.count
        let totalNotes = notesPerOctave * 2 // 2 octaves
        let columnWidth = size.width / CGFloat(totalNotes)
        let activeNotes = Set(activeTouches.map { $0.midiNote })

        return ZStack {
            // Vertical column lines — one per scale degree
            ForEach(0..<totalNotes, id: \.self) { index in
                let x = CGFloat(index) * columnWidth + columnWidth / 2
                let octave = index / notesPerOctave
                let degree = index % notesPerOctave
                let midiNote = Int(rootNote) + (octave * 12) + intervals[degree]
                let isActive = activeNotes.contains(midiNote)
                let isRoot = degree == 0

                // Column background — lights up when note is active
                Rectangle()
                    .fill(isActive
                          ? Color.white.opacity(0.12)
                          : Color.white.opacity(isRoot ? 0.03 : 0.01))
                    .frame(width: columnWidth - 1)
                    .position(x: x, y: size.height / 2)

                // Column border
                Rectangle()
                    .fill(Color.white.opacity(isRoot ? 0.08 : 0.03))
                    .frame(width: 0.5)
                    .position(x: CGFloat(index) * columnWidth, y: size.height / 2)

                // Note label at bottom
                Text(Self.midiNoteName(midiNote))
                    .font(.system(size: 10, weight: isActive ? .bold : .regular, design: .monospaced))
                    .foregroundColor(Color.white.opacity(isActive ? 0.6 : 0.15))
                    .position(x: x, y: size.height - 56)
            }
        }
    }

    /// Convert MIDI note number to note name
    private static func midiNoteName(_ note: Int) -> String {
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = (note / 12) - 1
        return "\(names[note % 12])\(octave)"
    }

    // MARK: - Touch Indicator

    @ViewBuilder
    private func touchIndicator(at location: CGPoint, noteName: String = "") -> some View {
        ZStack {
            // Touch ring
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 2)
                .frame(width: 44, height: 44)

            // Touch point
            Circle()
                .fill(Color.white.opacity(0.7))
                .frame(width: 30, height: 30)

            // Note name
            if !noteName.isEmpty {
                Text(noteName)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.5))
                    .offset(y: -32)
            }
        }
        .position(location)
        .allowsHitTesting(false)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 16) {
            // 1. Key / Scale
            keyScalePicker

            Divider().frame(height: 24).opacity(0.3)

            // 2. Sound Preset
            soundPicker

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Color.black.opacity(0.85)
                .overlay(
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 0.5),
                    alignment: .top
                )
        )
    }

    // MARK: - Key/Scale Picker

    private var keyScalePicker: some View {
        Menu {
            // Root note
            Menu("Root Note") {
                ForEach(0..<12, id: \.self) { i in
                    Button(Self.noteNames[i]) {
                        rootNote = UInt8(48 + i) // C3 + offset
                        rootNoteName = Self.noteNames[i]
                    }
                }
            }

            Divider()

            // Scale
            ForEach(TouchMusicalScale.allCases, id: \.self) { scale in
                Button {
                    currentScale = scale
                } label: {
                    HStack {
                        Text(scale.rawValue)
                        if scale == currentScale {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Text("\(rootNoteName) \(currentScale.rawValue)")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.8))
                .lineLimit(1)
        }
    }

    // MARK: - Sound Preset Picker

    private var soundPicker: some View {
        Menu {
            ForEach(SoundPreset.allCases, id: \.self) { preset in
                Button {
                    currentSound = preset
                    preset.apply()
                } label: {
                    HStack {
                        Text(preset.rawValue)
                        if preset == currentSound {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Text(currentSound.rawValue)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.8))
        }
    }

}

#endif
