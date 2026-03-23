#if canImport(SwiftUI)
import SwiftUI

// MARK: - Bio Source Selection

/// How the user provides heart rate data
enum BioInputSource: String, CaseIterable, Identifiable {
    case camera = "Camera"
    case appleWatch = "Apple Watch"
    case ouraRing = "Oura Ring"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .camera: return "camera.fill"
        case .appleWatch: return "applewatch.watchface"
        case .ouraRing: return "ring.circle"
        }
    }

    var description: String {
        switch self {
        case .camera: return "Finger on lens"
        case .appleWatch: return "HealthKit stream"
        case .ouraRing: return "Cloud sync"
        }
    }
}

/// Synth sound choices — mapped to real EchoelSynth presets
enum BioSoundMode: String, CaseIterable, Identifiable {
    case pad = "Ambient Pad"
    case keys = "Electric Piano"
    case pluck = "Crystal Pluck"
    case bio = "Bio Reactive"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .pad: return "waveform"
        case .keys: return "pianokeys"
        case .pluck: return "guitars"
        case .bio: return "heart.text.clipboard"
        }
    }
}

// MARK: - BioMusic Coordinator (class — safe for Timer closures)

/// Manages timers and audio state outside the SwiftUI struct.
/// Timer closures capture this class instance (reference type), not a View struct.
@MainActor
@Observable
final class BioMusicCoordinator {
    var isPlaying = false
    var currentNotes: [Int] = []

    private var noteTimer: Timer?
    private var bioFeedTimer: Timer?
    private var cameraFeedTimer: Timer?

    private let bio = EchoelBioEngine.shared

    // C minor pentatonic, 2 octaves
    private let scale = [48, 51, 53, 55, 58, 60, 63, 65, 67, 70, 72, 75]

    func startPlayback(sound: BioSoundMode) {
        guard !isPlaying else { return }
        isPlaying = true

        applySynthPreset(sound)

        // Ensure synth is connected and engine running
        let synth = EchoelSynth.shared

        // Generative note engine — 500ms interval
        noteTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.generateNote()
            }
        }

        // Bio → synth parameter feed at 20 Hz (not 30 — saves CPU)
        bioFeedTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 20.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.feedBioToSynth()
            }
        }

        // Play first note immediately
        generateNote()
    }

    func stopPlayback() {
        guard isPlaying else { return }
        isPlaying = false

        noteTimer?.invalidate()
        noteTimer = nil
        bioFeedTimer?.invalidate()
        bioFeedTimer = nil

        // Release all active notes
        for note in currentNotes {
            EchoelSynth.shared.noteOff(note: note)
        }
        currentNotes.removeAll()
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
        stopPlayback()
        stopCameraFeed()
    }

    private func generateNote() {
        guard isPlaying else { return }

        let coherence = Float(bio.smoothCoherence)
        let hrv = Float(bio.smoothHRV)

        // Higher coherence = more consonant (fewer notes, lower range)
        let noteCount = coherence > 0.6 ? 1 : (coherence > 0.3 ? 2 : 3)

        // Release previous notes
        for note in currentNotes {
            EchoelSynth.shared.noteOff(note: note)
        }
        currentNotes.removeAll()

        // High coherence → warmer lower range; low → full range
        let available = coherence > 0.5 ? Array(scale.prefix(5)) : scale
        guard !available.isEmpty else { return }

        for _ in 0..<noteCount {
            let note = available[Int.random(in: 0..<available.count)]
            let velocity = max(0.2, min(1.0, Float(0.4 + hrv * 0.4)))
            EchoelSynth.shared.noteOn(note: note, velocity: velocity)
            currentNotes.append(note)
        }
    }

    private func feedBioToSynth() {
        guard isPlaying else { return }
        let params = bio.audioParameters()
        EchoelSynth.shared.updateBio(
            coherence: params.coherence,
            heartRate: params.heartRate,
            hrv: params.hrv,
            breathPhase: params.breathPhase
        )
    }

    private func applySynthPreset(_ mode: BioSoundMode) {
        let synth = EchoelSynth.shared
        switch mode {
        case .pad: synth.setPreset(.warmPad)
        case .keys: synth.setPreset(.electricPiano)
        case .pluck: synth.setPreset(.crystalPluck)
        case .bio: synth.setPreset(.bioReactive)
        }
    }
}

// MARK: - BioMusicView

