#if canImport(AVFoundation)
//
//  TR808BassSynthView.swift
//  Echoelmusic
//
//  Extracted from TR808BassSynth.swift — keeps view layer separate from audio engine.
//

#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(Observation)
import Observation
#endif

public struct TR808BassSynthView: View {
    @Bindable private var synth = TR808BassSynth.shared
    @State private var selectedPreset: String = "Classic 808"

    private let presets: [(String, TR808BassConfig)] = [
        ("Classic 808", .classic808),
        ("Hard Trap", .hardTrap),
        ("Deep Sub", .deepSub),
        ("Distorted", .distorted808),
        ("Long Slide", .longSlide)
    ]

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    // Preset selector
                    presetSelector

                    // Pitch Glide section
                    pitchGlideSection

                    // Envelope section
                    envelopeSection

                    // Tone section
                    toneSection

                    // Drum Kit (SynthPresetLibrary integration)
                    drumKitSection

                    // Step Sequencer
                    sequencerSection

                    // Bass Keyboard
                    keyboardView
                }
                .padding()
            }
        }
    }

    private var headerView: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)

                Text("808")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(EchoelBrand.textPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("EchoelBeat")
                    .font(.title2.bold())

                Text("Drum Machine + Sub-Bass Engine")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Level meter
            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(EchoelBrand.border)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(meterColor)
                            .frame(height: geo.size.height * CGFloat(synth.meterLevel))
                    }
                }
                .frame(width: 20, height: 40)

                Text(String(format: "%.0f", synth.meterLevel * 100))
                    .font(.caption2.monospacedDigit())
            }
        }
        .padding()
    }

    private var meterColor: Color {
        if synth.meterLevel > 0.9 { return .red }
        if synth.meterLevel > 0.7 { return .orange }
        return .green
    }

    private var presetSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preset")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(presets, id: \.0) { name, preset in
                        Button(action: {
                            selectedPreset = name
                            synth.setPreset(preset)
                        }) {
                            Text(name)
                                .font(.subheadline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(selectedPreset == name ? Color.orange : EchoelBrand.border)
                                )
                                .foregroundColor(selectedPreset == name ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var pitchGlideSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Pitch Glide")
                    .font(.headline)

                Spacer()

                Toggle("", isOn: $synth.config.pitchGlideEnabled)
                    .labelsHidden()
            }

            if synth.config.pitchGlideEnabled {
                VStack(spacing: 16) {
                    // Glide Time
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Glide Time")
                                .font(.caption)
                            Spacer()
                            Text(String(format: "%.0f ms", synth.config.pitchGlideTime * 1000))
                                .font(.caption.monospacedDigit())
                        }
                        Slider(value: $synth.config.pitchGlideTime, in: 0.01...0.5)
                            .tint(.orange)
                    }

                    // Glide Range
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Glide Range")
                                .font(.caption)
                            Spacer()
                            Text(String(format: "%.0f st", synth.config.pitchGlideRange))
                                .font(.caption.monospacedDigit())
                        }
                        Slider(value: $synth.config.pitchGlideRange, in: -24...0)
                            .tint(.orange)
                    }

                    // Glide Curve
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Curve")
                                .font(.caption)
                            Spacer()
                            Text(synth.config.pitchGlideCurve > 0.5 ? "Exponential" : "Linear")
                                .font(.caption)
                        }
                        Slider(value: $synth.config.pitchGlideCurve, in: 0...1)
                            .tint(.orange)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
        )
    }

    private var envelopeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Envelope")
                .font(.headline)

            HStack(spacing: 20) {
                // Click
                VStack(spacing: 4) {
                    Text("Click")
                        .font(.caption)
                    Slider(value: $synth.config.clickAmount, in: 0...1)
                        .tint(.red)
                    Text(String(format: "%.0f%%", synth.config.clickAmount * 100))
                        .font(.caption2.monospacedDigit())
                }

                // Decay
                VStack(spacing: 4) {
                    Text("Decay")
                        .font(.caption)
                    Slider(value: $synth.config.decay, in: 0.1...5)
                        .tint(.red)
                    Text(String(format: "%.1fs", synth.config.decay))
                        .font(.caption2.monospacedDigit())
                }

                // Release
                VStack(spacing: 4) {
                    Text("Release")
                        .font(.caption)
                    Slider(value: $synth.config.release, in: 0.01...2)
                        .tint(.red)
                    Text(String(format: "%.2fs", synth.config.release))
                        .font(.caption2.monospacedDigit())
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.1))
        )
    }

    private var toneSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tone")
                .font(.headline)

            HStack(spacing: 20) {
                // Drive
                VStack(spacing: 4) {
                    Text("Drive")
                        .font(.caption)
                    Slider(value: $synth.config.drive, in: 0...1)
                        .tint(.purple)
                    Text(String(format: "%.0f%%", synth.config.drive * 100))
                        .font(.caption2.monospacedDigit())
                }

                // Filter
                VStack(spacing: 4) {
                    Text("Filter")
                        .font(.caption)
                    Slider(value: $synth.config.filterCutoff, in: 20...2000)
                        .tint(.purple)
                    Text(String(format: "%.0f Hz", synth.config.filterCutoff))
                        .font(.caption2.monospacedDigit())
                }

                // Level
                VStack(spacing: 4) {
                    Text("Level")
                        .font(.caption)
                    Slider(value: $synth.config.level, in: 0...1)
                        .tint(.purple)
                    Text(String(format: "%.0f%%", synth.config.level * 100))
                        .font(.caption2.monospacedDigit())
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.purple.opacity(0.1))
        )
    }

    private var keyboardView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Play")
                .font(.headline)

            // Simple octave keyboard (C1 - C2 for bass)
            HStack(spacing: 4) {
                ForEach([36, 38, 40, 41, 43, 45, 47, 48], id: \.self) { note in
                    Button(action: {}) {
                        Text(noteNameForMIDI(note))
                            .font(.caption2)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(synth.currentNote == note ? Color.orange : EchoelBrand.border)
                            )
                            .foregroundColor(synth.currentNote == note ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                synth.noteOn(note: note, velocity: 0.8)
                            }
                            .onEnded { _ in
                                synth.noteOff(note: note)
                            }
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

    private func noteNameForMIDI(_ note: Int) -> String {
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = (note / 12) - 1
        let noteName = names[note % 12]
        return "\(noteName)\(octave)"
    }

    // MARK: - Drum Kit Section

    private var drumKitSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Drum Kit")
                    .font(.headline)
                Spacer()
                Text(synth.currentDrumKit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Genre kit selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SynthPresetLibrary.GenreKit.allCases, id: \.rawValue) { genre in
                        Button(action: {
                            synth.loadDrumKit(genre: genre)
                        }) {
                            Text(genre.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(synth.currentDrumKit == genre.rawValue ? Color.cyan : EchoelBrand.border)
                                )
                                .foregroundColor(synth.currentDrumKit == genre.rawValue ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Drum pads (4x4 grid)
            if !synth.drumSlots.isEmpty {
                let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 4)
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(Array(synth.drumSlots.prefix(16).enumerated()), id: \.element.id) { index, slot in
                        Button(action: {}) {
                            VStack(spacing: 2) {
                                Text(drumPadShortName(slot.name))
                                    .font(.system(size: 10, weight: .bold))
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(drumPadColor(for: slot.category))
                            )
                            .foregroundColor(EchoelBrand.textPrimary)
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in
                                    synth.triggerDrum(slotIndex: index, velocity: 0.8)
                                }
                        )
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.cyan.opacity(0.1))
        )
    }

    // MARK: - Step Sequencer Section

    private var sequencerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with transport
            HStack {
                Text("Sequencer")
                    .font(.headline)

                Spacer()

                HStack(spacing: 4) {
                    Text("BPM")
                        .font(.caption)
                    Text(String(format: "%.0f", synth.sequencerBPM))
                        .font(.caption.monospacedDigit().bold())
                }

                Slider(value: $synth.sequencerBPM, in: 60...200, step: 1)
                    .frame(width: 100)
                    .tint(.cyan)

                Button(action: {
                    if synth.isSequencerPlaying {
                        synth.stopSequencer()
                    } else {
                        synth.startSequencer()
                    }
                }) {
                    Image(systemName: synth.isSequencerPlaying ? "stop.fill" : "play.fill")
                        .font(.title3)
                        .foregroundColor(synth.isSequencerPlaying ? .red : .green)
                }
                .buttonStyle(.plain)
            }

            // Pattern presets
            HStack(spacing: 6) {
                ForEach(TR808BassSynth.BeatPatternPreset.allCases, id: \.rawValue) { preset in
                    Button(preset.rawValue) {
                        synth.loadPatternPreset(preset)
                    }
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(EchoelBrand.border))
                    .buttonStyle(.plain)
                }
            }

            // Step grid
            if !synth.drumSlots.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(spacing: 2) {
                        // Step numbers header
                        HStack(spacing: 2) {
                            Text("")
                                .frame(width: 60)
                            ForEach(0..<16, id: \.self) { step in
                                Text("\(step + 1)")
                                    .font(.system(size: 8).monospacedDigit())
                                    .frame(width: 24, height: 14)
                                    .foregroundColor(synth.sequencerStep == step && synth.isSequencerPlaying ? .cyan : .secondary)
                            }
                        }

                        // Track rows (first 8 drum slots)
                        ForEach(Array(synth.drumSlots.prefix(8).enumerated()), id: \.element.id) { trackIdx, slot in
                            HStack(spacing: 2) {
                                Text(drumPadShortName(slot.name))
                                    .font(.system(size: 9, weight: .medium))
                                    .frame(width: 60, alignment: .trailing)
                                    .lineLimit(1)

                                ForEach(0..<16, id: \.self) { step in
                                    let isActive = trackIdx < synth.sequencerPattern.tracks.count &&
                                                   step < synth.sequencerPattern.stepCount &&
                                                   synth.sequencerPattern.tracks[trackIdx][step].isActive

                                    Button(action: {
                                        synth.sequencerPattern.toggle(track: trackIdx, step: step)
                                    }) {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(isActive ? drumPadColor(for: slot.category) : EchoelBrand.bgElevated)
                                            .frame(width: 24, height: 24)
                                            .overlay(
                                                Group {
                                                    if synth.sequencerStep == step && synth.isSequencerPlaying {
                                                        RoundedRectangle(cornerRadius: 3)
                                                            .stroke(Color.white, lineWidth: 1)
                                                    }
                                                }
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(EchoelBrand.bgElevated)
        )
    }

    // MARK: - View Helpers

    private func drumPadShortName(_ name: String) -> String {
        var result = name
        for (old, new) in [("Acoustic ", ""), ("Noise ", "N."), ("808 ", ""),
                           ("Distorted ", "Dist "), ("Closed ", "Cl."),
                           ("Open ", "Op."), ("Finger ", ""), ("Big Room ", "Big ")] {
            result = result.replacingOccurrences(of: old, with: new)
        }
        return String(result.prefix(8))
    }

    private func drumPadColor(for category: String) -> Color {
        switch category {
        case "kick": return Color.red.opacity(0.7)
        case "snare", "clap": return Color.orange.opacity(0.7)
        case "hihat", "closed", "open", "ride", "crash", "pedal": return Color.cyan.opacity(0.7)
        case "tom", "floor", "mid", "high": return Color.blue.opacity(0.7)
        default: return Color.purple.opacity(0.7)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct TR808BassSynthView_Previews: PreviewProvider {
    static var previews: some View {
        TR808BassSynthView()
    }
}
#endif
#endif
