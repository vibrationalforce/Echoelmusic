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

    // Synth Engine
    @State private var currentEngine: SynthEngineType = .pad

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
    @State private var showShareSheet = false

    // Coherence for ring color
    @Bindable private var bio = EchoelBioEngine.shared

    enum BioMode: String, CaseIterable {
        case off = "Off"
        case pulse = "Pulse"
        case face = "Face"
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
            applySynthEngine(currentEngine)
        }
        .onChange(of: bioMode) { _, newMode in
            switchBioMode(to: newMode)
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = recordedFileURL {
                ShareSheet(url: url)
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

            // 3. Synth Engine
            enginePicker

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

    // MARK: - Engine Picker

    private var enginePicker: some View {
        Menu {
            ForEach(SynthEngineType.allCases, id: \.self) { engine in
                Button {
                    currentEngine = engine
                    applySynthEngine(engine)
                } label: {
                    HStack {
                        Text(engine.rawValue)
                        if engine == currentEngine {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Text(currentEngine.rawValue)
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
            if let url = recordedFileURL {
                showShareSheet = true
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

    private func applySynthEngine(_ engine: SynthEngineType) {
        var cfg = EchoelSynth.shared.config
        cfg.engine = engine
        // Apply sensible defaults per engine
        switch engine {
        case .analog:
            cfg.analogDetune = 12.0
            cfg.analogVoices = 3
            cfg.attack = 0.01
            cfg.decay = 0.3
            cfg.sustain = 0.7
            cfg.release = 0.4
        case .fm:
            cfg.fmRatio = 2.0
            cfg.fmDepth = 0.5
            cfg.attack = 0.003
            cfg.decay = 1.0
            cfg.sustain = 0.0
            cfg.release = 0.5
        case .wavetable:
            cfg.wtPosition = 0.0
            cfg.wtModSpeed = 0.0
            cfg.attack = 0.05
            cfg.decay = 0.5
            cfg.sustain = 0.6
            cfg.release = 0.8
        case .pluck:
            cfg.pluckDamping = 0.3
            cfg.pluckBrightness = 0.8
            cfg.attack = 0.001
            cfg.decay = 1.0
            cfg.sustain = 0.0
            cfg.release = 0.3
        case .pad:
            cfg.padVoiceCount = 7
            cfg.padSpread = 20.0
            cfg.padChorusRate = 0.3
            cfg.chorusAmount = 0.4
            cfg.attack = 0.5
            cfg.decay = 0.8
            cfg.sustain = 0.8
            cfg.release = 1.5
            cfg.stereoWidth = 0.6
        }
        EchoelSynth.shared.config = cfg
    }

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

    private func toggleRecording() {
        if isRecording {
            // Stop recording synth output
            audioEngine.stopOutputRecording()
            isRecording = false
            HapticHelper.notification(.success)
        } else {
            // Start recording synth output (captures everything the user hears)
            do {
                let url = try audioEngine.startOutputRecording()
                recordedFileURL = url
                isRecording = true
                HapticHelper.impact(.heavy)
            } catch {
                log.log(.error, category: .audio, "Start output recording failed: \(error.localizedDescription)")
                HapticHelper.notification(.error)
            }
        }
    }
}

// MARK: - Share Sheet (UIKit bridge)

#if canImport(UIKit)
private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

#endif
