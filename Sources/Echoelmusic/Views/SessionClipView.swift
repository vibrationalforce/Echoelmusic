import SwiftUI

// MARK: - Session Clip View
// Ableton Live Session View inspired clip launcher
// Full VaporwaveTheme Corporate Identity

// Wrapper view that owns the @StateObject, passes it to content via @ObservedObject
@MainActor
struct SessionClipView: View {
    @StateObject private var session = SessionClipViewModel()

    var body: some View {
        SessionClipContent(session: session)
    }
}

// Content view receives view model via @ObservedObject (no wrapper ambiguity)
@MainActor
private struct SessionClipContent: View {
    @ObservedObject var session: SessionClipViewModel
    @State private var selectedTrack: Int?
    @State private var selectedScene: Int?
    @State private var showInstrumentBrowser = false
    @State private var showEffectsBrowser = false

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    /// Adaptive clip cell size for iPhone vs iPad
    private var clipCellWidth: CGFloat {
        #if os(iOS)
        return horizontalSizeClass == .compact ? 70 : 100
        #else
        return 100
        #endif
    }

    /// Adaptive track header width for iPhone vs iPad
    private var trackHeaderWidth: CGFloat {
        #if os(iOS)
        return horizontalSizeClass == .compact ? 70 : 100
        #else
        return 100
        #endif
    }

    /// Whether on iPhone compact layout
    private var isCompact: Bool {
        #if os(iOS)
        return horizontalSizeClass == .compact
        #else
        return false
        #endif
    }

    var body: some View {
        ZStack {
            VaporwaveGradients.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                makeHeaderView(session)

                // Main Content
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        // Track Headers
                        makeTrackHeaderColumn(session)

                        // Clip Grid
                        ScrollView([.horizontal, .vertical], showsIndicators: false) {
                            makeClipGrid(session)
                        }

                        // Scene Launch
                        makeSceneLaunchColumn(session)
                    }
                }

