#if canImport(AVFoundation)
//
//  EchoelBassView.swift
//  Echoelmusic
//
//  Extracted from EchoelBass.swift — keeps view layer separate from audio engine.
//

#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(Observation)
import Observation
#endif

public struct EchoelBassView: View {
    @Bindable private var bass = EchoelBass.shared
    @State private var selectedPreset: String = "808 Sub"

    private let presets: [(String, EchoelBassConfig)] = [
        ("808 Sub", .classic808),
        ("Reese", .reeseMonster),
        ("Moog", .moogBass),
        ("Acid 303", .acid303),
        ("Growl", .dubstepGrowl),
        ("Morph", .morphSweep),
        ("Bio", .bioReactive)
    ]

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            ScrollView {
                VStack(spacing: 16) {
                    presetSelector
                    engineMorphSection
                    filterSection
                    envelopeSection
                    effectsSection
                    keyboardView
                }
                .padding()
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: engineGradient(bass.config.engineA),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)

                Text("BASS")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(EchoelBrand.textPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("EchoelBass")
                    .font(.title2.bold())
                Text("5-Engine Morphing Bass")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Engine indicators
            HStack(spacing: 4) {
                Text(bass.config.engineA.rawValue)
                    .font(.caption2.bold())
                    .foregroundColor(EchoelBrand.textPrimary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: EchoelRadius.sm).fill(engineColor(bass.config.engineA)))

                Text(String(format: "%.0f%%", (1.0 - bass.config.morphPosition) * 100))
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.secondary)
            }

            // Level meter
            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(EchoelBrand.border)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(meterColor)
                            .frame(height: geo.size.height * CGFloat(bass.meterLevel))
                    }
                }
                .frame(width: 20, height: 40)
            }
        }
        .padding()
    }

    private var meterColor: Color {
        if bass.meterLevel > 0.9 { return .red }
        if bass.meterLevel > 0.7 { return .orange }
        return .green
    }

    // MARK: - Preset Selector

    private var presetSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preset")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(presets, id: \.0) { name, preset in
                        Button(action: {
                            selectedPreset = name
                            bass.setPreset(preset)
                        }) {
                            Text(name)
                                .font(.subheadline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: EchoelRadius.sm).fill(selectedPreset == name ? engineColor(preset.engineA) : EchoelBrand.border)
                                )
                                .foregroundColor(selectedPreset == name ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Engine Morph Section

    private var engineMorphSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Engine Morph")
                .font(.headline)

            // Engine A selector
            HStack {
                Text("A:")
                    .font(.caption.bold())
                    .foregroundColor(engineColor(bass.config.engineA))
                Picker("", selection: $bass.config.engineA) {
                    ForEach(BassEngineType.allCases, id: \.self) { engine in
                        Text(engine.rawValue).tag(engine)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Morph slider
            VStack(spacing: 4) {
                HStack {
                    Text(bass.config.engineA.rawValue)
                        .font(.caption2)
                        .foregroundColor(engineColor(bass.config.engineA))
                    Spacer()
                    Text(String(format: "%.0f%%", bass.config.morphPosition * 100))
                        .font(.caption2.monospacedDigit())
                    Spacer()
                    Text(bass.config.engineB.rawValue)
                        .font(.caption2)
                        .foregroundColor(engineColor(bass.config.engineB))
                }
                Slider(value: $bass.config.morphPosition, in: 0...1)
                    .accentColor(engineColor(bass.config.engineA))
            }

            // Engine B selector
            HStack {
                Text("B:")
                    .font(.caption.bold())
                    .foregroundColor(engineColor(bass.config.engineB))
                Picker("", selection: $bass.config.engineB) {
                    ForEach(BassEngineType.allCases, id: \.self) { engine in
                        Text(engine.rawValue).tag(engine)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.indigo.opacity(0.1))
        )
    }

    // MARK: - Filter Section

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Moog Ladder Filter")
                .font(.headline)

            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("Cutoff")
                        .font(.caption)
                    Slider(value: $bass.config.filterCutoff, in: 20...20000)
                        .tint(EchoelBrand.accent)
                    Text(String(format: "%.0f Hz", bass.config.filterCutoff))
                        .font(.caption2.monospacedDigit())
                }

                VStack(spacing: 4) {
                    Text("Resonance")
                        .font(.caption)
                    Slider(value: $bass.config.filterResonance, in: 0...1)
                        .tint(EchoelBrand.accent)
                    Text(String(format: "%.0f%%", bass.config.filterResonance * 100))
                        .font(.caption2.monospacedDigit())
                }

                VStack(spacing: 4) {
                    Text("Env Amt")
                        .font(.caption)
                    Slider(value: $bass.config.filterEnvAmount, in: 0...10000)
                        .tint(EchoelBrand.accent)
                    Text(String(format: "%.0f Hz", bass.config.filterEnvAmount))
                        .font(.caption2.monospacedDigit())
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(EchoelBrand.accent.opacity(0.1))
        )
    }

    // MARK: - Envelope Section

    private var envelopeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Envelope")
                .font(.headline)

            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("Attack").font(.caption)
                    Slider(value: $bass.config.attack, in: 0.001...1.0).tint(.red)
                    Text(String(format: "%.0fms", bass.config.attack * 1000)).font(.caption2.monospacedDigit())
                }
                VStack(spacing: 4) {
                    Text("Decay").font(.caption)
                    Slider(value: $bass.config.decay, in: 0.05...10.0).tint(.red)
                    Text(String(format: "%.1fs", bass.config.decay)).font(.caption2.monospacedDigit())
                }
                VStack(spacing: 4) {
                    Text("Sustain").font(.caption)
                    Slider(value: $bass.config.sustain, in: 0...1).tint(.red)
                    Text(String(format: "%.0f%%", bass.config.sustain * 100)).font(.caption2.monospacedDigit())
                }
                VStack(spacing: 4) {
                    Text("Release").font(.caption)
                    Slider(value: $bass.config.release, in: 0.01...5.0).tint(.red)
                    Text(String(format: "%.2fs", bass.config.release)).font(.caption2.monospacedDigit())
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.1))
        )
    }

    // MARK: - Effects Section

    private var effectsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Output")
                .font(.headline)

            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("Drive").font(.caption)
                    Slider(value: $bass.config.drive, in: 0...1).tint(EchoelBrand.violet)
                    Text(String(format: "%.0f%%", bass.config.drive * 100)).font(.caption2.monospacedDigit())
                }
                VStack(spacing: 4) {
                    Text("Width").font(.caption)
                    Slider(value: $bass.config.stereoWidth, in: 0...1).tint(EchoelBrand.violet)
                    Text(String(format: "%.0f%%", bass.config.stereoWidth * 100)).font(.caption2.monospacedDigit())
                }
                VStack(spacing: 4) {
                    Text("Level").font(.caption)
                    Slider(value: $bass.config.level, in: 0...1).tint(EchoelBrand.violet)
                    Text(String(format: "%.0f%%", bass.config.level * 100)).font(.caption2.monospacedDigit())
                }
            }

            // Glide toggle
            HStack {
                Toggle("Pitch Glide", isOn: $bass.config.glideEnabled)
                    .font(.caption)
                if bass.config.glideEnabled {
                    Slider(value: $bass.config.glideTime, in: 0.01...0.5)
                        .frame(width: 100)
                        .tint(EchoelBrand.amber)
                    Text(String(format: "%.0fms", bass.config.glideTime * 1000))
                        .font(.caption2.monospacedDigit())
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(EchoelBrand.violet.opacity(0.1))
        )
    }

    // MARK: - Keyboard

    private var keyboardView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Play")
                .font(.headline)

            HStack(spacing: 4) {
                ForEach([36, 38, 40, 41, 43, 45, 47, 48], id: \.self) { note in
                    Button(action: { bass.noteOn(note: note) }) {
                        Text(noteNameForMIDI(note))
                            .font(.caption2)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(bass.currentNote == note ? engineColor(bass.config.engineA) : EchoelBrand.border)
                            )
                            .foregroundColor(bass.currentNote == note ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                // Only trigger on first contact (translation == .zero), not continuously
                                if value.translation == .zero {
                                    bass.noteOn(note: note, velocity: 0.8)
                                }
                            }
                            .onEnded { _ in bass.noteOff(note: note) }
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(EchoelBrand.bgElevated)
        )
    }

    // MARK: - Helpers

    private func noteNameForMIDI(_ note: Int) -> String {
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = (note / 12) - 1
        return "\(names[note % 12])\(octave)"
    }

    private func engineColor(_ type: BassEngineType) -> Color {
        switch type {
        case .sub808: return .orange
        case .reese:  return .blue
        case .moog:   return .green
        case .acid:   return .yellow
        case .growl:  return Color(red: 1, green: 0, blue: 1)
        }
    }

    private func engineGradient(_ type: BassEngineType) -> [Color] {
        switch type {
        case .sub808: return [.orange, .red]
        case .reese:  return [.blue, .indigo]
        case .moog:   return [.green, .teal]
        case .acid:   return [.yellow, .orange]
        case .growl:  return [Color(red: 1, green: 0, blue: 1), .purple]
        }
    }
}

// MARK: - Preview

#if DEBUG
struct EchoelBassView_Previews: PreviewProvider {
    static var previews: some View {
        EchoelBassView()
    }
}
#endif
#endif
