import SwiftUI

// MARK: - Audio Routing Matrix View
// Professional audio routing inspired by Reaper/Pro Tools
// Full VaporwaveTheme Corporate Identity

@MainActor
struct AudioRoutingMatrixView: View {
    @StateObject private var audioRouter = AudioRouterViewModel()
    @State private var selectedChannel: AudioChannel?
    @State private var showEffectsRack = false
    @State private var showSendConfig = false

    var body: some View {
        ZStack {
            VaporwaveGradients.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView

                // Main Content
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        // Channel Strip List
                        channelStripList
                            .frame(width: min(geo.size.width * 0.65, 500))

                        // Routing Matrix
                        routingMatrix
                    }
                }
            }
        }
        .sheet(isPresented: $showEffectsRack) {
            if let channel = selectedChannel {
                EffectsRackSheet(channel: channel, isPresented: $showEffectsRack)
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: VaporwaveSpacing.xs) {
                Text("AUDIO ROUTING")
                    .font(VaporwaveTypography.sectionTitle())
                    .foregroundColor(VaporwaveColors.textPrimary)

                Text("\(audioRouter.channels.count) Channels • \(audioRouter.busses.count) Busses")
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.neonCyan)
            }

            Spacer()

            // Master Meter
            HStack(spacing: VaporwaveSpacing.sm) {
                StereoMeter(leftLevel: audioRouter.masterLeft, rightLevel: audioRouter.masterRight)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("MASTER")
                        .font(VaporwaveTypography.label())
                        .foregroundColor(VaporwaveColors.textTertiary)

                    Text(String(format: "%.1f dB", audioRouter.masterVolume))
                        .font(VaporwaveTypography.dataSmall())
                        .foregroundColor(VaporwaveColors.textPrimary)
                }
            }
            .padding(VaporwaveSpacing.md)
            .glassCard()

            // Add Channel Button
            Button(action: { audioRouter.addChannel() }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(VaporwaveColors.neonCyan)
            }
            .neonGlow(color: VaporwaveColors.neonCyan, radius: 8)
        }
        .padding(VaporwaveSpacing.md)
    }

    // MARK: - Channel Strip List

    private var channelStripList: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: VaporwaveSpacing.sm) {
                ForEach(audioRouter.channels) { channel in
                    ChannelStripView(
                        channel: channel,
                        isSelected: selectedChannel?.id == channel.id,
                        onSelect: { selectedChannel = channel },
                        onVolumeChange: { audioRouter.setVolume(channel.id, $0) },
                        onPanChange: { audioRouter.setPan(channel.id, $0) },
                        onMute: { audioRouter.toggleMute(channel.id) },
                        onSolo: { audioRouter.toggleSolo(channel.id) },
                        onEffects: {
                            selectedChannel = channel
                            showEffectsRack = true
                        }
                    )
                }

                // Busses
                ForEach(audioRouter.busses) { bus in
                    BusStripView(
                        bus: bus,
                        onVolumeChange: { audioRouter.setBusVolume(bus.id, $0) }
                    )
                }

                // Master
                MasterStripView(
                    volume: audioRouter.masterVolume,
                    leftLevel: audioRouter.masterLeft,
                    rightLevel: audioRouter.masterRight,
                    onVolumeChange: { audioRouter.masterVolume = $0 }
                )
            }
            .padding(VaporwaveSpacing.md)
        }
        .background(VaporwaveColors.deepBlack.opacity(0.5))
    }

    // MARK: - Routing Matrix

    private var routingMatrix: some View {
        VStack(spacing: 0) {
            // Matrix Header
            Text("ROUTING MATRIX")
                .font(VaporwaveTypography.label())
                .foregroundColor(VaporwaveColors.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(VaporwaveSpacing.sm)
                .background(VaporwaveColors.deepBlack.opacity(0.8))

            ScrollView {
                VStack(spacing: VaporwaveSpacing.md) {
                    // Input Section
                    VaporwaveSectionHeader("INPUTS", icon: "arrow.down.circle")

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: VaporwaveSpacing.sm) {
                        ForEach(audioRouter.inputs) { input in
                            InputRouteCard(input: input, channels: audioRouter.channels) { channelId in
                                audioRouter.routeInput(input.id, to: channelId)
                            }
                        }
                    }

                    // Sends Section
                    VaporwaveSectionHeader("SENDS", icon: "arrow.right.circle")
                        .padding(.top, VaporwaveSpacing.md)

                    ForEach(audioRouter.busses) { bus in
                        SendMatrixRow(bus: bus, channels: audioRouter.channels) { channelId, amount in
                            audioRouter.setSend(from: channelId, to: bus.id, amount: amount)
                        }
                    }

                    // Outputs Section
                    VaporwaveSectionHeader("OUTPUTS", icon: "arrow.up.circle")
                        .padding(.top, VaporwaveSpacing.md)

                    ForEach(audioRouter.outputs) { output in
                        OutputRouteCard(output: output, channels: audioRouter.channels, busses: audioRouter.busses) { sourceId in
                            audioRouter.routeToOutput(sourceId, output: output.id)
                        }
                    }

                    // Sidechain Section
                    VaporwaveSectionHeader("SIDECHAIN", icon: "arrow.triangle.branch")
                        .padding(.top, VaporwaveSpacing.md)

                    SidechainConfigView(
                        channels: audioRouter.channels,
                        sidechainSource: $audioRouter.sidechainSource,
                        sidechainTarget: $audioRouter.sidechainTarget
                    )
                }
                .padding(VaporwaveSpacing.md)
            }
        }
        .background(VaporwaveColors.midnightBlue.opacity(0.5))
    }
}

