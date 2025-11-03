import SwiftUI

/// DSP Control View - Configure advanced audio processing
///
/// Features:
/// - Noise Gate control
/// - De-Esser configuration
/// - Limiter settings
/// - Compressor settings
/// - Preset selection
/// - Visual meters
///
/// Usage:
/// ```swift
/// DSPControlView(dsp: dsp)
/// ```
@available(iOS 15.0, *)
struct DSPControlView: View {

    @ObservedObject var dsp: DSPProcessor
    @State private var selectedPreset: AdvancedDSP.Preset = .bypass
    @State private var showingAdvancedSettings = false

    var body: some View {
        Form {
            // MARK: - Presets
            Section {
                Picker("Preset", selection: $selectedPreset) {
                    ForEach(AdvancedDSP.Preset.allCases, id: \.self) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                .onChange(of: selectedPreset) { newPreset in
                    dsp.applyPreset(newPreset)
                }

                Text(selectedPreset.description)
                    .font(.caption)
                    .foregroundColor(.secondary)

            } header: {
                Text("Quick Presets")
            }

            // MARK: - Noise Gate
            Section {
                Toggle("Enable Noise Gate", isOn: Binding(
                    get: { dsp.advanced.noiseGate.enabled },
                    set: { enabled in
                        if enabled {
                            dsp.advanced.enableNoiseGate()
                        } else {
                            dsp.advanced.disableNoiseGate()
                        }
                    }
                ))

                if dsp.advanced.noiseGate.enabled {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Threshold")
                            Spacer()
                            Text(String(format: "%.1f dB", dsp.advanced.noiseGate.threshold))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: Binding(
                            get: { Double(dsp.advanced.noiseGate.threshold) },
                            set: { dsp.advanced.noiseGate.threshold = Float($0) }
                        ), in: -60...(-10))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Ratio")
                            Spacer()
                            Text(String(format: "%.1f:1", dsp.advanced.noiseGate.ratio))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: Binding(
                            get: { Double(dsp.advanced.noiseGate.ratio) },
                            set: { dsp.advanced.noiseGate.ratio = Float($0) }
                        ), in: 2...10, step: 0.5)
                    }
                }

            } header: {
                Text("Noise Gate")
            } footer: {
                Text("Reduces background noise below threshold")
            }

