#if canImport(SwiftUI)
import SwiftUI
#if canImport(Metal)
import Metal
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif

// MARK: - Generative Music Engine

/// Bio-reactive generative music. Chords + arpeggio respond to coherence/HRV/HR.
///
/// High coherence → major chords, slow arpeggios, warm timbre
/// Low coherence  → minor chords, faster arpeggios, brighter timbre
@MainActor
@Observable
final class BioMusicEngine {
    var isPlaying = false
    var activeNotes: [Int] = []
    var currentChordIndex = 0

    private var arpTimer: Timer?
    private var bioFeedTimer: Timer?
    private var cameraFeedTimer: Timer?
    private var chordTimer: Timer?
    private var arpIndex = 0

    private let bio = EchoelBioEngine.shared

    private let warmChords: [[Int]] = [
        [48, 52, 55, 59, 62],   // Cmaj9
        [53, 57, 60, 64],       // Fmaj7
        [57, 60, 64, 67],       // Am7
        [55, 59, 62, 66],       // G6/9
    ]

    private let coolChords: [[Int]] = [
        [48, 51, 55, 58, 62],   // Cm9
        [53, 56, 60, 63],       // Fm7
        [56, 60, 63, 67],       // Abmaj7
        [55, 58, 62, 65],       // Gm7
    ]

    func start() {
        guard !isPlaying else { return }

        let synth = EchoelSynth.shared

        // Verify synth is connected before playing
        guard synth.isReady else {
            log.log(.error, category: .audio, "BioMusicEngine: synth not connected to audio engine")
            return
        }

        isPlaying = true
        arpIndex = 0
        currentChordIndex = 0

        synth.setPreset(.warmPad)

        // Small delay to let preset apply before first note
        arpTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isPlaying else { return }
                self.playNextArpNote()
                self.scheduleArp()
            }
        }

        chordTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.advanceChord()
            }
        }

        bioFeedTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 15.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.feedBio()
            }
        }
    }

    func stop() {
        isPlaying = false
        invalidateTimers()

        let synth = EchoelSynth.shared
        for note in activeNotes {
            synth.noteOff(note: note)
        }
        activeNotes.removeAll()
    }

    #if os(iOS)
    func startCameraFeed(analyzer: CameraAnalyzer) {
        cameraFeedTimer?.invalidate()
        cameraFeedTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard analyzer.bpmConfidence > 0.3, analyzer.estimatedBPM > 40 else { return }
                self.bio.snapshot.heartRate = analyzer.estimatedBPM
                self.bio.smoothHeartRate = self.bio.smoothHeartRate * 0.85 + analyzer.estimatedBPM * 0.15
                if analyzer.rmssd > 0 {
                    self.bio.snapshot.hrvRMSSD = analyzer.rmssd
                    self.bio.snapshot.hrvNormalized = min(analyzer.rmssd / 100.0, 1.0)
                    self.bio.smoothHRV = self.bio.snapshot.hrvNormalized
                }
                self.bio.dataSource = .camera
                if !self.bio.isStreaming { self.bio.startStreaming() }
            }
        }
    }

    func stopCameraFeed() {
        cameraFeedTimer?.invalidate()
        cameraFeedTimer = nil
    }
    #endif

    func stopAll() {
        stop()
        #if os(iOS)
        stopCameraFeed()
        #endif
    }

    // MARK: - Private

    private func invalidateTimers() {
        arpTimer?.invalidate()
        arpTimer = nil
        chordTimer?.invalidate()
        chordTimer = nil
        bioFeedTimer?.invalidate()
        bioFeedTimer = nil
    }

    private func advanceChord() {
        guard isPlaying else { return }
        let chords = bio.smoothCoherence > 0.5 ? warmChords : coolChords
        currentChordIndex = (currentChordIndex + 1) % chords.count
        arpIndex = 0
        scheduleArp()
    }

    private func scheduleArp() {
        arpTimer?.invalidate()
        let coherence = bio.smoothCoherence
        let interval = max(0.25, min(0.8, 0.8 - coherence * 0.5))

        arpTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.playNextArpNote()
            }
        }
    }

    private func playNextArpNote() {
        guard isPlaying else { return }

        let coherence = bio.smoothCoherence
        let hrv = Float(bio.smoothHRV)
        let chords = coherence > 0.5 ? warmChords : coolChords
        let chord = chords[currentChordIndex % chords.count]
        guard !chord.isEmpty else { return }

        // Release oldest note if too many active (keep max 3 ringing)
        while activeNotes.count > 2 {
            let oldest = activeNotes.removeFirst()
            EchoelSynth.shared.noteOff(note: oldest)
        }

        let note = chord[arpIndex % chord.count]
        arpIndex += 1

        let velocity = max(0.2, min(0.85, Float(0.35 + hrv * 0.4)))
        EchoelSynth.shared.noteOn(note: note, velocity: velocity)
        activeNotes.append(note)
    }

    private func feedBio() {
        guard isPlaying else { return }
        let params = bio.audioParameters()
        EchoelSynth.shared.updateBio(
            coherence: params.coherence,
            heartRate: params.heartRate,
            hrv: params.hrv,
            breathPhase: params.breathPhase
        )
    }
}