// MARK: - Channel Strip View

struct ChannelStripView: View {
    let channel: AudioChannel
    let isSelected: Bool
    let onSelect: () -> Void
    let onVolumeChange: (Float) -> Void
    let onPanChange: (Float) -> Void
    let onMute: () -> Void
    let onSolo: () -> Void
    let onEffects: () -> Void

    var body: some View {
        VStack(spacing: VaporwaveSpacing.sm) {
            // Channel Name
            Text(channel.name)
                .font(VaporwaveTypography.caption())
                .foregroundColor(isSelected ? channel.color : VaporwaveColors.textSecondary)
                .lineLimit(1)

            // Input Label
            Text(channel.inputName)
                .font(VaporwaveTypography.label())
                .foregroundColor(VaporwaveColors.textTertiary)

            // Meter
            StereoMeter(leftLevel: channel.leftLevel, rightLevel: channel.rightLevel, height: 100)

            // Fader
            VStack(spacing: 4) {
                VerticalFader(value: Binding(
                    get: { channel.volume },
                    set: { onVolumeChange($0) }
                ))
                .frame(height: 120)

                Text(String(format: "%.1f", channel.volumeDB))
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textTertiary)
            }

            // Pan
            HStack(spacing: 4) {
                Text("L")
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textTertiary)

                PanKnob(value: Binding(
                    get: { channel.pan },
                    set: { onPanChange($0) }
                ))

                Text("R")
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textTertiary)
            }

            // Buttons
            HStack(spacing: VaporwaveSpacing.xs) {
                Button(action: onMute) {
                    Text("M")
                        .font(VaporwaveTypography.label())
                        .foregroundColor(channel.isMuted ? VaporwaveColors.deepBlack : VaporwaveColors.textSecondary)
                        .frame(width: 24, height: 24)
                        .background(channel.isMuted ? VaporwaveColors.coral : Color.clear)
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(channel.isMuted ? VaporwaveColors.coral : VaporwaveColors.textTertiary, lineWidth: 1)
                        )
                }

                Button(action: onSolo) {
                    Text("S")
                        .font(VaporwaveTypography.label())
                        .foregroundColor(channel.isSoloed ? VaporwaveColors.deepBlack : VaporwaveColors.textSecondary)
                        .frame(width: 24, height: 24)
                        .background(channel.isSoloed ? VaporwaveColors.coherenceMedium : Color.clear)
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(channel.isSoloed ? VaporwaveColors.coherenceMedium : VaporwaveColors.textTertiary, lineWidth: 1)
                        )
                }
            }

            // Effects Button
            Button(action: onEffects) {
                HStack(spacing: 2) {
                    Image(systemName: "waveform")
                        .font(.system(size: 10))
                    Text("\(channel.effectCount)")
                        .font(VaporwaveTypography.label())
                }
                .foregroundColor(channel.effectCount > 0 ? VaporwaveColors.neonPurple : VaporwaveColors.textTertiary)
                .padding(.horizontal, VaporwaveSpacing.sm)
                .padding(.vertical, 4)
                .background(channel.effectCount > 0 ? VaporwaveColors.neonPurple.opacity(0.2) : Color.clear)
                .cornerRadius(8)
            }

            // Color Strip
            Rectangle()
                .fill(channel.color)
                .frame(height: 4)
                .cornerRadius(2)
        }
        .frame(width: 70)
        .padding(VaporwaveSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? VaporwaveColors.deepBlack : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? channel.color : Color.clear, lineWidth: 2)
                )
        )
        .onTapGesture { onSelect() }
    }
}

