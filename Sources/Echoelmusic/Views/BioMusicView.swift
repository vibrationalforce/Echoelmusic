#if canImport(SwiftUI)
import SwiftUI

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

    func stopAll() {
        stop()
        stopCameraFeed()
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
    @State private var cameraAnalyzer = CameraAnalyzer()
    @State private var selectedSource = 0

    var body: some View {
        ZStack {
            coherenceGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                statusBar
                    .padding(.horizontal, EchoelSpacing.md)
                    .padding(.top, EchoelSpacing.sm)

                Spacer()

                breathingRing

                Spacer()

                metricsRow
                    .padding(.horizontal, EchoelSpacing.xl)

                Spacer()

                playControl
                    .padding(.bottom, EchoelSpacing.lg)

                sourceTabs
                    .padding(.horizontal, EchoelSpacing.md)
                    .padding(.bottom, EchoelSpacing.sm)

                Text("Not a medical device. For self-observation only.")
                    .font(.system(size: 8))
                    .foregroundStyle(Color.white.opacity(0.2))
                    .padding(.bottom, EchoelSpacing.sm)
            }
        }
        .onDisappear { engine.stopAll() }
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
                    .fill(isConnected ? EchoelBrand.emerald : Color.white.opacity(0.2))
                    .frame(width: 5, height: 5)
                Text(connectionLabel)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.35))
            }
        }
    }

    private var isConnected: Bool {
        bio.isStreaming && bio.dataSource != .fallback
    }

    private var connectionLabel: String {
        guard isConnected else { return "no signal" }
        switch bio.dataSource {
        case .healthKit, .appleWatch, .chestStrap: return "watch"
        case .camera: return "camera"
        case .ouraRing: return "oura"
        case .arkit: return "face"
        case .microphone: return "mic"
        case .fallback: return "—"
        }
    }

    // MARK: - Breathing Ring

    private var breathingRing: some View {
        let coherence = isConnected ? bio.smoothCoherence : 0
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

            let breathScale = isConnected ? (0.85 + bio.smoothBreathPhase * 0.15) : 0.9
            Circle()
                .fill(ringColor.opacity(engine.isPlaying ? 0.06 : 0.03))
                .frame(width: 160, height: 160)
                .scaleEffect(breathScale)
                .animation(.easeInOut(duration: 0.5), value: bio.smoothBreathPhase)

            VStack(spacing: 6) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(isConnected ? ringColor : Color.white.opacity(0.15))

                Text(isConnected ? "\(Int(bio.smoothHeartRate))" : "—")
                    .font(.system(size: 56, weight: .ultraLight, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(isConnected ? 0.9 : 0.2))

                if isConnected {
                    Text("\(Int(coherence * 100))% coherence")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(ringColor.opacity(0.7))
                }
            }
        }
    }

    // MARK: - Metrics

    private var metricsRow: some View {
        HStack {
            metric(
                value: isConnected ? String(format: "%.0f", bio.snapshot.hrvRMSSD) : "—",
                unit: "ms", label: "HRV"
            )
            Spacer()
            metric(
                value: isConnected ? String(format: "%.0f", bio.snapshot.breathRate) : "—",
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
            } else {
                engine.start()
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

    // MARK: - Source Tabs

    private var sourceTabs: some View {
        HStack(spacing: 0) {
            sourceTab(index: 0, icon: "applewatch", label: "Watch")
            sourceTab(index: 1, icon: "camera.fill", label: "Camera")
            sourceTab(index: 2, icon: "circle.circle", label: "Oura")
        }
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: EchoelRadius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: EchoelRadius.sm)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }

    private func sourceTab(index: Int, icon: String, label: String) -> some View {
        Button {
            selectedSource = index
            switchSource(index)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                Text(label)
                    .font(.system(size: 9, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, EchoelSpacing.sm)
            .foregroundStyle(selectedSource == index ? Color.white.opacity(0.8) : Color.white.opacity(0.25))
            .background(selectedSource == index ? Color.white.opacity(0.06) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Source Switching

    private func switchSource(_ index: Int) {
        engine.stopCameraFeed()
        bio.stopStreaming()

        switch index {
        case 0:
            Task {
                _ = await bio.requestAuthorization()
                bio.startStreaming()
            }
        case 1:
            cameraAnalyzer.startPulseDetection()
            engine.startCameraFeed(analyzer: cameraAnalyzer)
        case 2:
            Task {
                let client = OuraRingClient.shared
                guard client.authState == .authenticated else { return }
                await client.syncDailyData()
                let oura = client.snapshot
                if oura.hrvSleep > 0 {
                    bio.snapshot.hrvRMSSD = oura.hrvSleep
                    bio.snapshot.hrvNormalized = min(oura.hrvSleep / 100.0, 1.0)
                    bio.smoothHRV = bio.snapshot.hrvNormalized
                }
                if oura.restingHR > 0 {
                    bio.snapshot.heartRate = Double(oura.restingHR)
                    bio.smoothHeartRate = Double(oura.restingHR)
                }
                bio.dataSource = .ouraRing
                bio.isStreaming = true
            }
        default:
            break
        }
    }
}

#endif