            // MARK: - De-Esser
            Section {
                Toggle("Enable De-Esser", isOn: Binding(
                    get: { dsp.advanced.deEsser.enabled },
                    set: { enabled in
                        if enabled {
                            dsp.advanced.enableDeEsser()
                        } else {
                            dsp.advanced.disableDeEsser()
                        }
                    }
                ))

                if dsp.advanced.deEsser.enabled {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Frequency")
                            Spacer()
                            Text(String(format: "%.0f Hz", dsp.advanced.deEsser.frequency))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: Binding(
                            get: { Double(dsp.advanced.deEsser.frequency) },
                            set: { dsp.advanced.deEsser.frequency = Float($0) }
                        ), in: 4000...10000, step: 500)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Threshold")
                            Spacer()
                            Text(String(format: "%.1f dB", dsp.advanced.deEsser.threshold))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: Binding(
                            get: { Double(dsp.advanced.deEsser.threshold) },
                            set: { dsp.advanced.deEsser.threshold = Float($0) }
                        ), in: -30...(-5))
                    }
                }

            } header: {
                Text("De-Esser")
            } footer: {
                Text("Reduces harsh sibilant sounds (s, sh, ch)")
            }

            // MARK: - Compressor
            Section {
                Toggle("Enable Compressor", isOn: Binding(
                    get: { dsp.advanced.compressor.enabled },
                    set: { enabled in
                        if enabled {
                            dsp.advanced.enableCompressor()
                        } else {
                            dsp.advanced.disableCompressor()
                        }
                    }
                ))

                if dsp.advanced.compressor.enabled {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Threshold")
                            Spacer()
                            Text(String(format: "%.1f dB", dsp.advanced.compressor.threshold))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: Binding(
                            get: { Double(dsp.advanced.compressor.threshold) },
                            set: { dsp.advanced.compressor.threshold = Float($0) }
                        ), in: -40...(-5))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Ratio")
                            Spacer()
                            Text(String(format: "%.1f:1", dsp.advanced.compressor.ratio))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: Binding(
                            get: { Double(dsp.advanced.compressor.ratio) },
                            set: { dsp.advanced.compressor.ratio = Float($0) }
                        ), in: 1...10, step: 0.5)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Makeup Gain")
                            Spacer()
                            Text(String(format: "%.1f dB", dsp.advanced.compressor.makeupGain))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: Binding(
                            get: { Double(dsp.advanced.compressor.makeupGain) },
                            set: { dsp.advanced.compressor.makeupGain = Float($0) }
                        ), in: 0...20)
                    }
                }

            } header: {
                Text("Compressor")
            } footer: {
                Text("Controls dynamic range for consistent levels")
            }

            // MARK: - Limiter
            Section {
                Toggle("Enable Limiter", isOn: Binding(
                    get: { dsp.advanced.limiter.enabled },
                    set: { enabled in
                        if enabled {
                            dsp.advanced.enableLimiter()
                        } else {
                            dsp.advanced.disableLimiter()
                        }
                    }
                ))

                if dsp.advanced.limiter.enabled {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Threshold")
                            Spacer()
                            Text(String(format: "%.1f dB", dsp.advanced.limiter.threshold))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: Binding(
                            get: { Double(dsp.advanced.limiter.threshold) },
                            set: { dsp.advanced.limiter.threshold = Float($0) }
                        ), in: -6...0, step: 0.1)
                    }
                }

            } header: {
                Text("Limiter")
            } footer: {
                Text("Prevents clipping and distortion (brick wall)")
            }

            // MARK: - Advanced Settings
            Section {
                Button {
                    showingAdvancedSettings.toggle()
                } label: {
                    HStack {
                        Label("Advanced Settings", systemImage: "slider.horizontal.3")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .foregroundColor(.primary)
            }

            // MARK: - Info
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    infoRow(icon: "waveform.path", title: "DSP Chain Order", detail: "Gate → De-Esser → Compressor → Limiter")
                    infoRow(icon: "speedometer", title: "Processing", detail: "Real-time @ 48 kHz")
                    infoRow(icon: "cpu", title: "CPU Impact", detail: dspCpuImpact)
                }
            } header: {
                Text("Information")
            }
        }
        .navigationTitle("Audio Processing")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAdvancedSettings) {
            DSPAdvancedSettingsView(dsp: dsp)
        }
    }

    private func infoRow(icon: String, title: String, detail: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)

            Text(title)
                .font(.callout)

            Spacer()

            Text(detail)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var dspCpuImpact: String {
        var activeCount = 0
        if dsp.advanced.noiseGate.enabled { activeCount += 1 }
        if dsp.advanced.deEsser.enabled { activeCount += 1 }
        if dsp.advanced.compressor.enabled { activeCount += 1 }
        if dsp.advanced.limiter.enabled { activeCount += 1 }

        switch activeCount {
        case 0: return "None (bypass)"
        case 1: return "Low (~2%)"
        case 2: return "Medium (~4%)"
        case 3: return "Medium-High (~6%)"
        case 4: return "High (~8%)"
        default: return "Unknown"
        }
    }
}

// MARK: - Advanced Settings View