// MARK: - Bus Strip View

struct BusStripView: View {
    let bus: AudioBus
    let onVolumeChange: (Float) -> Void

    var body: some View {
        VStack(spacing: VaporwaveSpacing.sm) {
            Text(bus.name)
                .font(VaporwaveTypography.caption())
                .foregroundColor(bus.color)

            Text("BUS")
                .font(VaporwaveTypography.label())
                .foregroundColor(VaporwaveColors.textTertiary)

            StereoMeter(leftLevel: bus.leftLevel, rightLevel: bus.rightLevel, height: 100)

            VerticalFader(value: Binding(
                get: { bus.volume },
                set: { onVolumeChange($0) }
            ))
            .frame(height: 120)

            Text(String(format: "%.1f", bus.volumeDB))
                .font(VaporwaveTypography.label())
                .foregroundColor(VaporwaveColors.textTertiary)

            Rectangle()
                .fill(bus.color)
                .frame(height: 4)
                .cornerRadius(2)
        }
        .frame(width: 70)
        .padding(VaporwaveSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(bus.color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Master Strip View

struct MasterStripView: View {
    let volume: Float
    let leftLevel: Float
    let rightLevel: Float
    let onVolumeChange: (Float) -> Void

    var body: some View {
        VStack(spacing: VaporwaveSpacing.sm) {
            Text("MASTER")
                .font(VaporwaveTypography.caption())
                .foregroundColor(VaporwaveColors.neonPink)
                .neonGlow(color: VaporwaveColors.neonPink, radius: 6)

            StereoMeter(leftLevel: leftLevel, rightLevel: rightLevel, height: 100, showPeak: true)

            VerticalFader(value: Binding(
                get: { volume },
                set: { onVolumeChange($0) }
            ), accentColor: VaporwaveColors.neonPink)
            .frame(height: 120)

            Text(String(format: "%.1f dB", 20 * log10(max(volume, 0.0001))))
                .font(VaporwaveTypography.label())
                .foregroundColor(VaporwaveColors.textPrimary)

            Rectangle()
                .fill(VaporwaveGradients.neon)
                .frame(height: 4)
                .cornerRadius(2)
        }
        .frame(width: 80)
        .padding(VaporwaveSpacing.sm)
        .glassCard()
    }
}

// MARK: - UI Components

struct StereoMeter: View {
    let leftLevel: Float
    let rightLevel: Float
    var height: CGFloat = 60
    var showPeak: Bool = false

    var body: some View {
        HStack(spacing: 2) {
            MeterBar(level: leftLevel, height: height, showPeak: showPeak)
            MeterBar(level: rightLevel, height: height, showPeak: showPeak)
        }
    }
}

struct MeterBar: View {
    let level: Float
    let height: CGFloat
    var showPeak: Bool = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // Background
                RoundedRectangle(cornerRadius: 2)
                    .fill(VaporwaveColors.deepBlack)

                // Level
                RoundedRectangle(cornerRadius: 2)
                    .fill(meterGradient)
                    .frame(height: geo.size.height * CGFloat(min(level, 1.0)))

                // Peak Indicator
                if showPeak && level > 0.9 {
                    Rectangle()
                        .fill(VaporwaveColors.neonPink)
                        .frame(height: 2)
                        .offset(y: -geo.size.height * CGFloat(level) + 2)
                }
            }
        }
        .frame(width: 8, height: height)
    }

    private var meterGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                VaporwaveColors.coherenceHigh,
                VaporwaveColors.coherenceMedium,
                VaporwaveColors.coherenceLow
            ]),
            startPoint: .bottom,
            endPoint: .top
        )
    }
}