// MARK: - BioMusicView

struct BioMusicView: View {

    @Bindable private var bio = EchoelBioEngine.shared
    @State private var engine = BioMusicEngine()
    @State private var cameraActive = false
    @State private var cameraError: String?
    #if os(iOS)
    @State private var cameraAnalyzer = CameraAnalyzer()
    @State private var cameraManager: CameraManager?
    #endif

    var body: some View {
        ZStack {
            coherenceGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                statusBar
                    .padding(.horizontal, EchoelSpacing.md)
                    .padding(.top, EchoelSpacing.sm)

                Spacer()

                if !cameraActive {
                    fingerPlacementGuide
                } else {
                    breathingRing
                }

                Spacer()

                if cameraActive {
                    #if os(iOS)
                    signalStabilityBar
                        .padding(.horizontal, EchoelSpacing.xl)
                        .padding(.bottom, EchoelSpacing.sm)
                    #endif

                    metricsRow
                        .padding(.horizontal, EchoelSpacing.xl)

                    Spacer()
                }

                if let error = cameraError {
                    Text(error)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(EchoelBrand.coral.opacity(0.8))
                        .padding(.horizontal, EchoelSpacing.lg)
                        .padding(.bottom, EchoelSpacing.sm)
                }

                playControl
                    .padding(.bottom, EchoelSpacing.lg)

                Text("Not a medical device. For self-observation only.")
                    .font(.system(size: 8))
                    .foregroundStyle(Color.white.opacity(0.2))
                    .padding(.bottom, EchoelSpacing.sm)
            }
        }
        .onDisappear {
            engine.stopAll()
            #if os(iOS)
            teardownCamera()
            #endif
        }
    }

    // MARK: - Finger Placement Guide

    /// Visual instruction: place finger over rear camera + flash
    private var fingerPlacementGuide: some View {
        VStack(spacing: 24) {
            // Phone rear camera illustration
            ZStack {
                // Phone body
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 140, height: 200)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )

                VStack(spacing: 10) {
                    // Camera lens cluster
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.03))
                            .frame(width: 60, height: 60)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                            )

                        // Camera lens
                        Circle()
                            .fill(Color.white.opacity(0.06))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                            .overlay(
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(width: 12, height: 12)
                            )

                        // Flash LED
                        Circle()
                            .fill(Color.yellow.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .offset(x: 18, y: -18)
                    }
                    .offset(y: -30)

                    // Finger overlay — translucent red circle over camera area
                    ZStack {
                        // Finger tip shape
                        Capsule()
                            .fill(Color.red.opacity(0.15))
                            .frame(width: 80, height: 100)
                            .overlay(
                                Capsule()
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )

                        Text("Finger")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.red.opacity(0.5))
                    }
                    .offset(y: -50)
                }
            }

            VStack(spacing: 8) {
                Text("Place your finger")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.7))

                Text("Cover the rear camera and flash\nwith your fingertip. Press gently.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.35))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)

                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red.opacity(0.4))
                        .frame(width: 6, height: 6)
                    Text("Light passes through skin to detect pulse")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.25))
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Background

    private var coherenceGradient: some View {
        let c = bio.smoothCoherence
        let tint: Color = c > 0.7 ? EchoelBrand.coherenceHigh
            : c > 0.4 ? EchoelBrand.coherenceMedium
            : EchoelBrand.coherenceLow

        return LinearGradient(
            colors: [Color.black, tint.opacity(engine.isPlaying ? 0.08 : 0)],
            startPoint: .top,
            endPoint: .bottom
        )
        .animation(.easeInOut(duration: 2.0), value: c > 0.7)
        .animation(.easeInOut(duration: 2.0), value: c > 0.4)
    }

    // MARK: - Status

    private var statusBar: some View {
        HStack {
            Text("echoelmusic")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.4))
            Spacer()
            HStack(spacing: 4) {
                Circle()
                    .fill(statusDotColor)
                    .frame(width: 5, height: 5)
                Text(statusLabel)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.35))
            }
        }
    }

    private var statusDotColor: Color {
        guard cameraActive else { return Color.white.opacity(0.2) }
        #if os(iOS)
        if cameraAnalyzer.signalQuality > 0.6 { return EchoelBrand.emerald }
        if cameraAnalyzer.isFingerDetected { return EchoelBrand.amber }
        return EchoelBrand.coral
        #else
        return EchoelBrand.emerald
        #endif
    }

    private var statusLabel: String {
        guard cameraActive else { return "place finger" }
        #if os(iOS)
        if cameraAnalyzer.signalQuality > 0.6 { return "signal stable" }
        if cameraAnalyzer.isFingerDetected { return "measuring..." }
        return "no finger detected"
        #else
        return "active"
        #endif
    }

    // MARK: - Signal Stability Bar

    #if os(iOS)
    private var signalStabilityBar: some View {
        let quality = cameraAnalyzer.signalQuality
        let fingerDetected = cameraAnalyzer.isFingerDetected
        let confidence = cameraAnalyzer.bpmConfidence

        let barColor: Color = quality > 0.6 ? EchoelBrand.emerald
            : quality > 0.3 ? EchoelBrand.amber
            : EchoelBrand.coral

        return VStack(spacing: 6) {
            // Signal quality bar
            HStack(spacing: 8) {
                // Finger icon
                Image(systemName: fingerDetected ? "hand.point.up.fill" : "hand.point.up")
                    .font(.system(size: 11))
                    .foregroundStyle(fingerDetected ? EchoelBrand.emerald : Color.white.opacity(0.2))

                // Quality bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(barColor)
                            .frame(width: geo.size.width * max(0, min(1, quality)), height: 4)
                            .animation(.easeInOut(duration: 0.3), value: quality)
                    }
                }
                .frame(height: 4)

                // Quality percentage
                Text("\(Int(quality * 100))%")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(barColor)
                    .frame(minWidth: 32, alignment: .trailing)
            }

            // Status text
            HStack(spacing: 6) {
                if !fingerDetected {
                    Text("Cover rear camera + flash with fingertip")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.white.opacity(0.3))
                } else if confidence < 0.3 {
                    Text("Hold still — detecting pulse...")
                        .font(.system(size: 9))
                        .foregroundStyle(EchoelBrand.amber.opacity(0.6))
                } else if quality > 0.6 {
                    Text("Signal locked — \(Int(cameraAnalyzer.estimatedBPM)) BPM")
                        .font(.system(size: 9))
                        .foregroundStyle(EchoelBrand.emerald.opacity(0.6))
                } else {
                    Text("Stabilizing — press firmly, stay still")
                        .font(.system(size: 9))
                        .foregroundStyle(EchoelBrand.amber.opacity(0.6))
                }
                Spacer()
            }
        }
    }
    #endif

    // MARK: - Breathing Ring

    private var breathingRing: some View {
        let coherence = bio.smoothCoherence
        let ringColor: Color = coherence > 0.7 ? EchoelBrand.coherenceHigh
            : coherence > 0.4 ? EchoelBrand.coherenceMedium
            : EchoelBrand.coherenceLow

        return ZStack {
            Circle()
                .stroke(Color.white.opacity(0.06), lineWidth: 2)
                .frame(width: 220, height: 220)

            Circle()
                .trim(from: 0, to: max(0, min(1, coherence)))
                .stroke(ringColor.opacity(0.6), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 220, height: 220)
                .animation(.easeInOut(duration: 1.5), value: coherence)

            let breathScale = 0.85 + bio.smoothBreathPhase * 0.15
            Circle()
                .fill(ringColor.opacity(engine.isPlaying ? 0.06 : 0.03))
                .frame(width: 160, height: 160)
                .scaleEffect(breathScale)
                .animation(.easeInOut(duration: 0.5), value: bio.smoothBreathPhase)

            VStack(spacing: 6) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(ringColor)

                Text("\(Int(bio.smoothHeartRate))")
                    .font(.system(size: 56, weight: .ultraLight, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.9))

                Text("\(Int(coherence * 100))% coherence")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(ringColor.opacity(0.7))
            }
        }
    }

    // MARK: - Metrics

    private var metricsRow: some View {
        HStack {
            metric(
                value: String(format: "%.0f", bio.snapshot.hrvRMSSD),
                unit: "ms", label: "HRV"
            )
            Spacer()
            metric(
                value: String(format: "%.0f", bio.snapshot.breathRate),
                unit: "/m", label: "Breath"
            )
            Spacer()
            metric(
                value: engine.isPlaying ? "♪" : "—",
                unit: "", label: "Sound"
            )
        }
    }

    private func metric(value: String, unit: String, label: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 1) {
                Text(value)
                    .font(.system(size: 18, weight: .light, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.6))
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.25))
                }
            }
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.2))
        }
    }

    // MARK: - Play

    private var playControl: some View {
        Button {
            if engine.isPlaying {
                engine.stop()
                #if os(iOS)
                cameraAnalyzer.stopPulseDetection()
                engine.stopCameraFeed()
                teardownCamera()
                #endif
                cameraActive = false
            } else {
                #if os(iOS)
                Task { @MainActor in
                    await startCameraAndMusic()
                }
                #else
                engine.start()
                #endif
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(engine.isPlaying ? 0.08 : 0.04))
                    .frame(width: 64, height: 64)
                Circle()
                    .stroke(Color.white.opacity(engine.isPlaying ? 0.3 : 0.12), lineWidth: 1.5)
                    .frame(width: 64, height: 64)
                Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.white.opacity(engine.isPlaying ? 0.8 : 0.5))
                    .offset(x: engine.isPlaying ? 0 : 1.5)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Camera Lifecycle

    #if os(iOS)
    private func startCameraAndMusic() async {
        cameraError = nil

        // 1. Initialize CameraManager if needed
        #if canImport(Metal)
        if cameraManager == nil {
            guard let device = MTLCreateSystemDefaultDevice() else {
                cameraError = "Metal not available on this device"
                return
            }
            guard let manager = CameraManager(device: device) else {
                cameraError = "Failed to initialize camera"
                return
            }
            cameraManager = manager
        }
        #else
        cameraError = "Camera requires Metal GPU"
        return
        #endif

        guard let manager = cameraManager else { return }

        // 2. Wire raw frame callback → CameraAnalyzer
        manager.onRawFrameCaptured = { [cameraAnalyzer] pixelBuffer, _ in
            cameraAnalyzer.analyzePixelBuffer(pixelBuffer)
        }

        // 3. Start camera capture (handles permission request internally)
        do {
            try await manager.startCapture(camera: .back, resolution: .hd1280x720, frameRate: 30)
        } catch {
            cameraError = "Camera access denied — enable in Settings"
            log.log(.error, category: .biofeedback, "Camera start failed: \(error)")
            return
        }

        // 4. Enable torch for PPG illumination — required for finger-on-lens detection
        if let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           videoDevice.hasTorch {
            manager.setTorchMode(.on, level: 1.0)
        } else {
            cameraError = "This device has no flash — PPG requires rear flash for pulse detection"
            manager.stopCapture()
            log.log(.error, category: .biofeedback, "No torch available — PPG cannot work")
            return
        }

        // 5. Start pulse detection + bio feed + music
        cameraAnalyzer.startPulseDetection()
        engine.startCameraFeed(analyzer: cameraAnalyzer)
        cameraActive = true
        engine.start()

        log.log(.info, category: .biofeedback, "Camera PPG started — torch on, 30fps, rear camera")
    }

    private func teardownCamera() {
        cameraManager?.setTorchMode(.off)
        cameraManager?.stopCapture()
        cameraManager?.onRawFrameCaptured = nil
        cameraManager = nil
    }
    #endif
}

#endif
