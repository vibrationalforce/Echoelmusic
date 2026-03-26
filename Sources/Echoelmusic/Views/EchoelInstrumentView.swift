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

    // Motion control
    #if canImport(CoreMotion)
    @State private var motionController = MotionMusicController()
    #endif

    // Coherence for ring color
    @Bindable private var bio = EchoelBioEngine.shared

    enum BioMode: String, CaseIterable {
        case off = "Off"
        case pulse = "Pulse"
        case face = "Face"
    }

    /// Immersive sound environments — each one shapes the entire synth character
    enum SoundWorld: String, CaseIterable {
        // Nature
        case underwater = "Underwater"
        case jungle = "Jungle"
        case waterfall = "Waterfall"
        case ocean = "Ocean"
        case forest = "Forest"
        case rain = "Rain"
        // Spaces
        case cave = "Cave"
        case atmosphere = "Atmosphere"
        case midnight = "Midnight"
        // Textures
        case glass = "Glass"
        case drift = "Drift"
        case silk = "Silk"
        case ember = "Ember"
        case aurora = "Aurora"
        case void_ = "Void"

        /// Touch-reactive particle style matched to sound character
        var particleStyle: TouchParticleView.ParticleStyle {
            switch self {
            case .underwater, .ocean, .waterfall: return .water
            case .jungle, .forest: return .organic
            case .rain: return .rain
            case .atmosphere, .aurora, .void_: return .stars
            case .midnight, .ember: return .warmth
            case .glass, .drift, .silk: return .crystal
            case .cave: return .cave
            }
        }

        /// Apply this world's synth configuration
        @MainActor func apply() {
            // Start fresh — reset octave to 0, all params explicit
            var cfg = EchoelSynthConfig()
            switch self {

            // ─── NATURE ───────────────────────────────────────

            case .underwater:
                // Evidence: Water sounds = strongest stress reduction (Buxton 2021 PNAS).
                // Pink noise spectrum 100-4kHz. Slow amplitude modulation matching
                // respiratory rate ~0.1Hz (6 breaths/min = resonance frequency,
                // Lehrer & Gevirtz 2014). Heavy lowpass simulates acoustic absorption.
                cfg.engine = .pad
                cfg.padVoiceCount = 7; cfg.padSpread = 35.0
                cfg.padChorusRate = 0.1; cfg.padChorusDepth = 0.9
                cfg.filterMode = .lowpass; cfg.filterCutoff = 500.0; cfg.filterResonance = 0.4
                cfg.filterEnvAmount = 1000.0; cfg.filterEnvDecay = 2.0
                cfg.attack = 1.5; cfg.decay = 2.5; cfg.sustain = 0.7; cfg.release = 4.5
                cfg.chorusAmount = 0.85; cfg.stereoWidth = 0.95
                cfg.vibratoRate = 0.1; cfg.vibratoDepth = 0.12 // ~6/min respiratory match
                cfg.octave = -1

            case .jungle:
                // Evidence: Birdsong = strongest positive affect (Buxton 2021, Ratcliffe 2013).
                // Bird frequencies 1.5-8kHz, most species peak 2-5kHz.
                // FM synthesis with carrier in birdsong range, short notes (100-500ms),
                // rapid pitch sweeps simulate natural bird call patterns.
                cfg.engine = .fm
                cfg.fmRatio = 3.0; cfg.fmDepth = 0.9; cfg.fmFeedback = 0.1; cfg.fmModDecay = 0.3
                cfg.filterMode = .bandpass; cfg.filterCutoff = 3000.0; cfg.filterResonance = 0.3
                cfg.filterEnvAmount = 4000.0; cfg.filterEnvDecay = 0.2
                cfg.attack = 0.003; cfg.decay = 0.4; cfg.sustain = 0.05; cfg.release = 0.6
                cfg.chorusAmount = 0.45; cfg.stereoWidth = 0.85
                cfg.vibratoRate = 8.0; cfg.vibratoDepth = 0.2 // Rapid pitch modulation

            case .waterfall:
                // Evidence: Running water broadband noise 200-2000Hz peak energy.
                // Pink noise spectrum with gentle HF roll-off. Strong stress reduction.
                // Wide chorus simulates turbulent water scattering.
                cfg.engine = .pad
                cfg.padVoiceCount = 7; cfg.padSpread = 45.0
                cfg.padChorusRate = 0.6; cfg.padChorusDepth = 1.0
                cfg.filterMode = .lowpass; cfg.filterCutoff = 2500.0; cfg.filterResonance = 0.25
                cfg.filterEnvAmount = 3500.0; cfg.filterEnvDecay = 0.5
                cfg.attack = 0.2; cfg.decay = 0.6; cfg.sustain = 0.65; cfg.release = 2.0
                cfg.chorusAmount = 0.95; cfg.drive = 0.06; cfg.stereoWidth = 1.0
                cfg.vibratoRate = 4.0; cfg.vibratoDepth = 0.1

            case .ocean:
                // Evidence: Ocean waves modulate amplitude at 0.05-0.15Hz (6-12 cycles/min),
                // matching human respiratory rate. This entrainment is the mechanism
                // behind ocean sound stress reduction (Buxton 2021).
                // Slow wavetable morph simulates tidal harmonic shifts.
                cfg.engine = .wavetable
                cfg.wtPosition = 0.5; cfg.wtModSpeed = 0.03
                cfg.filterMode = .lowpass; cfg.filterCutoff = 1000.0; cfg.filterResonance = 0.18
                cfg.filterEnvAmount = 2500.0; cfg.filterEnvDecay = 3.5
                cfg.attack = 2.5; cfg.decay = 3.5; cfg.sustain = 0.7; cfg.release = 6.0
                cfg.chorusAmount = 0.65; cfg.stereoWidth = 1.0
                cfg.vibratoRate = 0.08; cfg.vibratoDepth = 0.08 // ~5/min tidal breath

            case .forest:
                // Evidence: Forest bathing (Shinrin-yoku) reduces cortisol, BP,
                // sympathetic activity (Li 2010). Forest audio = wood resonance +
                // mid-frequency complexity. Pluck engine simulates wood/branch sounds.
                // Gentle damping, organic decay, dappled frequency content.
                cfg.engine = .pluck
                cfg.pluckDamping = 0.4; cfg.pluckDecay = 0.995; cfg.pluckBrightness = 0.45
                cfg.pluckStretch = 0.1
                cfg.filterMode = .lowpass; cfg.filterCutoff = 3500.0; cfg.filterResonance = 0.15
                cfg.filterEnvAmount = 1500.0; cfg.filterEnvDecay = 0.6
                cfg.attack = 0.001; cfg.decay = 1.8; cfg.sustain = 0.0; cfg.release = 2.0
                cfg.chorusAmount = 0.3; cfg.stereoWidth = 0.65
                cfg.vibratoRate = 1.5; cfg.vibratoDepth = 0.015

            case .rain:
                // Evidence: Rain ≈ pink noise. Zhou et al. 2012 showed pink noise
                // enhances stable sleep and sleep quality. Gentle 1/f spectrum.
                // FM droplets in high register with long gentle release tails.
                cfg.engine = .fm
                cfg.fmRatio = 7.0; cfg.fmDepth = 0.35; cfg.fmFeedback = 0.0; cfg.fmModDecay = 0.06
                cfg.filterMode = .lowpass; cfg.filterCutoff = 7000.0; cfg.filterResonance = 0.08
                cfg.filterEnvAmount = 1500.0; cfg.filterEnvDecay = 0.08
                cfg.attack = 0.001; cfg.decay = 1.0; cfg.sustain = 0.0; cfg.release = 2.5
                cfg.chorusAmount = 0.55; cfg.stereoWidth = 1.0
                cfg.vibratoRate = 0.3; cfg.vibratoDepth = 0.008

            // ─── SPACES ───────────────────────────────────────

            case .cave:
                // Metallic resonances. Plucked stalactites. Long echoes.
                cfg.engine = .pluck
                cfg.pluckDamping = 0.1; cfg.pluckDecay = 0.999; cfg.pluckBrightness = 0.7
                cfg.pluckStretch = 0.2
                cfg.filterMode = .bandpass; cfg.filterCutoff = 2200.0; cfg.filterResonance = 0.65
                cfg.filterEnvAmount = 3000.0; cfg.filterEnvDecay = 1.0
                cfg.attack = 0.001; cfg.decay = 3.0; cfg.sustain = 0.0; cfg.release = 3.5
                cfg.chorusAmount = 0.35; cfg.drive = 0.03; cfg.stereoWidth = 0.75

            case .atmosphere:
                // High altitude. Thin air. Wide floating shimmer.
                cfg.engine = .wavetable
                cfg.wtPosition = 0.3; cfg.wtModSpeed = 0.06
                cfg.filterMode = .lowpass; cfg.filterCutoff = 5000.0; cfg.filterResonance = 0.12
                cfg.filterEnvAmount = 2000.0; cfg.filterEnvDecay = 2.5
                cfg.attack = 1.8; cfg.decay = 2.5; cfg.sustain = 0.8; cfg.release = 5.0
                cfg.chorusAmount = 0.55; cfg.stereoWidth = 1.0
                cfg.vibratoRate = 2.5; cfg.vibratoDepth = 0.04

            case .midnight:
                // Dark analog warmth. Detuned, intimate, close. Velvet.
                cfg.engine = .analog
                cfg.analogDetune = 22.0; cfg.analogVoices = 5; cfg.analogWaveform = 0.0
                cfg.filterMode = .lowpass; cfg.filterCutoff = 1200.0; cfg.filterResonance = 0.2
                cfg.filterEnvAmount = 2500.0; cfg.filterEnvDecay = 0.6
                cfg.attack = 0.05; cfg.decay = 0.8; cfg.sustain = 0.5; cfg.release = 1.5
                cfg.chorusAmount = 0.45; cfg.drive = 0.08; cfg.stereoWidth = 0.65
                cfg.vibratoRate = 3.0; cfg.vibratoDepth = 0.02

            // ─── TEXTURES ─────────────────────────────────────

            case .glass:
                // Crystalline FM bells. Bright, fragile, shimmering.
                cfg.engine = .fm
                cfg.fmRatio = 3.5; cfg.fmDepth = 1.2; cfg.fmFeedback = 0.06; cfg.fmModDecay = 3.0
                cfg.filterMode = .lowpass; cfg.filterCutoff = 14000.0; cfg.filterResonance = 0.03
                cfg.filterEnvAmount = 0.0
                cfg.attack = 0.001; cfg.decay = 4.0; cfg.sustain = 0.0; cfg.release = 3.0
                cfg.chorusAmount = 0.25; cfg.stereoWidth = 0.55

            case .drift:
                // Evolving wavetable. Slow morphing. Hypnotic tide.
                cfg.engine = .wavetable
                cfg.wtPosition = 0.0; cfg.wtModSpeed = 0.2
                cfg.filterMode = .lowpass; cfg.filterCutoff = 6000.0; cfg.filterResonance = 0.18
                cfg.filterEnvAmount = 1200.0; cfg.filterEnvDecay = 1.8
                cfg.attack = 0.4; cfg.decay = 1.2; cfg.sustain = 0.7; cfg.release = 2.5
                cfg.chorusAmount = 0.65; cfg.drive = 0.03; cfg.stereoWidth = 0.85
                cfg.vibratoRate = 3.5; cfg.vibratoDepth = 0.025

            case .silk:
                // Ultra-smooth pad. No edges. Pure warmth. Like fabric.
                cfg.engine = .pad
                cfg.padVoiceCount = 7; cfg.padSpread = 15.0
                cfg.padChorusRate = 0.2; cfg.padChorusDepth = 0.6
                cfg.filterMode = .lowpass; cfg.filterCutoff = 2500.0; cfg.filterResonance = 0.08
                cfg.filterEnvAmount = 800.0; cfg.filterEnvDecay = 1.5
                cfg.attack = 1.0; cfg.decay = 1.5; cfg.sustain = 0.85; cfg.release = 3.0
                cfg.chorusAmount = 0.5; cfg.stereoWidth = 0.7
                cfg.vibratoRate = 2.0; cfg.vibratoDepth = 0.015

            case .ember:
                // Warm distortion, crackling analog energy. Fireplace.
                cfg.engine = .analog
                cfg.analogDetune = 10.0; cfg.analogVoices = 3; cfg.analogWaveform = 0.35
                cfg.analogPWM = 0.55
                cfg.filterMode = .lowpass; cfg.filterCutoff = 2200.0; cfg.filterResonance = 0.3
                cfg.filterEnvAmount = 4500.0; cfg.filterEnvDecay = 0.25
                cfg.attack = 0.008; cfg.decay = 0.5; cfg.sustain = 0.55; cfg.release = 0.6
                cfg.chorusAmount = 0.15; cfg.drive = 0.35; cfg.stereoWidth = 0.45
                cfg.vibratoRate = 4.5; cfg.vibratoDepth = 0.02

            case .aurora:
                // Northern lights. Slow spectral sweep. Ethereal color shifts.
                cfg.engine = .wavetable
                cfg.wtPosition = 0.7; cfg.wtModSpeed = 0.12
                cfg.filterMode = .lowpass; cfg.filterCutoff = 3500.0; cfg.filterResonance = 0.25
                cfg.filterEnvAmount = 3500.0; cfg.filterEnvDecay = 2.0
                cfg.attack = 1.0; cfg.decay = 2.0; cfg.sustain = 0.75; cfg.release = 4.0
                cfg.chorusAmount = 0.7; cfg.stereoWidth = 1.0
                cfg.vibratoRate = 1.5; cfg.vibratoDepth = 0.06

            case .void_:
                // Almost nothing. Sub-bass pressure. Infinite darkness.
                cfg.engine = .pad
                cfg.padVoiceCount = 3; cfg.padSpread = 4.0
                cfg.padChorusRate = 0.03; cfg.padChorusDepth = 0.2
                cfg.filterMode = .lowpass; cfg.filterCutoff = 250.0; cfg.filterResonance = 0.55
                cfg.filterEnvAmount = 400.0; cfg.filterEnvDecay = 4.0
                cfg.attack = 3.0; cfg.decay = 4.0; cfg.sustain = 0.9; cfg.release = 6.0
                cfg.chorusAmount = 0.15; cfg.stereoWidth = 1.0
                cfg.vibratoRate = 0.5; cfg.vibratoDepth = 0.015
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

    /// Represents one active finger on the instrument surface
    struct ActiveTouchPoint: Identifiable {
        let id: String
        let location: CGPoint
        let midiNote: Int
        let noteName: String
    }

    // Active touches for multi-touch visualization
    @State private var activeTouches: [ActiveTouchPoint] = []

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

                // Rhythm orbs — bouncing in tempo
                // Visual space — clean, no distractions

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
                    // Bio smile → wavetable morph
                    #if os(iOS)
                    if bioMode == .face, smileDetector.isDetecting {
                        EchoelSynth.shared.config.wtPosition = smileDetector.smileAmount
                    }
                    #endif

                    // Motion sensors → sound shaping
                    #if canImport(CoreMotion)
                    if motionController.isActive {
                        // Tilt adds filter offset on top of touch Y-axis
                        let motionFilterOffset = (motionController.filterAmount - 0.5) * 3000.0
                        EchoelSynth.shared.config.filterCutoff += motionFilterOffset

                        // Rotation → chorus/vibrato intensity
                        EchoelSynth.shared.config.vibratoDepth = motionController.rotationIntensity * 0.3

                        // Shake → momentary drive burst
                        if motionController.shakeDetected {
                            EchoelSynth.shared.config.drive = 0.5
                        } else {
                            // Restore world default drive
                        }
                    }
                    #endif
                }
                #endif

                // Touch-reactive particles — like touching water, stars, or clouds
                TouchParticleView(
                    touches: activeTouches,
                    worldStyle: currentWorld.particleStyle
                )

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
            currentWorld.apply()
            #if canImport(CoreMotion)
            motionController.start()
            #endif
        }
        .onDisappear {
            #if canImport(CoreMotion)
            motionController.stop()
            #endif
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

    // Touch handling now via MultiTouchInstrumentView (UIKit polyphonic)
    // All noteOn/noteOff happens in MultiTouchInstrumentView.Coordinator

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
    private func touchIndicator(at location: CGPoint, noteName: String = "") -> some View {
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
            if !noteName.isEmpty {
                Text(noteName)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.4))
                    .offset(y: -32)
            }
        }
        .position(location)
        .allowsHitTesting(false)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            // 1. Loop Record
            recordButton

            // 1b. Retrospective Capture (save last 4 bars)
            captureButton

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

    // MARK: - Capture Button (Retrospective — save last N bars)

    private var captureButton: some View {
        Button {
            captureRetrospective()
        } label: {
            Image(systemName: "arrow.uturn.backward.circle")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.white.opacity(0.5))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Capture last 4 bars")
    }

    private func captureRetrospective() {
        do {
            let url = try audioEngine.retrospectiveBuffer.capture(bars: 4, bpm: bpm)
            recordedFileURL = url
            HapticHelper.notification(.success)
            log.log(.info, category: .audio, "Retrospective capture: 4 bars saved")
        } catch {
            log.log(.error, category: .audio, "Capture failed: \(error.localizedDescription)")
            HapticHelper.notification(.error)
        }
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