struct VerticalFader: View {
    @Binding var value: Float
    var accentColor: Color = VaporwaveColors.neonCyan

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // Track
                RoundedRectangle(cornerRadius: 4)
                    .fill(VaporwaveColors.deepBlack)
                    .frame(width: 8)

                // Fill
                RoundedRectangle(cornerRadius: 4)
                    .fill(accentColor)
                    .frame(width: 8, height: geo.size.height * CGFloat(value))

                // Handle
                RoundedRectangle(cornerRadius: 4)
                    .fill(VaporwaveColors.textPrimary)
                    .frame(width: 30, height: 16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(accentColor, lineWidth: 1)
                    )
                    .offset(y: -geo.size.height * CGFloat(value) + 8)
                    .gesture(
                        DragGesture()
                            .onChanged { drag in
                                let newValue = 1 - Float(drag.location.y / geo.size.height)
                                value = max(0, min(1, newValue))
                            }
                    )
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct PanKnob: View {
    @Binding var value: Float

    var body: some View {
        ZStack {
            Circle()
                .stroke(VaporwaveColors.textTertiary, lineWidth: 2)
                .frame(width: 30, height: 30)

            Circle()
                .fill(VaporwaveColors.deepBlack)
                .frame(width: 26, height: 26)

            // Indicator
            Rectangle()
                .fill(VaporwaveColors.neonCyan)
                .frame(width: 2, height: 10)
                .offset(y: -8)
                .rotationEffect(.degrees(Double(value - 0.5) * 270))
        }
        .gesture(
            DragGesture()
                .onChanged { drag in
                    let delta = Float(drag.translation.width) / 100
                    value = max(0, min(1, value + delta))
                }
        )
    }
}

// MARK: - Routing Components

struct InputRouteCard: View {
    let input: AudioInput
    let channels: [AudioChannel]
    let onRoute: (UUID?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: VaporwaveSpacing.sm) {
            HStack {
                Image(systemName: input.icon)
                    .foregroundColor(VaporwaveColors.neonCyan)

                Text(input.name)
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.textPrimary)
            }

            Picker("Route to", selection: Binding(
                get: { input.routedTo },
                set: { onRoute($0) }
            )) {
                Text("None").tag(nil as UUID?)
                ForEach(channels) { channel in
                    Text(channel.name).tag(channel.id as UUID?)
                }
            }
            .pickerStyle(.menu)
            .font(VaporwaveTypography.caption())
        }
        .padding(VaporwaveSpacing.sm)
        .glassCard()
    }
}

struct SendMatrixRow: View {
    let bus: AudioBus
    let channels: [AudioChannel]
    let onSendChange: (UUID, Float) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: VaporwaveSpacing.sm) {
            HStack {
                Circle()
                    .fill(bus.color)
                    .frame(width: 10, height: 10)

                Text(bus.name)
                    .font(VaporwaveTypography.body())
                    .foregroundColor(bus.color)

                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: VaporwaveSpacing.sm) {
                    ForEach(channels) { channel in
                        SendKnob(
                            channelName: channel.name,
                            color: channel.color,
                            value: channel.sends[bus.id] ?? 0,
                            onValueChange: { onSendChange(channel.id, $0) }
                        )
                    }
                }
            }
        }
        .padding(VaporwaveSpacing.md)
        .glassCard()
    }
}

struct SendKnob: View {
    let channelName: String
    let color: Color
    var value: Float
    let onValueChange: (Float) -> Void

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(VaporwaveColors.textTertiary.opacity(0.3), lineWidth: 3)
                    .frame(width: 36, height: 36)

                Circle()
                    .trim(from: 0, to: CGFloat(value))
                    .stroke(color, lineWidth: 3)
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(-90))

                Text(String(format: "%.0f", value * 100))
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textSecondary)
            }
            .gesture(
                DragGesture()
                    .onChanged { drag in
                        let delta = Float(-drag.translation.height) / 100
                        onValueChange(max(0, min(1, value + delta)))
                    }
            )

            Text(channelName)
                .font(VaporwaveTypography.label())
                .foregroundColor(VaporwaveColors.textTertiary)
                .lineLimit(1)
        }
        .frame(width: 50)
    }
}