                // Transport Bar
                transportBar
            }

            // Instrument Browser
            if showInstrumentBrowser {
                InstrumentBrowserSheet(isPresented: $showInstrumentBrowser, onSelect: { instrument in
                    session.addInstrumentToTrack(selectedTrack ?? 0, instrument: instrument)
                })
            }

            // Effects Browser
            if showEffectsBrowser {
                EffectsBrowserSheet(isPresented: $showEffectsBrowser, onSelect: { effect in
                    session.addEffectToTrack(selectedTrack ?? 0, effect: effect)
                })
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private func makeHeaderView(_ vm: SessionClipViewModel) -> some View {
        let trackCount = vm.tracks.count
        let sceneCount = vm.scenes.count
        let bpm = vm.bpm
        let bioSync = vm.bioSyncEnabled
        let coherence = vm.coherence
        let coherenceColor = vm.coherenceColor
        HStack {
            VStack(alignment: .leading, spacing: VaporwaveSpacing.xs) {
                Text("SESSION")
                    .font(VaporwaveTypography.sectionTitle())
                    .foregroundColor(VaporwaveColors.textPrimary)

                Text("\(trackCount) Tracks • \(sceneCount) Scenes")
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.neonCyan)
            }

            Spacer()

            // BPM Display
            HStack(spacing: VaporwaveSpacing.sm) {
                Image(systemName: "metronome")
                    .foregroundColor(VaporwaveColors.neonPink)

                Text(String(format: "%.1f", bpm))
                    .font(VaporwaveTypography.dataSmall())
                    .foregroundColor(VaporwaveColors.textPrimary)

                Text("BPM")
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textTertiary)
            }
            .padding(.horizontal, VaporwaveSpacing.md)
            .padding(.vertical, VaporwaveSpacing.sm)
            .glassCard()

            // Bio Sync
            Button(action: { vm.bioSyncEnabled.toggle() }) {
                HStack(spacing: VaporwaveSpacing.sm) {
                    Image(systemName: "heart.fill")
                    Text("Bio")
                }
                .font(VaporwaveTypography.caption())
                .foregroundColor(bioSync ? VaporwaveColors.neonPink : VaporwaveColors.textTertiary)
            }
            .padding(.horizontal, VaporwaveSpacing.md)
            .padding(.vertical, VaporwaveSpacing.sm)
            .background(bioSync ? VaporwaveColors.neonPink.opacity(0.2) : Color.clear)
            .glassCard()

            // Coherence Display
            if bioSync {
                VStack(spacing: 2) {
                    Text("\(Int(coherence * 100))")
                        .font(VaporwaveTypography.dataSmall())
                        .foregroundColor(coherenceColor)

                    Text("FLOW")
                        .font(VaporwaveTypography.label())
                        .foregroundColor(VaporwaveColors.textTertiary)
                }
                .neonGlow(color: coherenceColor, radius: 6)
            }
        }
        .padding(VaporwaveSpacing.md)
    }

    // MARK: - Track Header Column

    @ViewBuilder
    private func makeTrackHeaderColumn(_ vm: SessionClipViewModel) -> some View {
        let tracks = vm.tracks
        let trackCount = tracks.count
        VStack(spacing: 2) {
            // Add Track Button
            Button(action: { vm.addTrack() }) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(VaporwaveColors.neonCyan)
            }
            .frame(width: trackHeaderWidth, height: 30)
            .glassCard()

            // Track Headers
            ForEach(0..<trackCount, id: \.self) { index in
                TrackHeaderCell(
                    track: tracks[index],
                    isSelected: selectedTrack == index,
                    onSelect: { selectedTrack = index },
                    onMute: { vm.toggleMute(index) },
                    onSolo: { vm.toggleSolo(index) },
                    onArm: { vm.toggleArm(index) },
                    onInstrument: {
                        selectedTrack = index
                        showInstrumentBrowser = true
                    },
                    onEffects: {
                        selectedTrack = index
                        showEffectsBrowser = true
                    }
                )
            }

            Spacer()
        }
        .frame(width: trackHeaderWidth)
        .background(VaporwaveColors.deepBlack.opacity(0.5))
    }

    // MARK: - Clip Grid

    @ViewBuilder
    private func makeClipGrid(_ vm: SessionClipViewModel) -> some View {
        let tracks = vm.tracks
        let scenes = vm.scenes
        let sceneCount = scenes.count
        let trackCount = tracks.count
        VStack(spacing: 2) {
            // Scene Headers
            HStack(spacing: 2) {
                ForEach(0..<sceneCount, id: \.self) { idx in
                    Text("Scene \(idx + 1)")
                        .font(VaporwaveTypography.label())
                        .foregroundColor(VaporwaveColors.textTertiary)
                        .frame(width: trackHeaderWidth, height: 30)
                }
            }

            // Clip Slots
            ForEach(0..<trackCount, id: \.self) { trackIndex in
                HStack(spacing: 2) {
                    ForEach(0..<sceneCount, id: \.self) { sceneIndex in
                        ClipSlotCell(
                            clip: vm.clipAt(track: trackIndex, scene: sceneIndex),
                            trackColor: tracks[trackIndex].color,
                            isPlaying: vm.isClipPlaying(track: trackIndex, scene: sceneIndex),
                            onTap: { vm.toggleClip(track: trackIndex, scene: sceneIndex) },
                            onDoubleTap: { vm.editClip(track: trackIndex, scene: sceneIndex) },
                            onStop: { vm.stopClip(track: trackIndex, scene: sceneIndex) }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Scene Launch Column

    @ViewBuilder
    private func makeSceneLaunchColumn(_ vm: SessionClipViewModel) -> some View {
        let scenes = vm.scenes
        let activeScene = vm.activeScene
        let sceneCount = scenes.count
        VStack(spacing: 2) {
            // Master Stop
            Button(action: { vm.stopAll() }) {
                Image(systemName: "stop.fill")
                    .foregroundColor(VaporwaveColors.textTertiary)
            }
            .frame(width: 60, height: 30)
            .glassCard()

            // Scene Launch Buttons
            ForEach(0..<sceneCount, id: \.self) { index in
                SceneLaunchButton(
                    scene: scenes[index],
                    isPlaying: activeScene == index,
                    onLaunch: { vm.launchScene(index) }
                )
            }

            // Add Scene
            Button(action: { vm.addScene() }) {
                Image(systemName: "plus")
                    .foregroundColor(VaporwaveColors.neonPurple)
            }
            .frame(width: 60, height: 60)
            .glassCard()

            Spacer()
        }
        .frame(width: 60)
        .background(VaporwaveColors.deepBlack.opacity(0.5))
    }

    // MARK: - Transport Bar

    private var transportBar: some View {
        HStack(spacing: VaporwaveSpacing.lg) {
            // Transport Controls
            HStack(spacing: VaporwaveSpacing.md) {
                Button(action: { session.stop() }) {
                    Image(systemName: "stop.fill")
                        .foregroundColor(VaporwaveColors.textSecondary)
                }

                Button(action: { session.togglePlay() }) {
                    Image(systemName: session.isPlaying ? "pause.fill" : "play.fill")
                        .foregroundColor(session.isPlaying ? VaporwaveColors.neonCyan : VaporwaveColors.textSecondary)
                }
                .neonGlow(color: session.isPlaying ? VaporwaveColors.neonCyan : .clear, radius: 8)

                Button(action: { session.toggleRecord() }) {
                    Image(systemName: "record.circle")
                        .foregroundColor(session.isRecording ? VaporwaveColors.neonPink : VaporwaveColors.textSecondary)
                }
                .neonGlow(color: session.isRecording ? VaporwaveColors.neonPink : .clear, radius: 8)
            }
            .font(.system(size: 20))

            Spacer()

            // Position Display
            HStack(spacing: VaporwaveSpacing.sm) {
                Text(session.positionString)
                    .font(VaporwaveTypography.dataSmall())
                    .foregroundColor(VaporwaveColors.textPrimary)

                Text("BAR")
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textTertiary)
            }

            Spacer()

            // Quantize
            HStack(spacing: VaporwaveSpacing.sm) {
                Text("Q:")
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textTertiary)

                Picker("", selection: $session.quantize) {
                    Text("1 Bar").tag(QuantizeValue.bar)
                    Text("1/2").tag(QuantizeValue.half)
                    Text("1/4").tag(QuantizeValue.quarter)
                    Text("1/8").tag(QuantizeValue.eighth)
                    Text("Off").tag(QuantizeValue.off)
                }
                .pickerStyle(.menu)
                .font(VaporwaveTypography.caption())
            }

            // Follow
            Toggle(isOn: $session.followPlayhead) {
                Text("Follow")
                    .font(VaporwaveTypography.caption())
            }
            .toggleStyle(SwitchToggleStyle(tint: VaporwaveColors.neonCyan))
        }
        .padding(VaporwaveSpacing.md)
        .background(VaporwaveColors.deepBlack.opacity(0.8))
    }
}

// MARK: - Track Header Cell

struct TrackHeaderCell: View {
    let track: ClipViewTrack
    let isSelected: Bool
    let onSelect: () -> Void
    let onMute: () -> Void
    let onSolo: () -> Void
    let onArm: () -> Void
    let onInstrument: () -> Void
    let onEffects: () -> Void

    var body: some View {
        VStack(spacing: VaporwaveSpacing.xs) {
            // Track Name
            Text(track.name)
                .font(VaporwaveTypography.caption())
                .foregroundColor(isSelected ? track.color : VaporwaveColors.textSecondary)
                .lineLimit(1)

            // Instrument Button
            Button(action: onInstrument) {
                HStack(spacing: 2) {
                    Image(systemName: track.instrumentIcon)
                        .font(.system(size: 10))
                    Text(track.instrumentName)
                        .font(VaporwaveTypography.label())
                        .lineLimit(1)
                }
                .foregroundColor(VaporwaveColors.neonCyan)
            }

            // Effects Button
            Button(action: onEffects) {
                HStack(spacing: 2) {
                    Image(systemName: "waveform")
                        .font(.system(size: 8))
                    Text("\(track.effectCount) FX")
                        .font(VaporwaveTypography.label())
                }
                .foregroundColor(track.effectCount > 0 ? VaporwaveColors.neonPurple : VaporwaveColors.textTertiary)
            }

            // Buttons
            HStack(spacing: 4) {
                Button(action: onMute) {
                    Text("M")
                        .font(VaporwaveTypography.label())
                        .foregroundColor(track.isMuted ? VaporwaveColors.deepBlack : VaporwaveColors.textTertiary)
                        .frame(width: 20, height: 18)
                        .background(track.isMuted ? VaporwaveColors.coral : Color.clear)
                        .cornerRadius(3)
                }

                Button(action: onSolo) {
                    Text("S")
                        .font(VaporwaveTypography.label())
                        .foregroundColor(track.isSoloed ? VaporwaveColors.deepBlack : VaporwaveColors.textTertiary)
                        .frame(width: 20, height: 18)
                        .background(track.isSoloed ? VaporwaveColors.coherenceMedium : Color.clear)
                        .cornerRadius(3)
                }

                Button(action: onArm) {
                    Image(systemName: "record.circle")
                        .font(.system(size: 10))
                        .foregroundColor(track.isArmed ? VaporwaveColors.neonPink : VaporwaveColors.textTertiary)
                }
            }

            // Color Strip
            Rectangle()
                .fill(track.color)
                .frame(height: 3)
        }
        .frame(width: 100, height: 80)
        .padding(.vertical, VaporwaveSpacing.xs)
        .background(isSelected ? track.color.opacity(0.1) : Color.clear)
        .overlay(
            Rectangle()
                .stroke(isSelected ? track.color : Color.clear, lineWidth: 1)
        )
        .onTapGesture { onSelect() }
    }
}

// MARK: - Clip Slot Cell

struct ClipSlotCell: View {
    let clip: ClipViewClip?
    let trackColor: Color
    let isPlaying: Bool
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    let onStop: () -> Void

    @State private var isHovered = false

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 4)
                .fill(clip != nil ? trackColor.opacity(0.3) : VaporwaveColors.deepBlack.opacity(0.3))

            // Clip Content
            if let clip = clip {
                VStack(spacing: 2) {
                    Text(clip.name)
                        .font(VaporwaveTypography.label())
                        .foregroundColor(VaporwaveColors.textPrimary)
                        .lineLimit(1)

                    // Waveform Preview
                    ClipWaveformPreview(color: trackColor)
                        .frame(height: 20)
                }
                .padding(4)
            }

            // Playing Indicator
            if isPlaying {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(VaporwaveColors.coherenceHigh, lineWidth: 2)

                // Progress
                GeometryReader { geo in
                    Rectangle()
                        .fill(VaporwaveColors.coherenceHigh.opacity(0.3))
                        .frame(width: geo.size.width * 0.5) // Animated in real implementation
                }
            }

            // Stop Button (on hover)
            if isHovered && clip != nil {
                Button(action: onStop) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 12))
                        .foregroundColor(VaporwaveColors.textSecondary)
                }
            }
        }
        .frame(width: 100, height: 60)
        .onTapGesture(count: 2, perform: onDoubleTap)
        .onTapGesture(count: 1, perform: onTap)
        .onHover { isHovered = $0 }
    }
}

