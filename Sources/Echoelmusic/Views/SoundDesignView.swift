#if canImport(SwiftUI)
import SwiftUI

/// Debug panel exposing ALL synthesis parameters as sliders.
/// Michael tunes on device, then we bake the values as defaults.
struct SoundDesignView: View {

    @Environment(SoundscapeEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // Filter
                    paramSection("Filter") {
                        logSlider("Cutoff", value: filterCutoff, range: 20...18000, unit: "Hz")
                        linSlider("Resonance", value: filterResonance, range: 0...0.95)
                        linSlider("LFO → Filter", value: lfoFilterDepth, range: 0...1)
                    }

                    // LFO
                    paramSection("LFO") {
                        linSlider("Rate", value: lfoRate, range: 0.01...10, unit: "Hz")
                    }

                    // Entrainment
                    paramSection("Entrainment") {
                        Picker("Band", selection: entrainmentBand) {
                            ForEach(BrainwaveBand.allCases, id: \.self) { band in
                                Text(band.rawValue).tag(band)
                            }
                        }
                        .pickerStyle(.segmented)
                        linSlider("Depth", value: entrainmentDepth, range: 0...1)
                    }

                    // Oscillator
                    paramSection("Oscillator") {
                        linSlider("Harmonicity", value: harmonicity, range: 0.3...1)
                        linSlider("Brightness", value: brightness, range: 0...1)
                        linSlider("Noise", value: noiseLevel, range: 0...0.3)
                    }

                    // Envelope
                    paramSection("Envelope") {
                        linSlider("Attack", value: attack, range: 0.01...3, unit: "s")
                        linSlider("Decay", value: decay, range: 0.01...2, unit: "s")
                        linSlider("Sustain", value: sustain, range: 0...1)
                        linSlider("Release", value: release, range: 0.1...5, unit: "s")
                    }

                    // Reverb
                    paramSection("Reverb") {
                        linSlider("Mix", value: reverbMix, range: 0...1)
                        linSlider("Decay", value: reverbDecay, range: 0.1...5, unit: "s")
                    }

                    // Voice Mix
                    paramSection("Voice Mix") {
                        @Bindable var eng = engine
                        linSlider("Root", value: $eng.mixRoot, range: 0...0.6)
                        linSlider("Third", value: $eng.mixFifth, range: 0...0.6)
                        linSlider("Fifth", value: $eng.mixOctave, range: 0...0.6)
                        linSlider("Octave", value: $eng.mixHigh, range: 0...0.6)
                    }
                }
                .padding()
            }
            .navigationTitle("Sound Design")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Parameter Bindings (write to all 4 DDSP voices)

    private var filterCutoff: Binding<Float> {
        Binding(
            get: { engine.voiceRoot.filterCutoff },
            set: { v in for voice in engine.allVoices { voice.filterCutoff = v } }
        )
    }

    private var filterResonance: Binding<Float> {
        Binding(
            get: { engine.voiceRoot.filter.resonance },
            set: { v in for voice in engine.allVoices { voice.filter.resonance = v } }
        )
    }

    private var lfoFilterDepth: Binding<Float> {
        Binding(
            get: { engine.voiceRoot.lfoToFilterDepth },
            set: { v in for voice in engine.allVoices { voice.lfoToFilterDepth = v } }
        )
    }

    private var lfoRate: Binding<Float> {
        Binding(
            get: { engine.voiceRoot.filterLFO.rate },
            set: { v in for voice in engine.allVoices { voice.filterLFO.rate = v } }
        )
    }

    private var entrainmentBand: Binding<BrainwaveBand> {
        Binding(
            get: { engine.voiceRoot.entrainment.band },
            set: { v in for voice in engine.allVoices { voice.entrainment.band = v } }
        )
    }

    private var entrainmentDepth: Binding<Float> {
        Binding(
            get: { engine.voiceRoot.entrainment.depth },
            set: { v in for voice in engine.allVoices { voice.entrainment.depth = v } }
        )
    }

    private var harmonicity: Binding<Float> {
        Binding(
            get: { engine.voiceRoot.harmonicity },
            set: { v in for voice in engine.allVoices { voice.harmonicity = v } }
        )
    }

    private var brightness: Binding<Float> {
        Binding(
            get: { engine.voiceRoot.brightness },
            set: { v in for voice in engine.allVoices { voice.brightness = v } }
        )
    }

    private var noiseLevel: Binding<Float> {
        Binding(
            get: { engine.voiceRoot.noiseLevel },
            set: { v in for voice in engine.allVoices { voice.noiseLevel = v } }
        )
    }

    private var attack: Binding<Float> {
        Binding(
            get: { engine.voiceRoot.attack },
            set: { v in for voice in engine.allVoices { voice.attack = v } }
        )
    }

    private var decay: Binding<Float> {
        Binding(
            get: { engine.voiceRoot.decay },
            set: { v in for voice in engine.allVoices { voice.decay = v } }
        )
    }

    private var sustain: Binding<Float> {
        Binding(
            get: { engine.voiceRoot.sustain },
            set: { v in for voice in engine.allVoices { voice.sustain = v } }
        )
    }

    private var release: Binding<Float> {
        Binding(
            get: { engine.voiceRoot.release },
            set: { v in for voice in engine.allVoices { voice.release = v } }
        )
    }

    private var reverbMix: Binding<Float> {
        Binding(
            get: { engine.voiceRoot.reverbMix },
            set: { v in for voice in engine.allVoices { voice.reverbMix = v } }
        )
    }

    private var reverbDecay: Binding<Float> {
        Binding(
            get: { engine.voiceRoot.reverbDecay },
            set: { v in for voice in engine.allVoices { voice.reverbDecay = v } }
        )
    }

    // MARK: - UI Components

    @ViewBuilder
    private func paramSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.3))
                .kerning(1.5)
            VStack(spacing: 6) { content() }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.04)))
        }
    }

    @ViewBuilder
    private func linSlider(_ label: String, value: Binding<Float>, range: ClosedRange<Float>, unit: String = "") -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 80, alignment: .leading)
            Slider(value: value, in: range)
                .tint(.white.opacity(0.3))
            Text(String(format: "%.2f", value.wrappedValue) + (unit.isEmpty ? "" : " \(unit)"))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.25))
                .frame(width: 60, alignment: .trailing)
        }
    }

    @ViewBuilder
    private func logSlider(_ label: String, value: Binding<Float>, range: ClosedRange<Float>, unit: String = "") -> some View {
        // Logarithmic slider for frequency parameters
        let logMin = log2(max(1, range.lowerBound))
        let logMax = log2(range.upperBound)
        let logBinding = Binding<Float>(
            get: { log2(max(1, value.wrappedValue)) },
            set: { value.wrappedValue = pow(2, $0) }
        )
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 80, alignment: .leading)
            Slider(value: logBinding, in: logMin...logMax)
                .tint(.white.opacity(0.3))
            Text(String(format: "%.0f %@", value.wrappedValue, unit))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.25))
                .frame(width: 60, alignment: .trailing)
        }
    }
}
#endif
