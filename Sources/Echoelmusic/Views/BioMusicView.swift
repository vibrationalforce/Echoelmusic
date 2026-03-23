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

// MARK: - BioMusicView

/// The main experience: heartbeat → music.
/// One screen. Bio data visible. Sound reacts to you.
struct BioMusicView: View {

    @Bindable private var bio = EchoelBioEngine.shared
    @State private var selectedSource: BioInputSource = .appleWatch
    @State private var selectedSound: BioSoundMode = .pad
    @State private var isPlaying = false
    @State private var showSourcePicker = false
    @State private var cameraAnalyzer = CameraAnalyzer()
    @State private var pulseAnimation = false
    @State private var bioUpdateTimer: Timer?

    // Generative note engine
    @State private var noteTimer: Timer?
    @State private var currentNotes: [Int] = []

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
                .padding(.horizontal, EchoelSpacing.md)
                .padding(.top, EchoelSpacing.sm)

            Spacer()

            // Central bio display
            bioDisplay
                .padding(.horizontal, EchoelSpacing.lg)

            Spacer()

            // Sound mode selector
            soundSelector
                .padding(.horizontal, EchoelSpacing.md)

            // Play button
            playButton
                .padding(.vertical, EchoelSpacing.lg)

            // Source selector
            sourceSelector
                .padding(.horizontal, EchoelSpacing.md)
                .padding(.bottom, EchoelSpacing.lg)
        }
        .background(EchoelBrand.bgDeep.ignoresSafeArea())
        .onDisappear {
            stopPlayback()
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
            // Source indicator
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
            // Heart rate — big, central
            ZStack {
                // Coherence ring
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

                // HR number
                VStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(isRealData ? EchoelBrand.coral : EchoelBrand.textTertiary)
                        .scaleEffect(pulseAnimation ? 1.15 : 1.0)
                        .animation(
                            isRealData ? .easeInOut(duration: pulseInterval).repeatForever(autoreverses: true) : .default,
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

            // Secondary metrics
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
                    applySynthPreset(mode)
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
            if isPlaying {
                stopPlayback()
            } else {
                startPlayback()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(isPlaying ? EchoelBrand.coral.opacity(0.15) : EchoelBrand.bgElevated)
                    .frame(width: 72, height: 72)

                Circle()
                    .stroke(isPlaying ? EchoelBrand.coral : EchoelBrand.textTertiary, lineWidth: 2)
                    .frame(width: 72, height: 72)

                Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(isPlaying ? EchoelBrand.coral : EchoelBrand.textPrimary)
                    .offset(x: isPlaying ? 0 : 2) // Optical center for play icon
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

            // Safety disclaimer
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

    /// Pulse interval derived from heart rate
    private var pulseInterval: Double {
        guard bio.smoothHeartRate > 40 else { return 1.0 }
        return 60.0 / bio.smoothHeartRate
    }

    // MARK: - Actions

    private func switchBioSource(_ source: BioInputSource) {
        bio.stopStreaming()

        switch source {
        case .camera:
            // Camera rPPG — start pulse detection, feed into bio engine
            cameraAnalyzer.togglePulseDetection()
            // Camera feeds into bio engine via timer
            startCameraBioFeed()

        case .appleWatch:
            // HealthKit — already wired
            Task {
                _ = await bio.requestAuthorization()
                bio.startStreaming()
            }

        case .ouraRing:
            // Oura cloud sync — use last-known HRV data
            startOuraBioFeed()
        }
    }

    private func startCameraBioFeed() {
        // Poll camera analyzer and push to bio engine
        bioUpdateTimer?.invalidate()
        bioUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            Task { @MainActor in
                if cameraAnalyzer.bpmConfidence > 0.3, cameraAnalyzer.estimatedBPM > 40 {
                    bio.snapshot.heartRate = cameraAnalyzer.estimatedBPM
                    bio.smoothHeartRate = bio.smoothHeartRate * 0.85 + cameraAnalyzer.estimatedBPM * 0.15
                    // Feed camera HRV (RMSSD) to bio engine
                    if cameraAnalyzer.rmssd > 0 {
                        bio.snapshot.hrvRMSSD = cameraAnalyzer.rmssd
                        bio.snapshot.hrvNormalized = min(cameraAnalyzer.rmssd / 100.0, 1.0)
                        bio.smoothHRV = bio.snapshot.hrvNormalized
                    }
                    bio.dataSource = .camera
                    if !bio.isStreaming { bio.startStreaming() }
                }
            }
        }
    }

    private func startOuraBioFeed() {
        // Oura Ring provides resting HR and HRV from sleep data
        Task {
            let client = OuraRingClient.shared
            guard client.authState == .authenticated else {
                log.log(.warning, category: .audio, "Oura Ring not connected — configure in settings")
                return
            }
            await client.syncDailyData()
            let oura = client.snapshot
            // Map Oura sleep HRV to bio engine
            if oura.hrvSleep > 0 {
                bio.snapshot.hrvRMSSD = oura.hrvSleep
                bio.snapshot.hrvNormalized = min(oura.hrvSleep / 100.0, 1.0)
                bio.smoothHRV = bio.snapshot.hrvNormalized
            }
            if oura.restingHR > 0 {
                bio.snapshot.heartRate = Double(oura.restingHR)
                bio.smoothHeartRate = Double(oura.restingHR)
            }
            bio.dataSource = .healthKit // closest available source type
            bio.isStreaming = true
        }
    }

    private func applySynthPreset(_ mode: BioSoundMode) {
        let synth = EchoelSynth.shared
        switch mode {
        case .pad:
            synth.setPreset(.warmPad)
        case .keys:
            synth.setPreset(.electricPiano)
        case .pluck:
            synth.setPreset(.crystalPluck)
        case .bio:
            synth.setPreset(.bioReactive)
        }
    }

    private func startPlayback() {
        isPlaying = true
        pulseAnimation = true

        applySynthPreset(selectedSound)

        // Start generative note engine — coherence influences note choice
        startGenerativeEngine()

        // Start bio → synth parameter feed
        startBioSynthFeed()
    }

    private func stopPlayback() {
        isPlaying = false
        pulseAnimation = false

        // Release all notes
        for note in currentNotes {
            EchoelSynth.shared.noteOff(note: note)
        }
        currentNotes.removeAll()

        noteTimer?.invalidate()
        noteTimer = nil
        bioUpdateTimer?.invalidate()
        bioUpdateTimer = nil
    }

    /// Generative note engine — plays notes influenced by bio data
    private func startGenerativeEngine() {
        // Base scale: C minor pentatonic, spread across 2 octaves
        let baseNotes = [48, 51, 53, 55, 58, 60, 63, 65, 67, 70, 72, 75]

        // Note interval adapts to heart rate (faster HR = faster notes)
        noteTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            Task { @MainActor in
                guard isPlaying else { return }

                let coherence = Float(bio.smoothCoherence)
                let hrv = Float(bio.smoothHRV)

                // Higher coherence = more consonant (fewer notes, lower in scale)
                // Lower coherence = more dissonant (more notes, wider spread)
                let noteCount = coherence > 0.6 ? 1 : (coherence > 0.3 ? 2 : 3)

                // Release previous notes
                for note in currentNotes {
                    EchoelSynth.shared.noteOff(note: note)
                }
                currentNotes.removeAll()

                // Pick notes based on coherence
                let availableNotes = coherence > 0.5
                    ? Array(baseNotes.prefix(5))   // High coherence: stay in lower, warmer range
                    : baseNotes                     // Low coherence: full range

                for _ in 0..<noteCount {
                    guard !availableNotes.isEmpty else { break }
                    let note = availableNotes[Int.random(in: 0..<availableNotes.count)]
                    let velocity = Float(0.4 + hrv * 0.4) // HRV affects velocity
                    EchoelSynth.shared.noteOn(note: note, velocity: velocity)
                    currentNotes.append(note)
                }
            }
        }
    }

    /// Feed bio parameters to synth in real time
    private func startBioSynthFeed() {
        // Bio → synth parameter mapping runs on a timer
        // This feeds coherence, HRV, HR, breath to the synth's updateBio method
        let feedTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { _ in
            Task { @MainActor in
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
        // Store reference to prevent deallocation
        bioUpdateTimer = feedTimer
    }
}

#endif