struct ClipWaveformPreview: View {
    let color: Color

    var body: some View {
        GeometryReader { geo in
            Path { path in
                let width = geo.size.width
                let height = geo.size.height
                let midY = height / 2

                path.move(to: CGPoint(x: 0, y: midY))
                for x in stride(from: 0, to: width, by: 3) {
                    let amplitude = CGFloat.random(in: 0.2...1.0) * (height / 2 - 2)
                    path.addLine(to: CGPoint(x: x, y: midY - amplitude))
                    path.addLine(to: CGPoint(x: x + 1.5, y: midY + amplitude))
                }
            }
            .stroke(color, lineWidth: 1)
        }
    }
}

// MARK: - Scene Launch Button

struct SceneLaunchButton: View {
    let scene: ClipViewScene
    let isPlaying: Bool
    let onLaunch: () -> Void

    var body: some View {
        Button(action: onLaunch) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isPlaying ? VaporwaveColors.coherenceHigh.opacity(0.3) : VaporwaveColors.deepBlack.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isPlaying ? VaporwaveColors.coherenceHigh : VaporwaveColors.textTertiary.opacity(0.3), lineWidth: 1)
                    )

                Image(systemName: isPlaying ? "checkmark" : "play.fill")
                    .font(.system(size: 16))
                    .foregroundColor(isPlaying ? VaporwaveColors.coherenceHigh : VaporwaveColors.textSecondary)
            }
        }
        .frame(width: 60, height: 60)
        .neonGlow(color: isPlaying ? VaporwaveColors.coherenceHigh : .clear, radius: 6)
    }
}