@available(iOS 15.0, *)
struct DSPAdvancedSettingsView: View {
    @ObservedObject var dsp: DSPProcessor
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                // MARK: - Noise Gate Advanced
                if dsp.advanced.noiseGate.enabled {
                    Section("Noise Gate Timing") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Attack")
                                Spacer()
                                Text(String(format: "%.1f ms", dsp.advanced.noiseGate.attack * 1000))
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: Binding(
                                get: { Double(dsp.advanced.noiseGate.attack) },
                                set: { dsp.advanced.noiseGate.attack = Float($0) }
                            ), in: 0.001...0.050, step: 0.001)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Release")
                                Spacer()
                                Text(String(format: "%.0f ms", dsp.advanced.noiseGate.release * 1000))
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: Binding(
                                get: { Double(dsp.advanced.noiseGate.release) },
                                set: { dsp.advanced.noiseGate.release = Float($0) }
                            ), in: 0.020...0.500, step: 0.010)
                        }
                    }
                }

                // MARK: - De-Esser Advanced
                if dsp.advanced.deEsser.enabled {
                    Section("De-Esser Bandwidth") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Bandwidth")
                                Spacer()
                                Text(String(format: "%.0f Hz", dsp.advanced.deEsser.bandwidth))
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: Binding(
                                get: { Double(dsp.advanced.deEsser.bandwidth) },
                                set: { dsp.advanced.deEsser.bandwidth = Float($0) }
                            ), in: 500...4000, step: 100)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Ratio")
                                Spacer()
                                Text(String(format: "%.1f:1", dsp.advanced.deEsser.ratio))
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: Binding(
                                get: { Double(dsp.advanced.deEsser.ratio) },
                                set: { dsp.advanced.deEsser.ratio = Float($0) }
                            ), in: 1...5, step: 0.5)
                        }
                    }
                }

                // MARK: - Compressor Advanced
                if dsp.advanced.compressor.enabled {
                    Section("Compressor Timing") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Attack")
                                Spacer()
                                Text(String(format: "%.1f ms", dsp.advanced.compressor.attack * 1000))
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: Binding(
                                get: { Double(dsp.advanced.compressor.attack) },
                                set: { dsp.advanced.compressor.attack = Float($0) }
                            ), in: 0.001...0.100, step: 0.001)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Release")
                                Spacer()
                                Text(String(format: "%.0f ms", dsp.advanced.compressor.release * 1000))
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: Binding(
                                get: { Double(dsp.advanced.compressor.release) },
                                set: { dsp.advanced.compressor.release = Float($0) }
                            ), in: 0.020...1.000, step: 0.010)
                        }
                    }
                }

                // MARK: - Limiter Advanced
                if dsp.advanced.limiter.enabled {
                    Section("Limiter Timing") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Release")
                                Spacer()
                                Text(String(format: "%.0f ms", dsp.advanced.limiter.release * 1000))
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: Binding(
                                get: { Double(dsp.advanced.limiter.release) },
                                set: { dsp.advanced.limiter.release = Float($0) }
                            ), in: 0.010...0.200, step: 0.005)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Lookahead")
                                Spacer()
                                Text(String(format: "%.1f ms", dsp.advanced.limiter.lookahead * 1000))
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: Binding(
                                get: { Double(dsp.advanced.limiter.lookahead) },
                                set: { dsp.advanced.limiter.lookahead = Float($0) }
                            ), in: 0.001...0.020, step: 0.001)
                        }
                    }
                }
            }
            .navigationTitle("Advanced DSP")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - DSP Processor Wrapper

/// Wrapper to make AdvancedDSP observable
@available(iOS 15.0, *)
class DSPProcessor: ObservableObject {
    @Published var advanced: AdvancedDSP

    init(sampleRate: Double = 48000.0) {
        self.advanced = AdvancedDSP(sampleRate: sampleRate)
    }

    func applyPreset(_ preset: AdvancedDSP.Preset) {
        advanced.applyPreset(preset)
        objectWillChange.send()
    }

    func process(audioBuffer: AVAudioPCMBuffer) {
        advanced.process(audioBuffer: audioBuffer)
    }
}

// MARK: - Preview

@available(iOS 15.0, *)
struct DSPControlView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DSPControlView(dsp: DSPProcessor())
        }
    }
}