struct OutputRouteCard: View {
    let output: AudioOutput
    let channels: [AudioChannel]
    let busses: [AudioBus]
    let onRoute: (UUID?) -> Void

    var body: some View {
        HStack {
            Image(systemName: output.icon)
                .foregroundColor(VaporwaveColors.neonPink)

            Text(output.name)
                .font(VaporwaveTypography.body())
                .foregroundColor(VaporwaveColors.textPrimary)

            Spacer()

            Picker("Source", selection: Binding(
                get: { output.sourceId },
                set: { onRoute($0) }
            )) {
                Text("Master").tag(nil as UUID?)
                ForEach(channels) { ch in
                    Text(ch.name).tag(ch.id as UUID?)
                }
                ForEach(busses) { bus in
                    Text(bus.name).tag(bus.id as UUID?)
                }
            }
            .pickerStyle(.menu)
        }
        .padding(VaporwaveSpacing.md)
        .glassCard()
    }
}

struct SidechainConfigView: View {
    let channels: [AudioChannel]
    @Binding var sidechainSource: UUID?
    @Binding var sidechainTarget: UUID?

    var body: some View {
        VStack(spacing: VaporwaveSpacing.md) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Source (Key)")
                        .font(VaporwaveTypography.caption())
                        .foregroundColor(VaporwaveColors.textTertiary)

                    Picker("Source", selection: $sidechainSource) {
                        Text("None").tag(nil as UUID?)
                        ForEach(channels) { ch in
                            Text(ch.name).tag(ch.id as UUID?)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Image(systemName: "arrow.right")
                    .foregroundColor(VaporwaveColors.neonPurple)

                VStack(alignment: .leading) {
                    Text("Target (Comp)")
                        .font(VaporwaveTypography.caption())
                        .foregroundColor(VaporwaveColors.textTertiary)

                    Picker("Target", selection: $sidechainTarget) {
                        Text("None").tag(nil as UUID?)
                        ForEach(channels) { ch in
                            Text(ch.name).tag(ch.id as UUID?)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            if sidechainSource != nil && sidechainTarget != nil {
                Text("Sidechain compression active")
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.neonPurple)
            }
        }
        .padding(VaporwaveSpacing.md)
        .glassCard()
    }
}

// MARK: - Effects Rack Sheet

struct EffectsRackSheet: View {
    let channel: AudioChannel
    @Binding var isPresented: Bool
    @State private var effects: [AudioEffect] = []

    var body: some View {
        ZStack {
            VaporwaveGradients.background.ignoresSafeArea()

            VStack(spacing: VaporwaveSpacing.md) {
                // Header
                HStack {
                    Text("EFFECTS RACK")
                        .font(VaporwaveTypography.sectionTitle())
                        .foregroundColor(VaporwaveColors.textPrimary)

                    Spacer()

                    Text(channel.name)
                        .font(VaporwaveTypography.caption())
                        .foregroundColor(channel.color)

                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(VaporwaveColors.textSecondary)
                    }
                }
                .padding(VaporwaveSpacing.md)

                // Effects Chain
                ScrollView {
                    VStack(spacing: VaporwaveSpacing.sm) {
                        ForEach(effects.indices, id: \.self) { index in
                            EffectSlotView(effect: $effects[index])
                        }

                        // Add Effect Button
                        Button(action: { addEffect() }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Effect")
                            }
                            .font(VaporwaveTypography.body())
                            .foregroundColor(VaporwaveColors.neonCyan)
                            .frame(maxWidth: .infinity)
                            .padding(VaporwaveSpacing.lg)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(VaporwaveColors.neonCyan, style: StrokeStyle(lineWidth: 2, dash: [8]))
                            )
                        }
                    }
                    .padding(VaporwaveSpacing.md)
                }
            }
        }
        .onAppear {
            // Load channel effects
            effects = [
                AudioEffect(name: "EQ", type: .eq, isEnabled: true, parameters: [:]),
                AudioEffect(name: "Compressor", type: .compressor, isEnabled: true, parameters: [:]),
                AudioEffect(name: "Reverb", type: .reverb, isEnabled: false, parameters: [:])
            ]
        }
    }