// MARK: - Instrument Browser Sheet

struct InstrumentBrowserSheet: View {
    @Binding var isPresented: Bool
    let onSelect: (InstrumentInfo) -> Void

    let categories: [(String, String, [InstrumentInfo])] = [
        ("Synths", "waveform", [
            InstrumentInfo(name: "EchoSynth", icon: "waveform", category: "Synth"),
            InstrumentInfo(name: "Subtractive", icon: "waveform.path", category: "Synth"),
            InstrumentInfo(name: "FM Synth", icon: "waveform.circle", category: "Synth"),
            InstrumentInfo(name: "Wavetable", icon: "waveform.badge.plus", category: "Synth"),
            InstrumentInfo(name: "Granular", icon: "sparkles", category: "Synth"),
            InstrumentInfo(name: "Genetic", icon: "leaf.fill", category: "Synth")
        ]),
        ("Orchestral", "music.quarternote.3", [
            InstrumentInfo(name: "Strings", icon: "guitars", category: "Orchestral"),
            InstrumentInfo(name: "Brass", icon: "horn.fill", category: "Orchestral"),
            InstrumentInfo(name: "Woodwinds", icon: "wind", category: "Orchestral"),
            InstrumentInfo(name: "Choir", icon: "person.3.fill", category: "Orchestral"),
            InstrumentInfo(name: "Piano", icon: "pianokeys", category: "Orchestral"),
            InstrumentInfo(name: "Percussion", icon: "drum.fill", category: "Orchestral")
        ]),
        ("World", "globe", [
            InstrumentInfo(name: "Sitar", icon: "guitars.fill", category: "World"),
            InstrumentInfo(name: "Erhu", icon: "guitars", category: "World"),
            InstrumentInfo(name: "Koto", icon: "guitars", category: "World"),
            InstrumentInfo(name: "Oud", icon: "guitars.fill", category: "World"),
            InstrumentInfo(name: "Djembe", icon: "drum.fill", category: "World"),
            InstrumentInfo(name: "Kalimba", icon: "music.note", category: "World")
        ]),
        ("Drums", "drum.fill", [
            InstrumentInfo(name: "EchoelBeat", icon: "square.grid.3x3", category: "Drums"),
            InstrumentInfo(name: "Acoustic Kit", icon: "drum.fill", category: "Drums"),
            InstrumentInfo(name: "Electronic Kit", icon: "waveform.badge.mic", category: "Drums"),
            InstrumentInfo(name: "Percussion", icon: "music.note.list", category: "Drums")
        ]),
        ("Bio-Reactive", "heart.fill", [
            InstrumentInfo(name: "HeartBeat Synth", icon: "heart.fill", category: "Bio"),
            InstrumentInfo(name: "Coherence Pad", icon: "waveform.path.ecg", category: "Bio"),
            InstrumentInfo(name: "Breath Organ", icon: "wind", category: "Bio"),
            InstrumentInfo(name: "Neural Drone", icon: "brain.head.profile", category: "Bio")
        ])
    ]

