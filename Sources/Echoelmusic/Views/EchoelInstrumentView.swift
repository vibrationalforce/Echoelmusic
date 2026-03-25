#if canImport(SwiftUI) && canImport(AVFoundation)
import SwiftUI
import AVFoundation

/// One-screen bio-reactive instrument.
/// Black touch surface = the instrument. Bottom bar = minimal controls.
/// Touch → EchoelSynth.noteOn() directly (6-9ms latency via AVAudioSourceNode).
struct EchoelInstrumentView: View {

    @Environment(AudioEngine.self) var audioEngine
    @Environment(RecordingEngine.self) var recordingEngine

    // MARK: - State

    @State private var touchLocation: CGPoint?
    @State private var lastNote: Int?
    @State private var currentNoteName: String = ""

    // Scale & Key
    @State private var currentScale: TouchMusicalScale = .pentatonicMinor
    @State private var rootNote: UInt8 = 48 // C3
    @State private var rootNoteName: String = "C"

    // Synth Engine (exposed as Sound Worlds)
    @State private var currentWorld: SoundWorld = .underwater

    // BPM
    @State private var bpm: Double = 120.0

    // Bio
    @State private var bioMode: BioMode = .off
    #if os(iOS)
    @State private var smileDetector = SmileDetector()
    #endif

    // Recording
    @State private var isRecording = false
    @State private var recordedFileURL: URL?
    @State private var showExportSheet = false

    // Export Settings
    @State private var exportSampleRate: ExportSampleRate = .sr48000
    @State private var exportBitDepth: ExportBitDepth = .bit24

    // Coherence for ring color
    @Bindable private var bio = EchoelBioEngine.shared

    enum BioMode: String, CaseIterable {
        case off = "Off"
        case pulse = "Pulse"
        case face = "Face"
    }

    /// Immersive sound environments — each one shapes the entire synth character
    enum SoundWorld: String, CaseIterable {
        case underwater = "Underwater"
        case cave = "Cave"
        case atmosphere = "Atmosphere"
        case midnight = "Midnight"
        case glass = "Glass"
        case drift = "Drift"
        case ember = "Ember"
        case void_ = "Void"

