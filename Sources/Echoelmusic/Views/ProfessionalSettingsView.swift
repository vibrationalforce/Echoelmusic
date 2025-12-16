import SwiftUI

/// Professional Settings UI
/// **Complete control panel for all precision features**
struct ProfessionalSettingsView: View {
    @StateObject private var settings = ProfessionalSettingsManager()
    @State private var showingResetAlert = false

    var body: some View {
        NavigationView {
            Form {
                // VIDEO EDITING GRID
                videoGridSection

                // TUNING & CHAMBER TONE
                tuningSection

                // PITCH SHIFTING
                pitchShiftingSection

                // BIO-REACTIVE
                bioReactiveSection

                // MIDI SETTINGS
                midiSection

                // TIMELINE PRECISION
                timelineSection

                // ACTIONS
                actionsSection
            }
            .navigationTitle("Professional Settings")
            .navigationBarTitleDisplayMode(.large)
            .alert("Reset Settings", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    settings.resetToDefaults()
                }
            } message: {
                Text("Reset all settings to default values?")
            }
        }
    }

    // MARK: - Video Grid Section

    private var videoGridSection: some View {
        Section {
            Picker("Video Grid Mode", selection: $settings.videoGridMode) {
                ForEach(VideoGridMode.allCases, id: \.self) { mode in
                    Label(mode.rawValue, systemImage: mode.icon)
                        .tag(mode)
                }
            }
            .pickerStyle(.menu)

            Text(settings.videoGridMode.description)
                .font(.caption)
                .foregroundColor(.secondary)

            if settings.videoGridMode == .heartbeatSync || settings.videoGridMode == .adaptive {
                Picker("Heartbeat Division", selection: $settings.heartbeatGridDivision) {
                    ForEach(HeartbeatGridDivision.allCases, id: \.self) { division in
                        Text(division.rawValue).tag(division)
                    }
                }
            }

            if settings.videoGridMode == .straight || settings.videoGridMode == .adaptive {
                Picker("Fixed Grid Division", selection: $settings.fixedGridDivision) {
                    ForEach(FixedGridDivision.allCases, id: \.self) { division in
                        Text(division.rawValue).tag(division)
                    }
                }
            }

            Toggle("Snap to Grid", isOn: $settings.gridSnapEnabled)

            if settings.gridSnapEnabled {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Snap Tolerance: \(Int(settings.gridTolerance)) ms")
                        .font(.subheadline)

                    Slider(value: $settings.gridTolerance, in: 10...200, step: 10)
                }
            }

        } header: {
            Label("Video Editing Grid", systemImage: "film.stack")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("**Heartbeat Sync**: Grid follows your heart rhythm - natural, bio-reactive editing")
                Text("**Straight Grid**: Traditional fixed musical grid - precise quantization")
                Text("**Adaptive**: Intelligent blend based on HRV coherence")
            }
            .font(.caption)
        }
    }

    // MARK: - Tuning Section

    private var tuningSection: some View {
        Section {
            Picker("Tuning Preset", selection: $settings.tuningPreset) {
                ForEach(TuningPreset.allCases, id: \.self) { preset in
                    Text(preset.rawValue).tag(preset)
                }
            }
            .pickerStyle(.menu)

            if settings.tuningPreset != .custom {
                Text(settings.tuningPreset.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("Chamber Tone (A4)")
                    .font(.subheadline)

                Spacer()

                if settings.tuningPreset == .custom {
                    // Custom frequency input
                    TextField("Hz", value: $settings.chamberToneFrequency, format: .number.precision(.fractionLength(settings.tuningPrecision)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                } else {
                    Text(settings.formatFrequency(settings.chamberToneFrequency))
                }
            }

            Picker("Precision", selection: $settings.tuningPrecision) {
                Text("0.1 Hz (1 decimal)").tag(1)
                Text("0.01 Hz (2 decimals)").tag(2)
                Text("0.001 Hz (3 decimals)").tag(3)
                Text("0.0001 Hz (4 decimals)").tag(4)
            }
            .pickerStyle(.menu)

            Toggle("Microtonal Support", isOn: $settings.microtonalEnabled)

            // Preview: Show some note frequencies
            if settings.tuningPrecision >= 2 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reference Frequencies:")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    HStack {
                        Text("C4")
                        Spacer()
                        Text(settings.formatFrequency(settings.noteToFrequency(note: "C", octave: 4)))
                    }
                    .font(.caption)

                    HStack {
                        Text("A4")
                        Spacer()
                        Text(settings.formatFrequency(settings.chamberToneFrequency))
                    }
                    .font(.caption)

                    HStack {
                        Text("C5")
                        Spacer()
                        Text(settings.formatFrequency(settings.noteToFrequency(note: "C", octave: 5)))
                    }
                    .font(.caption)
                }
                .padding(.top, 8)
            }

        } header: {
            Label("Tuning & Chamber Tone", systemImage: "tuningfork")
        } footer: {
            Text("Chamber tone affects all pitch calculations. Higher precision allows fine-tuning to 0.01 Hz or better.")
                .font(.caption)
        }
    }

    // MARK: - Pitch Shifting Section

    private var pitchShiftingSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Semitones: \(String(format: "%+.2f", settings.pitchShiftSemitones))")
                    .font(.subheadline)

                Slider(value: $settings.pitchShiftSemitones, in: -12...12, step: 0.01)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Fine Tuning: \(settings.pitchShiftCents > 0 ? "+" : "")\(settings.pitchShiftCents) cents")
                    .font(.subheadline)

                Slider(value: Binding(
                    get: { Double(settings.pitchShiftCents) },
                    set: { settings.pitchShiftCents = Int($0) }
                ), in: -100...100, step: 1)
            }

            HStack {
                Text("Total Shift")
                    .font(.subheadline.bold())

                Spacer()

                Text(settings.formatPitchShift())
                    .font(.headline)
                    .foregroundColor(.cyan)
            }

            Picker("Precision", selection: $settings.pitchShiftPrecision) {
                Text("0.1 cents").tag(1)
                Text("0.01 cents").tag(2)
                Text("0.001 cents").tag(3)
            }
            .pickerStyle(.menu)

            Toggle("Preserve Formants", isOn: $settings.formantPreservation)

            // Reset pitch shift
            Button("Reset to ±0") {
                settings.pitchShiftSemitones = 0
                settings.pitchShiftCents = 0
            }
            .foregroundColor(.orange)

        } header: {
            Label("Pitch Shifting", systemImage: "waveform.path.ecg")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("**Formant Preservation**: Maintains vocal character when pitch shifting")
                Text("1 semitone = 100 cents")
                Text("Precision up to 0.001 cents for professional tuning")
            }
            .font(.caption)
        }
    }

    // MARK: - Bio-Reactive Section

    private var bioReactiveSection: some View {
        Section {
            Toggle("Heartbeat Sync", isOn: $settings.heartbeatSyncEnabled)

            Toggle("HRV-Based Timing", isOn: $settings.hrvBasedTiming)

            Toggle("Breath Sync", isOn: $settings.breathSyncEnabled)

            Toggle("Emotion-Based Effects", isOn: $settings.emotionBasedEffects)

        } header: {
            Label("Bio-Reactive Features", systemImage: "heart.circle")
        } footer: {
            Text("Enable bio-reactive features to sync music and video editing with your physiology")
                .font(.caption)
        }
    }

    // MARK: - MIDI Section

    private var midiSection: some View {
        Section {
            Toggle("MPE (MIDI Polyphonic Expression)", isOn: $settings.mpeEnabled)

            VStack(alignment: .leading, spacing: 8) {
                Text("Pitch Bend Range: ±\(settings.pitchBendRange) semitones")
                    .font(.subheadline)

                Slider(value: Binding(
                    get: { Double(settings.pitchBendRange) },
                    set: { settings.pitchBendRange = Int($0) }
                ), in: 1...48, step: 1)
            }

            Picker("Velocity Curve", selection: $settings.velocityCurve) {
                ForEach(VelocityCurve.allCases, id: \.self) { curve in
                    Text(curve.rawValue).tag(curve)
                }
            }
            .pickerStyle(.menu)

        } header: {
            Label("MIDI Settings", systemImage: "pianokeys")
        } footer: {
            Text("MPE allows per-note pitch bend, pressure, and timbre control. Pitch bend range up to ±4 octaves.")
                .font(.caption)
        }
    }

    // MARK: - Timeline Section

    private var timelineSection: some View {
        Section {
            Picker("Timeline Precision", selection: $settings.timelinePrecision) {
                ForEach(TimelinePrecision.allCases, id: \.self) { precision in
                    Text(precision.rawValue).tag(precision)
                }
            }
            .pickerStyle(.menu)

            Text(settings.timelinePrecision.description)
                .font(.caption)
                .foregroundColor(.secondary)

            Toggle("Sample-Accurate Timing", isOn: $settings.sampleAccurateTiming)

        } header: {
            Label("Timeline Precision", systemImage: "clock")
        } footer: {
            Text("Sample-accurate timing provides ultimate precision at 48kHz (0.02ms per sample)")
                .font(.caption)
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        Section {
            Button(role: .destructive) {
                showingResetAlert = true
            } label: {
                Label("Reset All Settings", systemImage: "arrow.counterclockwise")
            }

        } header: {
            Text("Actions")
        }
    }
}

#Preview {
    ProfessionalSettingsView()
}