    var body: some View {
        ZStack {
            VaporwaveGradients.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("INSTRUMENTS")
                        .font(VaporwaveTypography.sectionTitle())
                        .foregroundColor(VaporwaveColors.textPrimary)

                    Spacer()

                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(VaporwaveColors.textSecondary)
                    }
                }
                .padding(VaporwaveSpacing.md)

                // Categories
                ScrollView {
                    VStack(spacing: VaporwaveSpacing.lg) {
                        ForEach(categories, id: \.0) { category, icon, instruments in
                            VStack(alignment: .leading, spacing: VaporwaveSpacing.sm) {
                                VaporwaveSectionHeader(category, icon: icon)

                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: VaporwaveSpacing.sm) {
                                    ForEach(instruments, id: \.name) { instrument in
                                        InstrumentCard(instrument: instrument) {
                                            onSelect(instrument)
                                            isPresented = false
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(VaporwaveSpacing.md)
                }
            }
        }
    }
}

struct InstrumentCard: View {
    let instrument: InstrumentInfo
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: VaporwaveSpacing.sm) {
                Image(systemName: instrument.icon)
                    .font(.system(size: 24))
                    .foregroundColor(VaporwaveColors.neonCyan)

                Text(instrument.name)
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(VaporwaveSpacing.md)
            .glassCard()
        }
    }
}