        /// Apply this world's synth configuration
        func apply() {
            var cfg = EchoelSynth.shared.config
            switch self {
            case .underwater:
                // Deep, submerged. Heavy lowpass, slow movement, muted highs.
                cfg.engine = .pad
                cfg.padVoiceCount = 7; cfg.padSpread = 30.0; cfg.padChorusRate = 0.15; cfg.padChorusDepth = 0.8
                cfg.filterMode = .lowpass; cfg.filterCutoff = 800.0; cfg.filterResonance = 0.4
                cfg.filterEnvAmount = 1500.0; cfg.filterEnvDecay = 1.2
                cfg.attack = 0.8; cfg.decay = 1.5; cfg.sustain = 0.7; cfg.release = 3.0
                cfg.chorusAmount = 0.7; cfg.drive = 0.0; cfg.stereoWidth = 0.9
                cfg.vibratoRate = 2.0; cfg.vibratoDepth = 0.08

            case .cave:
                // Metallic resonances, long reverb tails, plucked echoes
                cfg.engine = .pluck
                cfg.pluckDamping = 0.15; cfg.pluckDecay = 0.998; cfg.pluckBrightness = 0.6; cfg.pluckStretch = 0.15
                cfg.filterMode = .bandpass; cfg.filterCutoff = 2000.0; cfg.filterResonance = 0.6
                cfg.filterEnvAmount = 3000.0; cfg.filterEnvDecay = 0.8
                cfg.attack = 0.001; cfg.decay = 2.0; cfg.sustain = 0.0; cfg.release = 2.5
                cfg.chorusAmount = 0.3; cfg.drive = 0.05; cfg.stereoWidth = 0.7

            case .atmosphere:
                // Wide, floating pads. Slow shimmer. Fog and wind.
                cfg.engine = .wavetable
                cfg.wtPosition = 0.3; cfg.wtModSpeed = 0.08
                cfg.filterMode = .lowpass; cfg.filterCutoff = 4000.0; cfg.filterResonance = 0.15
                cfg.filterEnvAmount = 2000.0; cfg.filterEnvDecay = 2.0
                cfg.attack = 1.5; cfg.decay = 2.0; cfg.sustain = 0.8; cfg.release = 4.0
                cfg.chorusAmount = 0.5; cfg.drive = 0.0; cfg.stereoWidth = 1.0
                cfg.vibratoRate = 3.0; cfg.vibratoDepth = 0.05

            case .midnight:
                // Dark analog warmth. Detuned, intimate, close.
                cfg.engine = .analog
                cfg.analogDetune = 20.0; cfg.analogVoices = 5; cfg.analogWaveform = 0.0
                cfg.filterMode = .lowpass; cfg.filterCutoff = 1500.0; cfg.filterResonance = 0.25
                cfg.filterEnvAmount = 3000.0; cfg.filterEnvDecay = 0.5
                cfg.attack = 0.03; cfg.decay = 0.6; cfg.sustain = 0.5; cfg.release = 1.0
                cfg.chorusAmount = 0.4; cfg.drive = 0.1; cfg.stereoWidth = 0.6

            case .glass:
                // Crystalline FM bells. Bright, fragile, shimmering.
                cfg.engine = .fm
                cfg.fmRatio = 3.5; cfg.fmDepth = 1.0; cfg.fmFeedback = 0.08; cfg.fmModDecay = 2.5
                cfg.filterMode = .lowpass; cfg.filterCutoff = 12000.0; cfg.filterResonance = 0.05
                cfg.filterEnvAmount = 0.0
                cfg.attack = 0.001; cfg.decay = 3.0; cfg.sustain = 0.0; cfg.release = 2.0
                cfg.chorusAmount = 0.2; cfg.drive = 0.0; cfg.stereoWidth = 0.5

            case .drift:
                // Evolving wavetable textures. Slow morphing. Hypnotic.
                cfg.engine = .wavetable
                cfg.wtPosition = 0.0; cfg.wtModSpeed = 0.25
                cfg.filterMode = .lowpass; cfg.filterCutoff = 6000.0; cfg.filterResonance = 0.2
                cfg.filterEnvAmount = 1000.0; cfg.filterEnvDecay = 1.5
                cfg.attack = 0.3; cfg.decay = 1.0; cfg.sustain = 0.7; cfg.release = 2.0
                cfg.chorusAmount = 0.6; cfg.drive = 0.05; cfg.stereoWidth = 0.8
                cfg.vibratoRate = 4.0; cfg.vibratoDepth = 0.03

            case .ember:
                // Warm distortion, crackling energy. Analog heat.
                cfg.engine = .analog
                cfg.analogDetune = 8.0; cfg.analogVoices = 3; cfg.analogWaveform = 0.4
                cfg.analogPWM = 0.6
                cfg.filterMode = .lowpass; cfg.filterCutoff = 2500.0; cfg.filterResonance = 0.35
                cfg.filterEnvAmount = 5000.0; cfg.filterEnvDecay = 0.2
                cfg.attack = 0.01; cfg.decay = 0.4; cfg.sustain = 0.6; cfg.release = 0.5
                cfg.chorusAmount = 0.1; cfg.drive = 0.3; cfg.stereoWidth = 0.4

            case .void_:
                // Almost nothing. Sub-bass drone. Infinite space.
                cfg.engine = .pad
                cfg.padVoiceCount = 3; cfg.padSpread = 5.0; cfg.padChorusRate = 0.05; cfg.padChorusDepth = 0.3
                cfg.filterMode = .lowpass; cfg.filterCutoff = 300.0; cfg.filterResonance = 0.5
                cfg.filterEnvAmount = 500.0; cfg.filterEnvDecay = 3.0
                cfg.attack = 2.0; cfg.decay = 3.0; cfg.sustain = 0.9; cfg.release = 5.0
                cfg.chorusAmount = 0.2; cfg.drive = 0.0; cfg.stereoWidth = 1.0
                cfg.vibratoRate = 1.0; cfg.vibratoDepth = 0.02
                cfg.octave = -1
            }
            EchoelSynth.shared.config = cfg
        }
    }

    enum ExportSampleRate: Double, CaseIterable {
        case sr44100 = 44100
        case sr48000 = 48000
        case sr96000 = 96000
        var label: String {
            switch self {
            case .sr44100: return "44.1 kHz"
            case .sr48000: return "48 kHz"
            case .sr96000: return "96 kHz"
            }
        }
    }

    enum ExportBitDepth: Int, CaseIterable {
        case bit8 = 8
        case bit16 = 16
        case bit24 = 24
        case bit32 = 32
        var label: String { "\(rawValue)-bit" }
    }