/// The main experience: heartbeat → music.
/// One screen. Bio data visible. Sound reacts to you.
struct BioMusicView: View {

    @Bindable private var bio = EchoelBioEngine.shared
    @State private var coordinator = BioMusicCoordinator()
    @State private var selectedSource: BioInputSource = .appleWatch
    @State private var selectedSound: BioSoundMode = .pad
    @State private var cameraAnalyzer = CameraAnalyzer()
    @State private var pulseAnimation = false

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, EchoelSpacing.md)
                .padding(.top, EchoelSpacing.sm)

            Spacer()

            bioDisplay
                .padding(.horizontal, EchoelSpacing.lg)

            Spacer()

            soundSelector
                .padding(.horizontal, EchoelSpacing.md)

            playButton
                .padding(.vertical, EchoelSpacing.lg)

            sourceSelector
                .padding(.horizontal, EchoelSpacing.md)
                .padding(.bottom, EchoelSpacing.lg)
        }
        .background(EchoelBrand.bgDeep.ignoresSafeArea())
        .onDisappear {
            coordinator.stopAll()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Echoelmusic")
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundStyle(EchoelBrand.textPrimary)
                Text("Your heartbeat shapes the sound")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(EchoelBrand.textSecondary)
            }
            Spacer()
            HStack(spacing: 4) {
                Circle()
                    .fill(sourceStatusColor)
                    .frame(width: 6, height: 6)
                Text(sourceStatusText)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(EchoelBrand.textSecondary)
            }
        }
    }

    private var sourceStatusColor: Color {
        guard bio.isStreaming else { return EchoelBrand.textTertiary }
        switch bio.dataSource {
        case .healthKit, .appleWatch, .chestStrap: return EchoelBrand.emerald
        case .camera: return EchoelBrand.sky
        case .ouraRing: return EchoelBrand.violet
        case .arkit: return EchoelBrand.sky
        case .microphone: return EchoelBrand.amber
        case .fallback: return EchoelBrand.textTertiary
        }
    }

    private var sourceStatusText: String {
        guard bio.isStreaming, bio.dataSource != .fallback else { return "No data" }
        return bio.dataSource.rawValue
    }

    // MARK: - Central Bio Display

    private var bioDisplay: some View {
        VStack(spacing: EchoelSpacing.lg) {
            ZStack {
                Circle()
                    .stroke(EchoelBrand.border, lineWidth: 3)
                    .frame(width: 180, height: 180)

                Circle()
                    .trim(from: 0, to: isRealData ? bio.smoothCoherence : 0)
                    .stroke(
                        coherenceColor,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 180, height: 180)
                    .animation(.easeInOut(duration: 1.0), value: bio.smoothCoherence)

                VStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(isRealData ? EchoelBrand.coral : EchoelBrand.textTertiary)
                        .scaleEffect(pulseAnimation ? 1.15 : 1.0)
                        .animation(
                            isRealData
                                ? .easeInOut(duration: pulseInterval).repeatForever(autoreverses: true)
                                : .default,
                            value: pulseAnimation
                        )

                    Text(isRealData ? "\(Int(bio.smoothHeartRate))" : "—")
                        .font(.system(size: 48, weight: .light, design: .monospaced))
                        .foregroundStyle(EchoelBrand.textPrimary)

                    Text("BPM")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(EchoelBrand.textTertiary)
                }
            }

            HStack(spacing: EchoelSpacing.xl) {
                bioMetric(
                    label: "HRV",
                    value: isRealData ? String(format: "%.0f", bio.snapshot.hrvRMSSD) : "—",
                    unit: "ms",
                    icon: "waveform.path.ecg"
                )
                bioMetric(
                    label: "Coherence",
                    value: isRealData ? String(format: "%.0f", bio.smoothCoherence * 100) : "—",
                    unit: "%",
                    icon: "brain.head.profile"
                )
                bioMetric(
                    label: "Breath",
                    value: isRealData ? String(format: "%.0f", bio.snapshot.breathRate) : "—",
                    unit: "/min",
                    icon: "wind"
                )
            }
        }
    }

    private func bioMetric(label: String, value: String, unit: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(EchoelBrand.textTertiary)
            HStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .light, design: .monospaced))
                    .foregroundStyle(EchoelBrand.textPrimary)
                Text(unit)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(EchoelBrand.textTertiary)
            }
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(EchoelBrand.textSecondary)
        }
    }

    // MARK: - Sound Selector

    private var soundSelector: some View {
        HStack(spacing: EchoelSpacing.sm) {
            ForEach(BioSoundMode.allCases) { mode in
                Button {
                    selectedSound = mode
                    if coordinator.isPlaying {
                        coordinator.stopPlayback()
                        coordinator.startPlayback(sound: mode)
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 16))
                        Text(mode.rawValue)
                            .font(.system(size: 9, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, EchoelSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: EchoelRadius.sm)
                            .fill(selectedSound == mode ? EchoelBrand.bgElevated : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: EchoelRadius.sm)
                            .stroke(selectedSound == mode ? EchoelBrand.textTertiary : EchoelBrand.border, lineWidth: 1)
                    )
                    .foregroundStyle(selectedSound == mode ? EchoelBrand.textPrimary : EchoelBrand.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Play Button

    private var playButton: some View {
        Button {
            if coordinator.isPlaying {
                coordinator.stopPlayback()
                pulseAnimation = false
            } else {
                coordinator.startPlayback(sound: selectedSound)
                pulseAnimation = true
            }
        } label: {
            ZStack {
                Circle()
                    .fill(coordinator.isPlaying ? EchoelBrand.coral.opacity(0.15) : EchoelBrand.bgElevated)
                    .frame(width: 72, height: 72)

                Circle()
                    .stroke(coordinator.isPlaying ? EchoelBrand.coral : EchoelBrand.textTertiary, lineWidth: 2)
                    .frame(width: 72, height: 72)

                Image(systemName: coordinator.isPlaying ? "stop.fill" : "play.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(coordinator.isPlaying ? EchoelBrand.coral : EchoelBrand.textPrimary)
                    .offset(x: coordinator.isPlaying ? 0 : 2)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Source Selector

    private var sourceSelector: some View {
        VStack(spacing: EchoelSpacing.sm) {
            Text("Heart Rate Source")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(EchoelBrand.textTertiary)

            HStack(spacing: EchoelSpacing.sm) {
                ForEach(BioInputSource.allCases) { source in
                    Button {
                        selectedSource = source
                        switchBioSource(source)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: source.icon)
                                .font(.system(size: 18))
                            Text(source.rawValue)
                                .font(.system(size: 10, weight: .medium))
                            Text(source.description)
                                .font(.system(size: 8))
                                .foregroundStyle(EchoelBrand.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, EchoelSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: EchoelRadius.sm)
                                .fill(selectedSource == source ? EchoelBrand.bgElevated : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: EchoelRadius.sm)
                                .stroke(selectedSource == source ? EchoelBrand.emerald : EchoelBrand.border, lineWidth: 1)
                        )
                        .foregroundStyle(selectedSource == source ? EchoelBrand.textPrimary : EchoelBrand.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("Bio data is for self-observation, not medical diagnosis.")
                .font(.system(size: 8))
                .foregroundStyle(EchoelBrand.textTertiary)
                .padding(.top, EchoelSpacing.xs)
        }
    }

    // MARK: - Helpers

    private var isRealData: Bool {
        bio.isStreaming && bio.dataSource != .fallback
    }

    private var coherenceColor: Color {
        if bio.smoothCoherence > 0.7 { return EchoelBrand.coherenceHigh }
        if bio.smoothCoherence > 0.4 { return EchoelBrand.coherenceMedium }
        return EchoelBrand.coherenceLow
    }

    private var pulseInterval: Double {
        let hr = bio.smoothHeartRate
        guard hr > 30, hr < 250 else { return 1.0 }
        // Clamp to safe animation duration range [0.25s, 2.0s]
        return max(0.25, min(2.0, 60.0 / hr))
    }

    // MARK: - Source Switching

    private func switchBioSource(_ source: BioInputSource) {
        coordinator.stopCameraFeed()
        bio.stopStreaming()

        switch source {
        case .camera:
            cameraAnalyzer.startPulseDetection()
            coordinator.startCameraFeed(analyzer: cameraAnalyzer)

        case .appleWatch:
            Task {
                _ = await bio.requestAuthorization()
                bio.startStreaming()
            }

        case .ouraRing:
            Task {
                let client = OuraRingClient.shared
                guard client.authState == .authenticated else {
                    log.log(.warning, category: .audio, "Oura Ring not connected — configure in settings")
                    return
                }
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
        }
    }
}

#endif