// MARK: - Effects Browser Sheet

struct EffectsBrowserSheet: View {
    @Binding var isPresented: Bool
    let onSelect: (EffectInfo) -> Void

    let categories: [(String, String, [EffectInfo])] = [
        ("Dynamics", "slider.horizontal.3", [
            EffectInfo(name: "Compressor", icon: "slider.horizontal.below.rectangle", category: "Dynamics"),
            EffectInfo(name: "Limiter", icon: "gauge.high", category: "Dynamics"),
            EffectInfo(name: "Gate", icon: "rectangle.split.3x1", category: "Dynamics"),
            EffectInfo(name: "De-Esser", icon: "waveform.badge.minus", category: "Dynamics"),
            EffectInfo(name: "Transient", icon: "bolt.horizontal", category: "Dynamics")
        ]),
        ("EQ & Filter", "slider.vertical.3", [
            EffectInfo(name: "Parametric EQ", icon: "slider.vertical.3", category: "EQ"),
            EffectInfo(name: "Graphic EQ", icon: "chart.bar", category: "EQ"),
            EffectInfo(name: "Low Pass", icon: "line.diagonal", category: "Filter"),
            EffectInfo(name: "High Pass", icon: "line.diagonal", category: "Filter"),
            EffectInfo(name: "Formant", icon: "waveform.and.person.filled", category: "Filter")
        ]),
        ("Reverb & Delay", "waveform.path", [
            EffectInfo(name: "Plate Reverb", icon: "rectangle.fill", category: "Reverb"),
            EffectInfo(name: "Convolution", icon: "waveform.path.ecg", category: "Reverb"),
            EffectInfo(name: "Shimmer", icon: "sparkles", category: "Reverb"),
            EffectInfo(name: "Tape Delay", icon: "clock.arrow.2.circlepath", category: "Delay"),
            EffectInfo(name: "Ping Pong", icon: "arrow.left.arrow.right", category: "Delay"),
            EffectInfo(name: "Granular Delay", icon: "circle.grid.3x3", category: "Delay")
        ]),
        ("Modulation", "waveform.circle", [
            EffectInfo(name: "Chorus", icon: "person.2.wave.2", category: "Mod"),
            EffectInfo(name: "Flanger", icon: "arrow.trianglehead.swap", category: "Mod"),
            EffectInfo(name: "Phaser", icon: "waveform.circle", category: "Mod"),
            EffectInfo(name: "Tremolo", icon: "arrow.up.arrow.down", category: "Mod"),
            EffectInfo(name: "Ring Mod", icon: "circle.slash", category: "Mod")
        ]),
        ("Distortion", "bolt.fill", [
            EffectInfo(name: "Tube Saturation", icon: "flame.fill", category: "Dist"),
            EffectInfo(name: "Tape Warmth", icon: "sparkle", category: "Dist"),
            EffectInfo(name: "Bit Crusher", icon: "square.stack.3d.up", category: "Dist"),
            EffectInfo(name: "EchoelPunish", icon: "bolt.fill", category: "Dist")
        ]),
        ("EchoelCore (AI)", "brain.head.profile", [
            EffectInfo(name: "Bio Modulator", icon: "heart.fill", category: "AI"),
            EffectInfo(name: "AI Mastering", icon: "wand.and.stars", category: "AI"),
            EffectInfo(name: "Smart EQ", icon: "sparkles", category: "AI"),
            EffectInfo(name: "Coherence FX", icon: "waveform.path.ecg", category: "AI")
        ]),
        ("EchoelWarmth", "dial.high", [
            EffectInfo(name: "EchoelGlue", icon: "dial.high", category: "Console"),
            EffectInfo(name: "EchoelSilk", icon: "dial.medium", category: "Console"),
            EffectInfo(name: "EchoelThrust", icon: "dial.low", category: "Console"),
            EffectInfo(name: "EchoelAir", icon: "slider.horizontal.3", category: "Console"),
            EffectInfo(name: "EchoelOpto", icon: "gauge", category: "Console"),
            EffectInfo(name: "EchoelBite", icon: "speedometer", category: "Console")
        ])
    ]

