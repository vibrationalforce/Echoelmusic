import SwiftUI

/// Detailed Professional Synthesizer UI
/// FULL USER CONTROL over every parameter
/// Oscillators, Filters, Envelopes, LFOs, Modulation Matrix
/// NOT AI - USER shapes every sound!
@MainActor
struct DetailedSynthView: View {

    @ObservedObject var synthEngine: SynthEngine
    @State private var selectedTab: SynthTab = .oscillators

    enum SynthTab: String, CaseIterable {
        case oscillators = "Oscillators"
        case filter = "Filter"
        case envelopes = "Envelopes"
        case lfos = "LFOs"
        case modulation = "Modulation"
        case presets = "Presets"

        var icon: String {
            switch self {
            case .oscillators: return "waveform"
            case .filter: return "slider.horizontal.3"
            case .envelopes: return "chart.xyaxis.line"
            case .lfos: return "waveform.path.ecg"
            case .modulation: return "arrow.triangle.branch"
            case .presets: return "folder"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Tab Selector
            HStack(spacing: 0) {
                ForEach(SynthTab.allCases, id: \.self) { tab in
                    Button(action: { selectedTab = tab }) {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                            Text(tab.rawValue)
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selectedTab == tab ? Color.blue.opacity(0.2) : Color.clear)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color.secondary.opacity(0.05))

            Divider()

            // Content
            ScrollView {
                Group {
                    switch selectedTab {
                    case .oscillators:
                        OscillatorsView(synthEngine: synthEngine)
                    case .filter:
                        FilterView(synthEngine: synthEngine)
                    case .envelopes:
                        EnvelopesView(synthEngine: synthEngine)
                    case .lfos:
                        LFOsView(synthEngine: synthEngine)
                    case .modulation:
                        ModulationMatrixView(synthEngine: synthEngine)
                    case .presets:
                        PresetsView(synthEngine: synthEngine)
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(synthEngine.currentPatch.name)
                    .font(.title2)
                    .bold()

                Text(synthEngine.currentPatch.type.rawValue.capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Synthesis Type Picker
            Picker("Type", selection: Binding(
                get: { synthEngine.currentPatch.type },
                set: { type in
                    var patch = synthEngine.currentPatch
                    patch.type = type
                    synthEngine.loadPatch(patch)
                }
            )) {
                ForEach(SynthEngine.SynthesisType.allCases, id: \.self) { type in
                    Text(type.rawValue.capitalized).tag(type)
                }
            }
            .pickerStyle(.menu)

            // Save Patch
            Button(action: savePatch) {
                Label("Save Patch", systemImage: "square.and.arrow.down")
            }
        }
        .padding()
    }

    private func savePatch() {
        let patch = synthEngine.savePatch(name: synthEngine.currentPatch.name)
        DebugConsole.shared.info("Saved synth patch: \(patch.name)", category: "Synth")
    }
}

// MARK: - Oscillators View

struct OscillatorsView: View {
    @ObservedObject var synthEngine: SynthEngine

    var body: some View {
        VStack(spacing: 24) {
            ForEach(0..<3, id: \.self) { index in
                OscillatorPanel(
                    oscillator: Binding(
                        get: { synthEngine.currentPatch.oscillators[index] },
                        set: { osc in
                            var patch = synthEngine.currentPatch
                            patch.oscillators[index] = osc
                            synthEngine.loadPatch(patch)
                        }
                    ),
                    index: index
                )
            }
        }
    }
}

struct OscillatorPanel: View {
    @Binding var oscillator: SynthEngine.Oscillator
    let index: Int

    var body: some View {
        GroupBox(label: Label("Oscillator \(index + 1)", systemImage: "waveform")) {
            VStack(spacing: 16) {
                // Enable Toggle
                Toggle("Enable", isOn: $oscillator.enabled)
                    .toggleStyle(.switch)

                if oscillator.enabled {
                    // Waveform Picker
                    Picker("Waveform", selection: $oscillator.waveform) {
                        ForEach(SynthEngine.Oscillator.Waveform.allCases, id: \.self) { waveform in
                            Label(waveform.rawValue.capitalized, systemImage: waveformIcon(waveform))
                                .tag(waveform)
                        }
                    }
                    .pickerStyle(.segmented)

                    // Tuning
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tuning")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack {
                            VStack {
                                Text("Octave")
                                    .font(.caption2)
                                Stepper("\(oscillator.octave)", value: $oscillator.octave, in: -3...3)
                                    .labelsHidden()
                            }

                            VStack {
                                Text("Semitone")
                                    .font(.caption2)
                                Stepper("\(oscillator.semitone)", value: $oscillator.semitone, in: -12...12)
                                    .labelsHidden()
                            }

                            VStack {
                                Text("Cents")
                                    .font(.caption2)
                                Slider(value: $oscillator.cents, in: -100...100)
                                    .frame(width: 100)
                                Text(String(format: "%.1f", oscillator.cents))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // Level
                    ParameterSlider(
                        label: "Level",
                        value: $oscillator.level,
                        range: 0...1,
                        format: "%.2f"
                    )

                    // Unison
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Unison")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack {
                            Stepper("Voices: \(oscillator.unisonVoices)", value: $oscillator.unisonVoices, in: 1...8)

                            Spacer()

                            ParameterSlider(
                                label: "Detune",
                                value: $oscillator.unisonDetune,
                                range: 0...50,
                                format: "%.1f"
                            )
                            .frame(width: 200)
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func waveformIcon(_ waveform: SynthEngine.Oscillator.Waveform) -> String {
        switch waveform {
        case .sine: return "waveform"
        case .saw: return "waveform.path"
        case .square: return "square"
        case .triangle: return "triangle"
        case .pulse: return "rectangle"
        case .noise: return "waveform.path.ecg"
        }
    }
}

// MARK: - Filter View

struct FilterView: View {
    @ObservedObject var synthEngine: SynthEngine

    var body: some View {
        GroupBox(label: Label("Filter", systemImage: "slider.horizontal.3")) {
            VStack(spacing: 16) {
                Toggle("Enable", isOn: Binding(
                    get: { synthEngine.currentPatch.filter.enabled },
                    set: { enabled in
                        var patch = synthEngine.currentPatch
                        patch.filter.enabled = enabled
                        synthEngine.loadPatch(patch)
                    }
                ))

                if synthEngine.currentPatch.filter.enabled {
                    // Filter Type
                    Picker("Type", selection: Binding(
                        get: { synthEngine.currentPatch.filter.type },
                        set: { type in
                            var patch = synthEngine.currentPatch
                            patch.filter.type = type
                            synthEngine.loadPatch(patch)
                        }
                    )) {
                        ForEach(SynthEngine.Filter.FilterType.allCases, id: \.self) { type in
                            Text(type.rawValue.capitalized).tag(type)
                        }
                    }
                    .pickerStyle(.menu)

                    // Cutoff
                    VStack(alignment: .leading) {
                        Text("Cutoff: \(String(format: "%.0f Hz", synthEngine.currentPatch.filter.cutoff))")
                            .font(.caption)

                        Slider(
                            value: Binding(
                                get: { synthEngine.currentPatch.filter.cutoff },
                                set: { cutoff in
                                    var patch = synthEngine.currentPatch
                                    patch.filter.cutoff = cutoff
                                    synthEngine.loadPatch(patch)
                                }
                            ),
                            in: 20...20000
                        )
                    }

                    // Resonance
                    ParameterSlider(
                        label: "Resonance",
                        value: Binding(
                            get: { synthEngine.currentPatch.filter.resonance },
                            set: { res in
                                var patch = synthEngine.currentPatch
                                patch.filter.resonance = res
                                synthEngine.loadPatch(patch)
                            }
                        ),
                        range: 0...1,
                        format: "%.2f"
                    )

                    // Key Tracking
                    ParameterSlider(
                        label: "Key Tracking",
                        value: Binding(
                            get: { synthEngine.currentPatch.filter.keyTracking },
                            set: { tracking in
                                var patch = synthEngine.currentPatch
                                patch.filter.keyTracking = tracking
                                synthEngine.loadPatch(patch)
                            }
                        ),
                        range: 0...1,
                        format: "%.2f"
                    )
                }
            }
            .padding()
        }
    }
}

// MARK: - Envelopes View

struct EnvelopesView: View {
    @ObservedObject var synthEngine: SynthEngine

    var body: some View {
        VStack(spacing: 24) {
            // Amp Envelope
            EnvelopePanel(
                title: "Amplitude Envelope",
                envelope: Binding(
                    get: { synthEngine.currentPatch.ampEnvelope },
                    set: { env in
                        var patch = synthEngine.currentPatch
                        patch.ampEnvelope = env
                        synthEngine.loadPatch(patch)
                    }
                )
            )

            // Filter Envelope
            EnvelopePanel(
                title: "Filter Envelope",
                envelope: Binding(
                    get: { synthEngine.currentPatch.filterEnvelope },
                    set: { env in
                        var patch = synthEngine.currentPatch
                        patch.filterEnvelope = env
                        synthEngine.loadPatch(patch)
                    }
                )
            )
        }
    }
}

struct EnvelopePanel: View {
    let title: String
    @Binding var envelope: SynthEngine.Envelope

    var body: some View {
        GroupBox(label: Label(title, systemImage: "chart.xyaxis.line")) {
            VStack(spacing: 16) {
                // ADSR Sliders
                ParameterSlider(label: "Attack", value: $envelope.attack, range: 0...10, format: "%.3f s")
                ParameterSlider(label: "Decay", value: $envelope.decay, range: 0...10, format: "%.3f s")
                ParameterSlider(label: "Sustain", value: $envelope.sustain, range: 0...1, format: "%.2f")
                ParameterSlider(label: "Release", value: $envelope.release, range: 0...10, format: "%.3f s")

                // Curves
                HStack {
                    VStack {
                        Text("Attack Curve")
                            .font(.caption)
                        Picker("", selection: $envelope.attackCurve) {
                            Text("Linear").tag(SynthEngine.Envelope.Curve.linear)
                            Text("Exp").tag(SynthEngine.Envelope.Curve.exponential)
                            Text("Log").tag(SynthEngine.Envelope.Curve.logarithmic)
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack {
                        Text("Decay Curve")
                            .font(.caption)
                        Picker("", selection: $envelope.decayCurve) {
                            Text("Linear").tag(SynthEngine.Envelope.Curve.linear)
                            Text("Exp").tag(SynthEngine.Envelope.Curve.exponential)
                            Text("Log").tag(SynthEngine.Envelope.Curve.logarithmic)
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - LFOs View

struct LFOsView: View {
    @ObservedObject var synthEngine: SynthEngine

    var body: some View {
        VStack(spacing: 24) {
            ForEach(0..<2, id: \.self) { index in
                LFOPanel(
                    lfo: Binding(
                        get: { synthEngine.currentPatch.lfos[index] },
                        set: { lfo in
                            var patch = synthEngine.currentPatch
                            patch.lfos[index] = lfo
                            synthEngine.loadPatch(patch)
                        }
                    ),
                    index: index
                )
            }
        }
    }
}

struct LFOPanel: View {
    @Binding var lfo: SynthEngine.LFO
    let index: Int

    var body: some View {
        GroupBox(label: Label("LFO \(index + 1)", systemImage: "waveform.path.ecg")) {
            VStack(spacing: 16) {
                Toggle("Enable", isOn: $lfo.enabled)

                if lfo.enabled {
                    // Waveform
                    Picker("Waveform", selection: $lfo.waveform) {
                        ForEach(SynthEngine.Oscillator.Waveform.allCases, id: \.self) { waveform in
                            Text(waveform.rawValue.capitalized).tag(waveform)
                        }
                    }
                    .pickerStyle(.segmented)

                    // Rate
                    ParameterSlider(label: "Rate", value: $lfo.rate, range: 0.01...20, format: "%.2f Hz")

                    // Depth
                    ParameterSlider(label: "Depth", value: $lfo.depth, range: 0...1, format: "%.2f")

                    // Tempo Sync
                    Toggle("Sync to Tempo", isOn: $lfo.syncToTempo)

                    if lfo.syncToTempo {
                        Picker("Division", selection: $lfo.tempoMultiplier) {
                            Text("Whole").tag(SynthEngine.LFO.TempoMultiplier.whole)
                            Text("Half").tag(SynthEngine.LFO.TempoMultiplier.half)
                            Text("Quarter").tag(SynthEngine.LFO.TempoMultiplier.quarter)
                            Text("Eighth").tag(SynthEngine.LFO.TempoMultiplier.eighth)
                            Text("Sixteenth").tag(SynthEngine.LFO.TempoMultiplier.sixteenth)
                        }
                        .pickerStyle(.menu)
                    }

                    // Destination
                    Picker("Destination", selection: $lfo.destination) {
                        ForEach(SynthEngine.LFO.LFODestination.allCases, id: \.self) { dest in
                            Text(dest.rawValue.capitalized).tag(dest)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .padding()
        }
    }
}

// MARK: - Modulation Matrix View

struct ModulationMatrixView: View {
    @ObservedObject var synthEngine: SynthEngine

    var body: some View {
        VStack {
            Text("Modulation Matrix")
                .font(.title2)

            Text("Advanced modulation routing")
                .font(.caption)
                .foregroundColor(.secondary)

            // TODO: Implement modulation matrix UI
            Text("Coming soon...")
                .foregroundColor(.secondary)
                .padding()
        }
    }
}

// MARK: - Presets View

struct PresetsView: View {
    @ObservedObject var synthEngine: SynthEngine
    @State private var showSaveDialog = false
    @State private var newPresetName = ""

    var body: some View {
        VStack {
            Text("Preset Manager")
                .font(.title2)

            Button(action: { showSaveDialog.toggle() }) {
                Label("Save Current Patch", systemImage: "square.and.arrow.down")
            }
            .sheet(isPresented: $showSaveDialog) {
                VStack {
                    Text("Save Patch")
                        .font(.headline)

                    TextField("Patch Name", text: $newPresetName)
                        .textFieldStyle(.roundedBorder)
                        .padding()

                    HStack {
                        Button("Cancel") {
                            showSaveDialog = false
                        }

                        Button("Save") {
                            _ = synthEngine.savePatch(name: newPresetName)
                            showSaveDialog = false
                            DebugConsole.shared.info("Saved patch: \(newPresetName)", category: "Synth")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .frame(width: 300, height: 150)
            }

            Text("Saved presets will appear here")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
        }
    }
}

// MARK: - Parameter Slider Component

struct ParameterSlider: View {
    let label: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let format: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(String(format: format, value))
                    .font(.caption)
                    .foregroundColor(.blue)
            }

            Slider(value: $value, in: range)
        }
    }
}
