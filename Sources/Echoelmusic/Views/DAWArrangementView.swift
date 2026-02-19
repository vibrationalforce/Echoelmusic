import SwiftUI

// MARK: - DAW Arrangement View
// Homogeneous GUI with VaporwaveTheme - "Flüssiges Licht"

/// Professional DAW arrangement interface with bio-reactive features
struct DAWArrangementView: View {
    @StateObject private var engine = ArrangementDAWProductionEngine()
    @State private var selectedTrackIndex: Int?
    @State private var timelineZoom: Double = 1.0
    @State private var showMixer = false
    @State private var showInstrumentBrowser = false
    @State private var currentBeat: Double = 0
    @State private var isPlaying = false
    @State private var bpm: Double = 120

    var body: some View {
        ZStack {
            // Background
            VaporwaveGradients.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerSection

                // Main Content
                HStack(spacing: 0) {
                    // Track List
                    trackListSection

                    // Arrangement Timeline
                    arrangementSection
                }

                // Transport Bar
                transportBar
            }

            // Instrument Browser Overlay
            if showInstrumentBrowser {
                instrumentBrowserOverlay
            }
        }
        .sheet(isPresented: $showMixer) {
            MixerSheet(engine: engine)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: VaporwaveSpacing.xs) {
                Text("DAW STUDIO")
                    .font(VaporwaveTypography.sectionTitle())
                    .foregroundColor(VaporwaveColors.textPrimary)

                Text("Bio-Reactive Production")
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.textSecondary)
            }

            Spacer()

            // BPM Display
            HStack(spacing: VaporwaveSpacing.sm) {
                Image(systemName: "metronome")
                    .foregroundColor(VaporwaveColors.neonPink)

                Text("\(Int(bpm))")
                    .font(VaporwaveTypography.data())
                    .foregroundColor(VaporwaveColors.textPrimary)

                Text("BPM")
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textSecondary)
            }
            .padding(.horizontal, VaporwaveSpacing.md)
            .padding(.vertical, VaporwaveSpacing.sm)
            .modifier(GlassCard())

            Spacer()

            // Toolbar
            HStack(spacing: VaporwaveSpacing.sm) {
                toolbarButton(icon: "slider.horizontal.3", label: "Mixer", isActive: showMixer) {
                    showMixer = true
                }

                toolbarButton(icon: "pianokeys", label: "Instruments", isActive: showInstrumentBrowser) {
                    withAnimation(VaporwaveAnimation.smooth) {
                        showInstrumentBrowser.toggle()
                    }
                }
            }
        }
        .padding(VaporwaveSpacing.md)
    }

    // MARK: - Track List Section

    private var trackListSection: some View {
        VStack(spacing: 0) {
            // Track list header
            HStack {
                Text("TRACKS")
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textSecondary)
                    .tracking(2)

                Spacer()

                Button {
                    engine.addTrack()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(VaporwaveColors.neonCyan)
                }
            }
            .padding(VaporwaveSpacing.sm)

            // Track rows
            ScrollView {
                VStack(spacing: VaporwaveSpacing.xs) {
                    ForEach(engine.tracks.indices, id: \.self) { index in
                        trackRow(track: engine.tracks[index], index: index)
                    }
                }
                .padding(.horizontal, VaporwaveSpacing.sm)
            }
        }
        .frame(width: 200)
        .background(VaporwaveColors.deepBlack.opacity(0.5))
    }

    private func trackRow(track: DAWTrack, index: Int) -> some View {
        let isSelected = selectedTrackIndex == index

        return HStack(spacing: VaporwaveSpacing.sm) {
            // Track color indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(track.color)
                .frame(width: 4, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(track.name)
                    .font(VaporwaveTypography.body())
                    .foregroundColor(VaporwaveColors.textPrimary)
                    .lineLimit(1)

                Text(track.instrumentName)
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            // Mute/Solo buttons
            HStack(spacing: 4) {
                miniButton(label: "M", isActive: track.isMuted, color: VaporwaveColors.coral)
                miniButton(label: "S", isActive: track.isSolo, color: VaporwaveColors.neonCyan)
            }
        }
        .padding(VaporwaveSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? track.color.opacity(0.15) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? track.color : Color.clear, lineWidth: 1)
        )
        .onTapGesture {
            selectedTrackIndex = index
        }
    }

    private func miniButton(label: String, isActive: Bool, color: Color) -> some View {
        Text(label)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(isActive ? VaporwaveColors.deepBlack : VaporwaveColors.textTertiary)
            .frame(width: 20, height: 20)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isActive ? color : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(color.opacity(0.5), lineWidth: 1)
            )
    }

    // MARK: - Arrangement Section

    private var arrangementSection: some View {
        VStack(spacing: 0) {
            // Timeline ruler
            timelineRuler

            // Track lanes
            ScrollView([.horizontal, .vertical]) {
                VStack(spacing: VaporwaveSpacing.xs) {
                    ForEach(engine.tracks.indices, id: \.self) { index in
                        trackLane(track: engine.tracks[index], index: index)
                    }
                }
                .padding(VaporwaveSpacing.sm)
            }
        }
        .modifier(GlassCard())
        .padding(VaporwaveSpacing.md)
    }

    private var timelineRuler: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Bar markers
                HStack(spacing: 0) {
                    ForEach(0..<32, id: \.self) { bar in
                        VStack {
                            Text("\(bar + 1)")
                                .font(VaporwaveTypography.caption())
                                .foregroundColor(VaporwaveColors.textTertiary)
                            Spacer()
                        }
                        .frame(width: 50 * timelineZoom)
                    }
                }

                // Playhead
                Rectangle()
                    .fill(VaporwaveColors.neonPink)
                    .frame(width: 2)
                    .offset(x: CGFloat(currentBeat / 4 * 50 * timelineZoom))
                    .modifier(NeonGlow(color: VaporwaveColors.neonPink, radius: 8))
            }
        }
        .frame(height: 30)
        .background(VaporwaveColors.deepBlack.opacity(0.5))
    }

    private func trackLane(track: DAWTrack, index: Int) -> some View {
        let isSelected = selectedTrackIndex == index

        return ZStack(alignment: .leading) {
            // Lane background
            RoundedRectangle(cornerRadius: 4)
                .fill(VaporwaveColors.deepBlack.opacity(0.3))
                .frame(height: 50)

            // MIDI regions/clips
            HStack(spacing: 2) {
                ForEach(track.regions) { region in
                    regionView(region: region, color: track.color)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isSelected ? track.color.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }

    private func regionView(region: DAWRegion, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(color.opacity(0.4))
            .frame(width: CGFloat(Double(region.length) * 50 * timelineZoom), height: 46)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(color, lineWidth: 1)
            )
            .overlay(
                Text(region.name)
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.textPrimary)
                    .padding(.horizontal, 4)
                , alignment: .leading
            )
            .offset(x: CGFloat(Double(region.startBar) * 50 * timelineZoom))
    }

    // MARK: - Transport Bar

    private var transportBar: some View {
        HStack(spacing: VaporwaveSpacing.lg) {
            // Position display
            VStack(spacing: 2) {
                Text(formatPosition(currentBeat))
                    .font(VaporwaveTypography.dataSmall())
                    .foregroundColor(VaporwaveColors.textPrimary)
                Text("POSITION")
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textTertiary)
            }
            .frame(width: 100)

            Spacer()

            // Transport controls
            HStack(spacing: VaporwaveSpacing.md) {
                transportButton(icon: "backward.end.fill") {
                    currentBeat = 0
                }

                transportButton(icon: "backward.fill") {
                    currentBeat = max(0, currentBeat - 4)
                }

                // Play button
                Button {
                    isPlaying.toggle()
                } label: {
                    ZStack {
                        Circle()
                            .fill(isPlaying ? VaporwaveColors.neonPink.opacity(0.3) : VaporwaveColors.neonCyan.opacity(0.2))
                            .frame(width: 56, height: 56)

                        Circle()
                            .stroke(isPlaying ? VaporwaveColors.neonPink : VaporwaveColors.neonCyan, lineWidth: 2)
                            .frame(width: 56, height: 56)

                        Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                            .font(.system(size: 22))
                            .foregroundColor(isPlaying ? VaporwaveColors.neonPink : VaporwaveColors.neonCyan)
                    }
                    .modifier(NeonGlow(color: isPlaying ? VaporwaveColors.neonPink : VaporwaveColors.neonCyan, radius: 12))
                }
                .buttonStyle(.plain)

                // Record button
                Button {
                    engine.isRecording.toggle()
                } label: {
                    ZStack {
                        Circle()
                            .fill(engine.isRecording ? VaporwaveColors.recordingActive.opacity(0.3) : Color.clear)
                            .frame(width: 44, height: 44)

                        Circle()
                            .stroke(VaporwaveColors.recordingActive, lineWidth: 2)
                            .frame(width: 44, height: 44)

                        Circle()
                            .fill(VaporwaveColors.recordingActive)
                            .frame(width: 16, height: 16)
                    }
                    .modifier(engine.isRecording ? NeonGlow(color: VaporwaveColors.recordingActive, radius: 15) : NeonGlow(color: .clear, radius: 0))
                }
                .buttonStyle(.plain)

                transportButton(icon: "forward.fill") {
                    currentBeat += 4
                }

                transportButton(icon: "forward.end.fill") {
                    currentBeat = Double(engine.projectLength)
                }
            }

            Spacer()

            // Bio-reactive indicator
            HStack(spacing: VaporwaveSpacing.sm) {
                Circle()
                    .fill(VaporwaveColors.coherenceHigh)
                    .frame(width: 8, height: 8)
                    .modifier(NeonGlow(color: VaporwaveColors.coherenceHigh, radius: 5))

                Text("Bio-Sync Active")
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.textSecondary)
            }
            .frame(width: 120)
        }
        .padding(VaporwaveSpacing.md)
        .background(VaporwaveColors.deepBlack.opacity(0.8))
    }

    // MARK: - Instrument Browser Overlay

    private var instrumentBrowserOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(VaporwaveAnimation.smooth) {
                        showInstrumentBrowser = false
                    }
                }

            VStack(spacing: VaporwaveSpacing.md) {
                // Header
                HStack {
                    Text("INSTRUMENTS")
                        .font(VaporwaveTypography.sectionTitle())
                        .foregroundColor(VaporwaveColors.textPrimary)

                    Spacer()

                    Button {
                        withAnimation(VaporwaveAnimation.smooth) {
                            showInstrumentBrowser = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(VaporwaveColors.textSecondary)
                    }
                }

                // Categories
                ScrollView {
                    VStack(spacing: VaporwaveSpacing.md) {
                        instrumentCategory("Synths", instruments: ["EchoSynth", "Pulse Drum Bass", "Wavetable", "FM Synth", "Granular"])
                        instrumentCategory("Orchestral", instruments: ["Strings", "Brass", "Woodwinds", "Choir", "Piano"])
                        instrumentCategory("World", instruments: ["Sitar", "Erhu", "Koto", "Djembe", "Kalimba"])
                        instrumentCategory("Bio-Reactive", instruments: ["Coherence Pad", "Heart Pulse", "Breath Synth"])
                    }
                }
            }
            .padding(VaporwaveSpacing.lg)
            .frame(maxWidth: 500, maxHeight: 600)
            .modifier(GlassCard())
        }
    }

    private func instrumentCategory(_ title: String, instruments: [String]) -> some View {
        VStack(alignment: .leading, spacing: VaporwaveSpacing.sm) {
            Text(title.uppercased())
                .font(VaporwaveTypography.label())
                .foregroundColor(VaporwaveColors.neonCyan)
                .tracking(2)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: VaporwaveSpacing.sm) {
                ForEach(instruments, id: \.self) { instrument in
                    Button {
                        engine.addTrack(withInstrument: instrument)
                        withAnimation(VaporwaveAnimation.smooth) {
                            showInstrumentBrowser = false
                        }
                    } label: {
                        VStack(spacing: VaporwaveSpacing.xs) {
                            Image(systemName: "pianokeys")
                                .font(.system(size: 24))
                                .foregroundColor(VaporwaveColors.neonPurple)

                            Text(instrument)
                                .font(VaporwaveTypography.caption())
                                .foregroundColor(VaporwaveColors.textPrimary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(VaporwaveSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(VaporwaveColors.deepBlack.opacity(0.5))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(VaporwaveColors.neonPurple.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Helper Views

    private func toolbarButton(icon: String, label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: VaporwaveSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(VaporwaveTypography.caption())
            }
            .foregroundColor(isActive ? VaporwaveColors.neonCyan : VaporwaveColors.textSecondary)
            .padding(.horizontal, VaporwaveSpacing.sm)
            .padding(.vertical, VaporwaveSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? VaporwaveColors.neonCyan.opacity(0.15) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func transportButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(VaporwaveColors.textSecondary)
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
    }

    private func formatPosition(_ beat: Double) -> String {
        let bar = Int(beat / 4) + 1
        let beatInBar = Int(beat.truncatingRemainder(dividingBy: 4)) + 1
        return "\(bar).\(beatInBar)"
    }
}

// MARK: - DAW Models

class ArrangementDAWProductionEngine: ObservableObject {
    @Published var tracks: [DAWTrack] = [
        DAWTrack(name: "Drums", instrumentName: "Pulse Drum", color: VaporwaveColors.neonPink),
        DAWTrack(name: "Bass", instrumentName: "EchoSynth", color: VaporwaveColors.neonCyan),
        DAWTrack(name: "Lead", instrumentName: "Wavetable", color: VaporwaveColors.neonPurple),
        DAWTrack(name: "Pad", instrumentName: "Coherence Pad", color: VaporwaveColors.lavender)
    ]
    @Published var isRecording = false
    @Published var projectLength: Int = 32 // bars

    func addTrack(withInstrument instrument: String = "EchoSynth") {
        let colors: [Color] = [VaporwaveColors.neonPink, VaporwaveColors.neonCyan, VaporwaveColors.neonPurple, VaporwaveColors.lavender, VaporwaveColors.coral]
        let newTrack = DAWTrack(
            name: "Track \(tracks.count + 1)",
            instrumentName: instrument,
            color: colors[tracks.count % colors.count]
        )
        tracks.append(newTrack)
    }
}

struct DAWTrack: Identifiable {
    let id = UUID()
    var name: String
    var instrumentName: String
    var color: Color
    var isMuted = false
    var isSolo = false
    var volume: Float = 0.8
    var pan: Float = 0.0
    var regions: [DAWRegion] = [
        DAWRegion(name: "Intro", startBar: 0, length: 4),
        DAWRegion(name: "Verse", startBar: 4, length: 8)
    ]
}

struct DAWRegion: Identifiable {
    let id = UUID()
    var name: String
    var startBar: Int
    var length: Int
}

// MARK: - Mixer Sheet

struct MixerSheet: View {
    @ObservedObject var engine: ArrangementDAWProductionEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            VaporwaveGradients.background
                .ignoresSafeArea()

            VStack(spacing: VaporwaveSpacing.md) {
                // Header
                HStack {
                    Text("MIXER")
                        .font(VaporwaveTypography.sectionTitle())
                        .foregroundColor(VaporwaveColors.textPrimary)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(VaporwaveColors.textSecondary)
                    }
                }
                .padding(.horizontal, VaporwaveSpacing.md)

                // Channel strips
                ScrollView(.horizontal) {
                    HStack(spacing: VaporwaveSpacing.md) {
                        ForEach(engine.tracks) { track in
                            channelStrip(track: track)
                        }

                        // Master channel
                        masterChannelStrip()
                    }
                    .padding(VaporwaveSpacing.md)
                }
            }
        }
    }

    private func channelStrip(track: DAWTrack) -> some View {
        VStack(spacing: VaporwaveSpacing.sm) {
            // Track name
            Text(track.name)
                .font(VaporwaveTypography.caption())
                .foregroundColor(track.color)
                .lineLimit(1)

            // Meter
            VStack(spacing: 2) {
                ForEach(0..<12, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(i > 8 ? VaporwaveColors.coherenceLow : (i > 5 ? VaporwaveColors.coherenceMedium : VaporwaveColors.coherenceHigh))
                        .frame(width: 40, height: 4)
                        .opacity(i < Int(track.volume * 12) ? 1.0 : 0.2)
                }
            }
            .padding(.vertical, VaporwaveSpacing.sm)

            // Fader
            Slider(value: .constant(Double(track.volume)), in: 0...1)
                .tint(track.color)
                .frame(height: 100)
                .rotationEffect(.degrees(-90))
                .frame(width: 100, height: 40)

            // Pan
            Text(String(format: "%.0f", track.pan * 100))
                .font(VaporwaveTypography.dataSmall())
                .foregroundColor(VaporwaveColors.textSecondary)

            // M/S buttons
            HStack(spacing: 4) {
                muteButton(isMuted: track.isMuted)
                soloButton(isSolo: track.isSolo)
            }
        }
        .frame(width: 60)
        .padding(VaporwaveSpacing.sm)
        .modifier(GlassCard())
    }

    private func masterChannelStrip() -> some View {
        VStack(spacing: VaporwaveSpacing.sm) {
            Text("MASTER")
                .font(VaporwaveTypography.caption())
                .foregroundColor(VaporwaveColors.neonPink)

            // Stereo meter
            HStack(spacing: 2) {
                meterBar()
                meterBar()
            }
            .padding(.vertical, VaporwaveSpacing.sm)

            // Fader
            Slider(value: .constant(0.8), in: 0...1)
                .tint(VaporwaveColors.neonPink)
                .frame(height: 100)
                .rotationEffect(.degrees(-90))
                .frame(width: 100, height: 40)

            Text("0.0 dB")
                .font(VaporwaveTypography.caption())
                .foregroundColor(VaporwaveColors.textSecondary)
        }
        .frame(width: 80)
        .padding(VaporwaveSpacing.sm)
        .modifier(GlassCard())
    }

    private func meterBar() -> some View {
        VStack(spacing: 2) {
            ForEach(0..<12, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(i > 8 ? VaporwaveColors.coherenceLow : (i > 5 ? VaporwaveColors.coherenceMedium : VaporwaveColors.coherenceHigh))
                    .frame(width: 16, height: 4)
                    .opacity(i < 9 ? 1.0 : 0.2)
            }
        }
    }

    private func muteButton(isMuted: Bool) -> some View {
        Text("M")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(isMuted ? VaporwaveColors.deepBlack : VaporwaveColors.textTertiary)
            .frame(width: 24, height: 24)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isMuted ? VaporwaveColors.coral : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(VaporwaveColors.coral.opacity(0.5), lineWidth: 1)
            )
    }

    private func soloButton(isSolo: Bool) -> some View {
        Text("S")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(isSolo ? VaporwaveColors.deepBlack : VaporwaveColors.textTertiary)
            .frame(width: 24, height: 24)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSolo ? VaporwaveColors.neonCyan : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(VaporwaveColors.neonCyan.opacity(0.5), lineWidth: 1)
            )
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    DAWArrangementView()
}
#endif