    var body: some View {
        ZStack {
            VaporwaveGradients.background.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("EFFECTS")
                        .font(VaporwaveTypography.sectionTitle())
                        .foregroundColor(VaporwaveColors.textPrimary)

                    Spacer()

                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(VaporwaveColors.textSecondary)
                    }
                }
                .padding(VaporwaveSpacing.md)

                ScrollView {
                    VStack(spacing: VaporwaveSpacing.lg) {
                        ForEach(categories, id: \.0) { category, icon, effects in
                            VStack(alignment: .leading, spacing: VaporwaveSpacing.sm) {
                                VaporwaveSectionHeader(category, icon: icon)

                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: VaporwaveSpacing.sm) {
                                    ForEach(effects, id: \.name) { effect in
                                        EffectCard(effect: effect) {
                                            onSelect(effect)
                                            isPresented = false
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(VaporwaveSpacing.md)
                }
            }
        }
    }
}

struct EffectCard: View {
    let effect: EffectInfo
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: VaporwaveSpacing.sm) {
                Image(systemName: effect.icon)
                    .font(.system(size: 18))
                    .foregroundColor(VaporwaveColors.neonPurple)

                VStack(alignment: .leading, spacing: 2) {
                    Text(effect.name)
                        .font(VaporwaveTypography.caption())
                        .foregroundColor(VaporwaveColors.textPrimary)

                    Text(effect.category)
                        .font(VaporwaveTypography.label())
                        .foregroundColor(VaporwaveColors.textTertiary)
                }

                Spacer()
            }
            .padding(VaporwaveSpacing.sm)
            .glassCard()
        }
    }
}

// MARK: - Models

@MainActor
class SessionClipViewModel: ObservableObject {
    @Published var tracks: [ClipViewTrack] = []
    @Published var scenes: [ClipViewScene] = []
    @Published var clips: [[ClipViewClip?]] = []
    @Published var isRecording = false
    @Published var position: Double = 0
    @Published var quantize: QuantizeValue = .bar
    @Published var followPlayhead = true
    @Published var activeScene: Int?
    @Published var bioSyncEnabled = true

    /// Live BPM from EchoelCreativeWorkspace (single source of truth)
    var bpm: Double { EchoelCreativeWorkspace.shared.globalBPM }

    /// Live playback state from EchoelCreativeWorkspace
    var isPlaying: Bool {
        get { EchoelCreativeWorkspace.shared.isPlaying }
        set { EchoelCreativeWorkspace.shared.isPlaying = newValue }
    }

    /// Live coherence from UnifiedHealthKitEngine (real biometrics, not hardcoded)
    var coherence: Float { Float(UnifiedHealthKitEngine.shared.coherence) }

    var coherenceColor: Color {
        if coherence > 0.7 { return VaporwaveColors.coherenceHigh }
        if coherence > 0.4 { return VaporwaveColors.coherenceMedium }
        return VaporwaveColors.coherenceLow
    }

    var positionString: String {
        let bars = Int(position) + 1
        let beats = Int((position - Double(Int(position))) * 4) + 1
        return "\(bars).\(beats)"
    }

    init() {
        // Default tracks representing the core Echoelmusic instruments
        tracks = [
            ClipViewTrack(name: "Drums", color: EchoelBrand.primary, instrumentName: "EchoelBeat", instrumentIcon: "square.grid.3x3"),
            ClipViewTrack(name: "Bass", color: EchoelBrand.primary.opacity(0.7), instrumentName: "EchoSynth", instrumentIcon: "waveform"),
            ClipViewTrack(name: "Lead", color: Color.white, instrumentName: "Wavetable", instrumentIcon: "waveform.badge.plus"),
            ClipViewTrack(name: "Pad", color: EchoelBrand.primary.opacity(0.5), instrumentName: "Granular", instrumentIcon: "sparkles"),
            ClipViewTrack(name: "Bio", color: EchoelBrand.coherenceHigh, instrumentName: "Coherence", instrumentIcon: "heart.fill")
        ]

        scenes = (1...8).map { ClipViewScene(name: "Scene \($0)") }

        // Initialize empty clip grid — users create clips by recording or dragging
        clips = tracks.map { _ in
            scenes.map { _ -> ClipViewClip? in nil }
        }
    }