    private func addEffect() {
        effects.append(AudioEffect(name: "New Effect", type: .eq, isEnabled: true, parameters: [:]))
    }
}

struct EffectSlotView: View {
    @Binding var effect: AudioEffect

    var body: some View {
        VStack(spacing: VaporwaveSpacing.sm) {
            HStack {
                // Power Button
                Button(action: { effect.isEnabled.toggle() }) {
                    Image(systemName: "power")
                        .foregroundColor(effect.isEnabled ? VaporwaveColors.neonCyan : VaporwaveColors.textTertiary)
                }

                Text(effect.name)
                    .font(VaporwaveTypography.body())
                    .foregroundColor(effect.isEnabled ? VaporwaveColors.textPrimary : VaporwaveColors.textTertiary)

                Spacer()

                // Effect Type Badge
                Text(effect.type.rawValue.uppercased())
                    .font(VaporwaveTypography.label())
                    .foregroundColor(effect.type.color)
                    .padding(.horizontal, VaporwaveSpacing.sm)
                    .padding(.vertical, 2)
                    .background(effect.type.color.opacity(0.2))
                    .cornerRadius(4)

                Image(systemName: "line.3.horizontal")
                    .foregroundColor(VaporwaveColors.textTertiary)
            }

            // Parameters Preview
            if effect.isEnabled {
                HStack(spacing: VaporwaveSpacing.lg) {
                    ForEach(effect.type.defaultParams, id: \.self) { param in
                        VStack(spacing: 2) {
                            Text("0")
                                .font(VaporwaveTypography.dataSmall())
                                .foregroundColor(VaporwaveColors.textSecondary)
                            Text(param)
                                .font(VaporwaveTypography.label())
                                .foregroundColor(VaporwaveColors.textTertiary)
                        }
                    }
                }
            }
        }
        .padding(VaporwaveSpacing.md)
        .glassCard()
    }
}

// MARK: - Models

@MainActor
class AudioRouterViewModel: ObservableObject {
    @Published var channels: [AudioChannel] = []
    @Published var busses: [AudioBus] = []
    @Published var inputs: [AudioInput] = []
    @Published var outputs: [AudioOutput] = []
    @Published var masterVolume: Float = 0.8
    @Published var masterLeft: Float = 0.6
    @Published var masterRight: Float = 0.55
    @Published var sidechainSource: UUID?
    @Published var sidechainTarget: UUID?

    init() {
        // Sample data
        channels = [
            AudioChannel(id: UUID(), name: "Drums", color: VaporwaveColors.neonPink, volume: 0.75, pan: 0.5, leftLevel: 0.7, rightLevel: 0.65),
            AudioChannel(id: UUID(), name: "Bass", color: VaporwaveColors.neonCyan, volume: 0.8, pan: 0.5, leftLevel: 0.6, rightLevel: 0.6),
            AudioChannel(id: UUID(), name: "Synth", color: VaporwaveColors.neonPurple, volume: 0.6, pan: 0.3, leftLevel: 0.5, rightLevel: 0.4),
            AudioChannel(id: UUID(), name: "Vocals", color: VaporwaveColors.coral, volume: 0.7, pan: 0.5, leftLevel: 0.55, rightLevel: 0.55),
            AudioChannel(id: UUID(), name: "FX", color: VaporwaveColors.lavender, volume: 0.5, pan: 0.7, leftLevel: 0.3, rightLevel: 0.4)
        ]

        busses = [
            AudioBus(id: UUID(), name: "Reverb", color: VaporwaveColors.neonCyan, volume: 0.6, leftLevel: 0.4, rightLevel: 0.4),
            AudioBus(id: UUID(), name: "Delay", color: VaporwaveColors.neonPurple, volume: 0.5, leftLevel: 0.35, rightLevel: 0.35)
        ]

        inputs = [
            AudioInput(id: UUID(), name: "Mic 1", icon: "mic.fill", routedTo: channels[3].id),
            AudioInput(id: UUID(), name: "Line In L", icon: "cable.connector", routedTo: nil),
            AudioInput(id: UUID(), name: "Line In R", icon: "cable.connector", routedTo: nil)
        ]

        outputs = [
            AudioOutput(id: UUID(), name: "Main L/R", icon: "speaker.wave.3", sourceId: nil),
            AudioOutput(id: UUID(), name: "Headphones", icon: "headphones", sourceId: nil)
        ]
    }