    // MARK: - Root Note Options

    private static let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background — near-black (#0A0A0A)
                Color(red: 0.04, green: 0.04, blue: 0.04)
                    .ignoresSafeArea()

                // Faint octave guide lines
                octaveGuides(in: geometry.size)

                // Touch visualization
                if let location = touchLocation {
                    touchIndicator(at: location)
                }

                // Bottom bar
                VStack {
                    Spacer()
                    bottomBar
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleTouch(at: value.location, in: geometry.size)
                    }
                    .onEnded { _ in
                        handleTouchEnd()
                    }
            )
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .persistentSystemOverlays(.hidden)
        .statusBarHidden()
        .onAppear {
            currentWorld.apply()
        }
        .onChange(of: bioMode) { _, newMode in
            switchBioMode(to: newMode)
        }
        .sheet(isPresented: $showExportSheet) {
            if let url = recordedFileURL {
                ExportSettingsSheet(
                    sourceURL: url,
                    sampleRate: $exportSampleRate,
                    bitDepth: $exportBitDepth
                )
            }
        }
    }

    // MARK: - Touch Handling

    private func handleTouch(at location: CGPoint, in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }

        touchLocation = location

        // X → pitch (scale-quantized, 2 octaves)
        let normalizedX = Float(location.x / size.width)
        let totalDegrees = currentScale.intervals.count * 2 // 2 octaves
        let degree = Int(normalizedX * Float(totalDegrees))
        let midiNote = Int(currentScale.noteInScale(degree: degree, root: rootNote))
        let clampedNote = max(21, min(108, midiNote)) // Piano range

        // Y → filter cutoff (top=bright 12kHz, bottom=dark 200Hz)
        let normalizedY = Float(location.y / size.height)
        let cutoff = 200.0 + (1.0 - normalizedY) * 11800.0
        EchoelSynth.shared.config.filterCutoff = cutoff

        // Note changed? Retrigger
        if clampedNote != lastNote {
            if let last = lastNote {
                EchoelSynth.shared.noteOff(note: last)
            }
            EchoelSynth.shared.noteOn(note: clampedNote, velocity: 0.8)
            lastNote = clampedNote
            currentNoteName = midiNoteName(clampedNote)
            HapticHelper.impact(.light)
        }

        // Bio smile → wavetable morph + brightness
        #if os(iOS)
        if bioMode == .face, smileDetector.isDetecting {
            EchoelSynth.shared.config.wtPosition = smileDetector.smileAmount
        }
        #endif
    }

    private func handleTouchEnd() {
        if let last = lastNote {
            EchoelSynth.shared.noteOff(note: last)
        }
        lastNote = nil

        // Fade out touch indicator
        withAnimation(.easeOut(duration: 0.3)) {
            touchLocation = nil
        }
        currentNoteName = ""
    }

    // MARK: - MIDI Note Name

    private func midiNoteName(_ note: Int) -> String {
        let name = Self.noteNames[note % 12]
        let octave = (note / 12) - 1
        return "\(name)\(octave)"
    }

    // MARK: - Octave Guide Lines

    private func octaveGuides(in size: CGSize) -> some View {
        let totalDegrees = currentScale.intervals.count * 2
        let notesPerOctave = currentScale.intervals.count

        return ForEach(0..<3, id: \.self) { octave in
            let x = CGFloat(octave * notesPerOctave) / CGFloat(totalDegrees) * size.width
            Rectangle()
                .fill(Color.white.opacity(0.03))
                .frame(width: 0.5)
                .position(x: x, y: size.height / 2)
        }
    }

    // MARK: - Touch Indicator

    @ViewBuilder
    private func touchIndicator(at location: CGPoint) -> some View {
        let coherence = CGFloat(bio.smoothCoherence)
        let coherenceColor: Color = bio.isStreaming && bio.dataSource != .fallback
            ? (coherence > 0.6 ? EchoelBrand.coherenceHigh
                : coherence > 0.3 ? EchoelBrand.coherenceMedium
                : EchoelBrand.coherenceLow)
            : Color.white.opacity(0.3)

        ZStack {
            // Coherence ring
            Circle()
                .stroke(coherenceColor.opacity(0.4), lineWidth: 2)
                .frame(width: 44, height: 44)

            // Touch point
            Circle()
                .fill(Color.white.opacity(0.7))
                .frame(width: 30, height: 30)

            // Note name
            Text(currentNoteName)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.4))
                .offset(y: -32)
        }
        .position(location)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            // 1. Loop Record
            recordButton

            Divider().frame(height: 20).opacity(0.3)

            // 2. Key / Scale
            keyScalePicker

            Divider().frame(height: 20).opacity(0.3)

            // 3. Sound World
            worldPicker

            Divider().frame(height: 20).opacity(0.3)

            // 4. BPM
            bpmControl

            Divider().frame(height: 20).opacity(0.3)

            // 5. Bio Mode
            bioModePicker

            Divider().frame(height: 20).opacity(0.3)

            // 6. Export
            exportButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Color.black.opacity(0.85)
                .overlay(
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 0.5),
                    alignment: .top
                )
        )
        .padding(.bottom, 0) // sits at safe area bottom
    }

    // MARK: - Record Button (RC-505 pattern)

    private var recordButton: some View {
        Button {
            toggleRecording()
        } label: {
            ZStack {
                Circle()
                    .fill(isRecording ? EchoelBrand.coral : Color.white.opacity(0.15))
                    .frame(width: 32, height: 32)

                Circle()
                    .fill(isRecording ? EchoelBrand.coral : Color.white.opacity(0.6))
                    .frame(width: isRecording ? 12 : 14, height: isRecording ? 12 : 14)

                if isRecording {
                    Circle()
                        .stroke(EchoelBrand.coral.opacity(0.4), lineWidth: 2)
                        .frame(width: 32, height: 32)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isRecording ? "Stop recording" : "Record")
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
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.7))
                .lineLimit(1)
        }
    }

    // MARK: - Sound World Picker

    private var worldPicker: some View {
        Menu {
            ForEach(SoundWorld.allCases, id: \.self) { world in
                Button {
                    currentWorld = world
                    world.apply()
                } label: {
                    HStack {
                        Text(world.rawValue)
                        if world == currentWorld {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Text(currentWorld.rawValue)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.7))
        }
    }

    // MARK: - BPM Control

    private var bpmControl: some View {
        HStack(spacing: 4) {
            Button {
                bpm = max(40, bpm - 5)
                EchoelCreativeWorkspace.shared.globalBPM = bpm
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.5))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)

            Text("\(Int(bpm))")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.7))
                .frame(minWidth: 28)

            Button {
                bpm = min(300, bpm + 5)
                EchoelCreativeWorkspace.shared.globalBPM = bpm
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.5))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Bio Mode Picker

    private var bioModePicker: some View {
        Menu {
            ForEach(BioMode.allCases, id: \.self) { mode in
                Button {
                    bioMode = mode
                } label: {
                    HStack {
                        Text(mode.rawValue)
                        if mode == bioMode {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Circle()
                    .fill(bioModeColor)
                    .frame(width: 5, height: 5)
                Text("BIO")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.7))
            }
        }
    }

    private var bioModeColor: Color {
        switch bioMode {
        case .off: return Color.white.opacity(0.3)
        case .pulse: return EchoelBrand.coral
        case .face: return EchoelBrand.sky
        }
    }

    // MARK: - Export Button

    private var exportButton: some View {
        Button {
            if recordedFileURL != nil {
                showExportSheet = true
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(recordedFileURL != nil ? Color.white.opacity(0.7) : Color.white.opacity(0.2))
        }
        .buttonStyle(.plain)
        .disabled(recordedFileURL == nil)
        .accessibilityLabel("Export recording")
    }

    // MARK: - Actions

    // Sound world application happens via SoundWorld.apply() — no separate function needed

    private func switchBioMode(to mode: BioMode) {
        // Stop all bio sources first
        #if os(iOS)
        smileDetector.stopDetecting()
        #endif
        // CameraAnalyzer managed by EchoelBioEngine

        switch mode {
        case .off:
            break
        case .pulse:
            // Rear camera PPG — handled by existing bio pipeline
            bio.startStreaming()
        case .face:
            #if os(iOS)
            smileDetector.startDetecting()
            #endif
        }
    }

    @State private var recordingStartTime: Date?

    private func toggleRecording() {
        if isRecording {
            // Stop recording synth output
            audioEngine.stopOutputRecording()
            isRecording = false

            // Quantize recorded file to exact bar length for tight loops
            if let url = recordedFileURL, let startTime = recordingStartTime {
                let duration = Date().timeIntervalSince(startTime)
                let barDuration = (60.0 / bpm) * 4.0 // 4/4 time
                let bars = max(1.0, round(duration / barDuration))
                let quantizedDuration = bars * barDuration
                // Trim or pad to exact bar boundary
                trimToExactDuration(url: url, targetDuration: quantizedDuration)
                log.log(.info, category: .audio, "Loop quantized: \(Int(bars)) bars @ \(Int(bpm)) BPM = \(String(format: "%.2f", quantizedDuration))s")
            }

            HapticHelper.notification(.success)
        } else {
            // Start recording synth output (captures everything the user hears)
            do {
                let url = try audioEngine.startOutputRecording()
                recordedFileURL = url
                recordingStartTime = Date()
                isRecording = true
                HapticHelper.impact(.heavy)
            } catch {
                log.log(.error, category: .audio, "Start output recording failed: \(error.localizedDescription)")
                HapticHelper.notification(.error)
            }
        }
    }

    /// Trim audio file to exact duration for tight BPM-quantized loops
    private func trimToExactDuration(url: URL, targetDuration: TimeInterval) {
        do {
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            let targetFrames = AVAudioFrameCount(targetDuration * format.sampleRate)
            let actualFrames = AVAudioFrameCount(file.length)

            // Only trim if file is longer than target (don't pad)
            guard actualFrames > targetFrames else { return }

            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: targetFrames) else { return }
            try file.read(into: buffer, frameCount: targetFrames)

            // Overwrite file with trimmed version
            let trimmedFile = try AVAudioFile(forWriting: url, settings: format.settings)
            try trimmedFile.write(from: buffer)

            log.log(.info, category: .audio, "Trimmed loop: \(actualFrames) → \(targetFrames) frames")
        } catch {
            log.log(.error, category: .audio, "Loop trim failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Export Settings Sheet

private struct ExportSettingsSheet: View {
    let sourceURL: URL
    @Binding var sampleRate: EchoelInstrumentView.ExportSampleRate
    @Binding var bitDepth: EchoelInstrumentView.ExportBitDepth
    @Environment(\.dismiss) private var dismiss
    @State private var isExporting = false
    @State private var exportedURL: URL?
    @State private var showShareSheet = false
    @State private var exportError: String?

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.04, green: 0.04, blue: 0.04).ignoresSafeArea()

                VStack(spacing: 24) {
                    // Sample Rate
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SAMPLE RATE")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.5))
                            .tracking(2)

                        HStack(spacing: 8) {
                            ForEach(EchoelInstrumentView.ExportSampleRate.allCases, id: \.self) { rate in
                                Button {
                                    sampleRate = rate
                                } label: {
                                    Text(rate.label)
                                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                        .foregroundColor(sampleRate == rate ? .black : Color.white.opacity(0.7))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(sampleRate == rate ? Color.white : Color.white.opacity(0.1))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Bit Depth
                    VStack(alignment: .leading, spacing: 8) {
                        Text("BIT DEPTH")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.5))
                            .tracking(2)

                        HStack(spacing: 8) {
                            ForEach(EchoelInstrumentView.ExportBitDepth.allCases, id: \.self) { depth in
                                Button {
                                    bitDepth = depth
                                } label: {
                                    Text(depth.label)
                                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                        .foregroundColor(bitDepth == depth ? .black : Color.white.opacity(0.7))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(bitDepth == depth ? Color.white : Color.white.opacity(0.1))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // File Info
                    VStack(spacing: 4) {
                        Text("WAV \(sampleRate.label) / \(bitDepth.label)")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.white)

                        if let fileSize = try? FileManager.default.attributesOfItem(atPath: sourceURL.path)[.size] as? Int {
                            let mbSize = Double(fileSize) / 1_048_576.0
                            Text(String(format: "Source: %.1f MB", mbSize))
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(Color.white.opacity(0.4))
                        }
                    }
                    .padding(.top, 8)

                    // Export Button
                    Button {
                        exportWAV()
                    } label: {
                        HStack {
                            if isExporting {
                                ProgressView().controlSize(.small).tint(.black)
                            }
                            Text(isExporting ? "Rendering..." : "Export WAV")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isExporting)

                    if let error = exportError {
                        Text(error)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(EchoelBrand.coral)
                    }

                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color.white.opacity(0.7))
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = exportedURL {
                ShareSheetView(url: url)
            }
        }
    }

    private func exportWAV() {
        isExporting = true
        exportError = nil

        Task {
            do {
                let url = try await renderWAV(
                    source: sourceURL,
                    sampleRate: sampleRate.rawValue,
                    bitDepth: bitDepth.rawValue
                )
                exportedURL = url
                isExporting = false
                showShareSheet = true
            } catch {
                exportError = error.localizedDescription
                isExporting = false
            }
        }
    }

    /// Offline render: CAF source → WAV at target sample rate and bit depth
    private func renderWAV(source: URL, sampleRate: Double, bitDepth: Int) async throws -> URL {
        let sourceFile = try AVAudioFile(forReading: source)
        let sourceFormat = sourceFile.processingFormat

        // Determine PCM format
        let commonFormat: AVAudioCommonFormat
        switch bitDepth {
        case 8: commonFormat = .pcmFormatInt16 // AVFoundation minimum is 16-bit for WAV
        case 16: commonFormat = .pcmFormatInt16
        case 24: commonFormat = .pcmFormatInt32 // 24-bit stored in 32-bit container
        case 32: commonFormat = .pcmFormatFloat32
        default: commonFormat = .pcmFormatFloat32
        }

        guard let outputFormat = AVAudioFormat(
            commonFormat: commonFormat,
            sampleRate: sampleRate,
            channels: min(sourceFormat.channelCount, 2),
            interleaved: commonFormat == .pcmFormatInt16 || commonFormat == .pcmFormatInt32
        ) else {
            throw NSError(domain: "Export", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot create output format"])
        }

        // Output file
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let exportDir = documentsPath.appendingPathComponent("Exports", isDirectory: true)
        try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)

        let rateStr = sampleRate >= 1000 ? "\(Int(sampleRate / 1000))k" : "\(Int(sampleRate))"
        let fileName = "echoelmusic_\(rateStr)_\(bitDepth)bit_\(Int(Date().timeIntervalSince1970)).wav"
        let outputURL = exportDir.appendingPathComponent(fileName)

        // WAV file settings
        var settings: [String: Any] = outputFormat.settings
        settings[AVFormatIDKey] = kAudioFormatLinearPCM
        settings[AVLinearPCMIsFloatKey] = (commonFormat == .pcmFormatFloat32)
        settings[AVLinearPCMBitDepthKey] = bitDepth == 8 ? 16 : bitDepth // Clamp 8→16
        settings[AVSampleRateKey] = sampleRate
        settings[AVNumberOfChannelsKey] = min(Int(sourceFormat.channelCount), 2)

        let outputFile = try AVAudioFile(forWriting: outputURL, settings: settings)

        // Read + convert in chunks
        let bufferSize: AVAudioFrameCount = 8192
        guard let readBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: bufferSize) else {
            throw NSError(domain: "Export", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot create read buffer"])
        }

        // If sample rates differ, use AVAudioConverter
        if abs(sourceFormat.sampleRate - sampleRate) > 1.0 || sourceFormat.commonFormat != commonFormat {
            guard let converter = AVAudioConverter(from: sourceFormat, to: outputFormat) else {
                throw NSError(domain: "Export", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cannot create format converter"])
            }

            let ratio = sampleRate / sourceFormat.sampleRate
            let convertedCapacity = AVAudioFrameCount(Double(bufferSize) * ratio) + 128
            guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: convertedCapacity) else {
                throw NSError(domain: "Export", code: 4, userInfo: [NSLocalizedDescriptionKey: "Cannot create conversion buffer"])
            }

            while sourceFile.framePosition < sourceFile.length {
                try sourceFile.read(into: readBuffer)
                guard readBuffer.frameLength > 0 else { break }

                convertedBuffer.frameLength = 0
                var error: NSError?
                converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                    outStatus.pointee = .haveData
                    return readBuffer
                }
                if let error { throw error }
                if convertedBuffer.frameLength > 0 {
                    try outputFile.write(from: convertedBuffer)
                }
            }
        } else {
            // Same format — direct copy
            while sourceFile.framePosition < sourceFile.length {
                try sourceFile.read(into: readBuffer)
                guard readBuffer.frameLength > 0 else { break }
                try outputFile.write(from: readBuffer)
            }
        }

        let outputSize = try FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int ?? 0
        log.log(.info, category: .audio, "Exported WAV: \(fileName) (\(outputSize / 1024)KB)")
        return outputURL
    }
}

// MARK: - Share Sheet (UIKit bridge)

#if canImport(UIKit)
private struct ShareSheetView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

#endif