    func addTrack() { tracks.append(ClipViewTrack(name: "Track \(tracks.count + 1)", color: EchoelBrand.primary.opacity(0.6), instrumentName: "Empty", instrumentIcon: "questionmark")) }
    func addScene() { scenes.append(ClipViewScene(name: "Scene \(scenes.count + 1)")) }
    func toggleMute(_ index: Int) { tracks[index].isMuted.toggle() }
    func toggleSolo(_ index: Int) { tracks[index].isSoloed.toggle() }
    func toggleArm(_ index: Int) { tracks[index].isArmed.toggle() }
    func togglePlay() { EchoelCreativeWorkspace.shared.isPlaying.toggle() }
    func toggleRecord() { isRecording.toggle() }
    func stop() { EchoelCreativeWorkspace.shared.isPlaying = false; isRecording = false }
    func stopAll() { activeScene = nil }
    func launchScene(_ index: Int) { activeScene = index; EchoelCreativeWorkspace.shared.isPlaying = true }
    func clipAt(track: Int, scene: Int) -> ClipViewClip? { clips[track][scene] }
    func isClipPlaying(track: Int, scene: Int) -> Bool { activeScene == scene && clips[track][scene] != nil }
    func toggleClip(track: Int, scene: Int) {
        let loopEngine = EchoelCreativeWorkspace.shared.loopEngine
        if clips[track][scene] != nil {
            // Clip exists — toggle playback
            if loopEngine.isPlayingLoops {
                loopEngine.stopPlayback()
            } else {
                loopEngine.startPlayback()
            }
            EchoelCreativeWorkspace.shared.isPlaying = true
        } else {
            // Empty slot — record a new loop into it
            loopEngine.setTempo(bpm)
            let bars = quantize == .bar ? 4 : (quantize == .beat ? 1 : 2)
            loopEngine.startLoopRecording(bars: bars)
            clips[track][scene] = ClipViewClip(name: "\(tracks[track].name) \(scene + 1)")
        }
    }

    func editClip(track: Int, scene: Int) {
        guard clips[track][scene] != nil else { return }
        let loopEngine = EchoelCreativeWorkspace.shared.loopEngine
        // Start overdub on the last recorded loop
        if let lastLoop = loopEngine.loops.last {
            loopEngine.startOverdub(loopID: lastLoop.id)
        }
    }

    func stopClip(track: Int, scene: Int) {
        let loopEngine = EchoelCreativeWorkspace.shared.loopEngine
        if loopEngine.isRecordingLoop {
            loopEngine.stopLoopRecording()
        } else if loopEngine.isPlayingLoops {
            loopEngine.stopPlayback()
        }
    }
    func addInstrumentToTrack(_ track: Int, instrument: InstrumentInfo) { tracks[track].instrumentName = instrument.name; tracks[track].instrumentIcon = instrument.icon }
    func addEffectToTrack(_ track: Int, effect: EffectInfo) { tracks[track].effectCount += 1 }
}

struct ClipViewTrack: Identifiable {
    let id = UUID()
    var name: String
    var color: Color
    var instrumentName: String
    var instrumentIcon: String
    var effectCount: Int = 0
    var isMuted: Bool = false
    var isSoloed: Bool = false
    var isArmed: Bool = false
}

struct ClipViewScene: Identifiable {
    let id = UUID()
    var name: String
}

struct ClipViewClip: Identifiable {
    let id = UUID()
    var name: String
}

struct InstrumentInfo {
    let name: String
    let icon: String
    let category: String
}

struct EffectInfo {
    let name: String
    let icon: String
    let category: String
}

enum QuantizeValue: String {
    case bar = "1 Bar"
    case half = "1/2"
    case quarter = "1/4"
    case eighth = "1/8"
    case off = "Off"
}

#if DEBUG
#Preview {
    SessionClipView()
}
#endif