    func setVolume(_ id: UUID, _ vol: Float) { if let i = channels.firstIndex(where: { $0.id == id }) { channels[i].volume = vol } }
    func setPan(_ id: UUID, _ pan: Float) { if let i = channels.firstIndex(where: { $0.id == id }) { channels[i].pan = pan } }
    func toggleMute(_ id: UUID) { if let i = channels.firstIndex(where: { $0.id == id }) { channels[i].isMuted.toggle() } }
    func toggleSolo(_ id: UUID) { if let i = channels.firstIndex(where: { $0.id == id }) { channels[i].isSoloed.toggle() } }
    func setBusVolume(_ id: UUID, _ vol: Float) { if let i = busses.firstIndex(where: { $0.id == id }) { busses[i].volume = vol } }
    func routeInput(_ inputId: UUID, to channelId: UUID?) { if let i = inputs.firstIndex(where: { $0.id == inputId }) { inputs[i].routedTo = channelId } }
    func setSend(from channelId: UUID, to busId: UUID, amount: Float) { if let i = channels.firstIndex(where: { $0.id == channelId }) { channels[i].sends[busId] = amount } }
    func routeToOutput(_ sourceId: UUID?, output: UUID) { if let i = outputs.firstIndex(where: { $0.id == output }) { outputs[i].sourceId = sourceId } }
    func addChannel() { channels.append(AudioChannel(id: UUID(), name: "Track \(channels.count + 1)", color: VaporwaveColors.neonCyan, volume: 0.7, pan: 0.5, leftLevel: 0, rightLevel: 0)) }
}

struct AudioChannel: Identifiable {
    let id: UUID
    var name: String
    var color: Color
    var volume: Float
    var pan: Float
    var leftLevel: Float
    var rightLevel: Float
    var isMuted: Bool = false
    var isSoloed: Bool = false
    var effectCount: Int = 2
    var inputName: String = "Input"
    var sends: [UUID: Float] = [:]

    var volumeDB: Float { 20 * log10(max(volume, 0.0001)) }
}

struct AudioBus: Identifiable {
    let id: UUID
    var name: String
    var color: Color
    var volume: Float
    var leftLevel: Float
    var rightLevel: Float

    var volumeDB: Float { 20 * log10(max(volume, 0.0001)) }
}

struct AudioInput: Identifiable {
    let id: UUID
    var name: String
    var icon: String
    var routedTo: UUID?
}

struct AudioOutput: Identifiable {
    let id: UUID
    var name: String
    var icon: String
    var sourceId: UUID?
}

struct AudioEffect: Identifiable {
    let id = UUID()
    var name: String
    var type: EffectType
    var isEnabled: Bool
    var parameters: [String: Float]
}

enum EffectType: String {
    case eq = "EQ"
    case compressor = "Comp"
    case reverb = "Reverb"
    case delay = "Delay"
    case distortion = "Dist"
    case filter = "Filter"

    var color: Color {
        switch self {
        case .eq: return VaporwaveColors.neonCyan
        case .compressor: return VaporwaveColors.neonPink
        case .reverb: return VaporwaveColors.neonPurple
        case .delay: return VaporwaveColors.coral
        case .distortion: return VaporwaveColors.coherenceLow
        case .filter: return VaporwaveColors.lavender
        }
    }

    var defaultParams: [String] {
        switch self {
        case .eq: return ["Low", "Mid", "High"]
        case .compressor: return ["Thresh", "Ratio", "Attack"]
        case .reverb: return ["Size", "Decay", "Mix"]
        case .delay: return ["Time", "FB", "Mix"]
        case .distortion: return ["Drive", "Tone"]
        case .filter: return ["Cutoff", "Reso"]
        }
    }
}

#Preview {
    AudioRoutingMatrixView()
}
