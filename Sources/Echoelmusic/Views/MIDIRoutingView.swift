import SwiftUI

// MARK: - MIDI Routing View
// Professional MIDI 1.0/2.0/MPE routing matrix inspired by Ableton/Reaper
// Full VaporwaveTheme Corporate Identity

@MainActor
struct MIDIRoutingView: View {
    @StateObject private var midiRouter = MIDIRouterViewModel()
    @State private var selectedTab: MIDITab = .devices
    @State private var showMIDILearn = false
    @State private var selectedMapping: MIDIMappingItem?

    enum MIDITab: String, CaseIterable {
        case devices = "Devices"
        case routing = "Routing"
        case mappings = "Mappings"
        case mpe = "MPE"
    }

    var body: some View {
        ZStack {
            VaporwaveGradients.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView

                // Tab Bar
                tabBarView

                // Content
                ScrollView {
                    switch selectedTab {
                    case .devices:
                        devicesView
                    case .routing:
                        routingMatrixView
                    case .mappings:
                        mappingsView
                    case .mpe:
                        mpeView
                    }
                }
            }
        }
        .sheet(isPresented: $showMIDILearn) {
            MIDILearnSheet(isPresented: $showMIDILearn, onMapped: { mapping in
                midiRouter.addMapping(mapping)
            })
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: VaporwaveSpacing.xs) {
                Text("MIDI CONTROL")
                    .font(VaporwaveTypography.sectionTitle())
                    .foregroundColor(VaporwaveColors.textPrimary)

                Text("MIDI 1.0 / 2.0 / MPE")
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.neonCyan)
            }

            Spacer()

            // MIDI Activity Indicator
            HStack(spacing: VaporwaveSpacing.sm) {
                Circle()
                    .fill(midiRouter.isReceiving ? VaporwaveColors.neonCyan : VaporwaveColors.textTertiary)
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut(duration: 0.1), value: midiRouter.isReceiving)

                Text("IN")
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textSecondary)

                Circle()
                    .fill(midiRouter.isSending ? VaporwaveColors.neonPink : VaporwaveColors.textTertiary)
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut(duration: 0.1), value: midiRouter.isSending)

                Text("OUT")
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textSecondary)
            }
            .padding(.horizontal, VaporwaveSpacing.md)
            .padding(.vertical, VaporwaveSpacing.sm)
            .glassCard()
        }
        .padding(VaporwaveSpacing.md)
    }

    // MARK: - Tab Bar

    private var tabBarView: some View {
        HStack(spacing: VaporwaveSpacing.sm) {
            ForEach(MIDITab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(VaporwaveAnimation.smooth) {
                        selectedTab = tab
                    }
                }) {
                    Text(tab.rawValue)
                        .font(VaporwaveTypography.caption())
                        .foregroundColor(selectedTab == tab ? VaporwaveColors.deepBlack : VaporwaveColors.textSecondary)
                        .padding(.horizontal, VaporwaveSpacing.md)
                        .padding(.vertical, VaporwaveSpacing.sm)
                        .background(
                            Capsule()
                                .fill(selectedTab == tab ? VaporwaveColors.neonCyan : Color.clear)
                        )
                        .overlay(
                            Capsule()
                                .stroke(selectedTab == tab ? VaporwaveColors.neonCyan : VaporwaveColors.textTertiary, lineWidth: 1)
                        )
                }
                .neonGlow(color: selectedTab == tab ? VaporwaveColors.neonCyan : .clear, radius: 8)
            }
        }
        .padding(.horizontal, VaporwaveSpacing.md)
        .padding(.bottom, VaporwaveSpacing.md)
    }

    // MARK: - Devices View

    private var devicesView: some View {
        VStack(spacing: VaporwaveSpacing.md) {
            VaporwaveSectionHeader("INPUT DEVICES", icon: "pianokeys")

            ForEach(midiRouter.inputDevices, id: \.id) { device in
                MIDIDeviceRow(
                    device: device,
                    isInput: true,
                    isEnabled: midiRouter.enabledInputs.contains(device.id),
                    onToggle: { midiRouter.toggleInput(device.id) }
                )
            }

            if midiRouter.inputDevices.isEmpty {
                emptyDeviceState(message: "No MIDI inputs detected")
            }

            VaporwaveSectionHeader("OUTPUT DEVICES", icon: "speaker.wave.3")
                .padding(.top, VaporwaveSpacing.lg)

            ForEach(midiRouter.outputDevices, id: \.id) { device in
                MIDIDeviceRow(
                    device: device,
                    isInput: false,
                    isEnabled: midiRouter.enabledOutputs.contains(device.id),
                    onToggle: { midiRouter.toggleOutput(device.id) }
                )
            }

            if midiRouter.outputDevices.isEmpty {
                emptyDeviceState(message: "No MIDI outputs detected")
            }

            // Virtual MIDI 2.0 Source
            VaporwaveSectionHeader("VIRTUAL MIDI 2.0", icon: "waveform")
                .padding(.top, VaporwaveSpacing.lg)

            VStack(spacing: VaporwaveSpacing.sm) {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundColor(VaporwaveColors.neonPurple)

                    Text("Echoelmusic MIDI 2.0 Output")
                        .font(VaporwaveTypography.body())
                        .foregroundColor(VaporwaveColors.textPrimary)

                    Spacer()

                    Text("UMP")
                        .font(VaporwaveTypography.label())
                        .foregroundColor(VaporwaveColors.neonCyan)
                        .padding(.horizontal, VaporwaveSpacing.sm)
                        .padding(.vertical, VaporwaveSpacing.xs)
                        .background(VaporwaveColors.neonCyan.opacity(0.2))
                        .cornerRadius(4)

                    VaporwaveStatusIndicator(isActive: midiRouter.virtualSourceActive, activeColor: VaporwaveColors.neonPurple)
                }

                Text("32-bit resolution • Per-note controllers • UMP protocol")
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.textTertiary)
            }
            .padding(VaporwaveSpacing.md)
            .glassCard()
        }
        .padding(VaporwaveSpacing.md)
    }

    private func emptyDeviceState(message: String) -> some View {
        HStack {
            Image(systemName: "cable.connector.horizontal")
                .foregroundColor(VaporwaveColors.textTertiary)
            Text(message)
                .font(VaporwaveTypography.caption())
                .foregroundColor(VaporwaveColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(VaporwaveSpacing.lg)
        .glassCard()
    }

    // MARK: - Routing Matrix View

    private var routingMatrixView: some View {
        VStack(spacing: VaporwaveSpacing.md) {
            VaporwaveSectionHeader("ROUTING MATRIX", icon: "arrow.triangle.branch")

            // Matrix Grid
            VStack(spacing: 2) {
                // Header Row
                HStack(spacing: 2) {
                    Text("IN / OUT")
                        .font(VaporwaveTypography.label())
                        .foregroundColor(VaporwaveColors.textTertiary)
                        .frame(width: 80)

                    ForEach(midiRouter.outputDevices, id: \.id) { output in
                        Text(String(output.name.prefix(8)))
                            .font(VaporwaveTypography.label())
                            .foregroundColor(VaporwaveColors.neonCyan)
                            .frame(width: 60)
                            .lineLimit(1)
                    }

                    Text("Virtual")
                        .font(VaporwaveTypography.label())
                        .foregroundColor(VaporwaveColors.neonPurple)
                        .frame(width: 60)
                }
                .padding(.vertical, VaporwaveSpacing.sm)

                // Matrix Rows
                ForEach(midiRouter.inputDevices, id: \.id) { input in
                    HStack(spacing: 2) {
                        Text(String(input.name.prefix(10)))
                            .font(VaporwaveTypography.label())
                            .foregroundColor(VaporwaveColors.textSecondary)
                            .frame(width: 80, alignment: .leading)
                            .lineLimit(1)

                        ForEach(midiRouter.outputDevices, id: \.id) { output in
                            RoutingMatrixCell(
                                isRouted: midiRouter.isRouted(from: input.id, to: output.id),
                                onToggle: { midiRouter.toggleRoute(from: input.id, to: output.id) }
                            )
                        }

                        // Virtual Output
                        RoutingMatrixCell(
                            isRouted: midiRouter.isRoutedToVirtual(from: input.id),
                            onToggle: { midiRouter.toggleVirtualRoute(from: input.id) },
                            color: VaporwaveColors.neonPurple
                        )
                    }
                }
            }
            .padding(VaporwaveSpacing.md)
            .glassCard()

            // Channel Filter
            VaporwaveSectionHeader("CHANNEL FILTER", icon: "line.3.horizontal.decrease.circle")
                .padding(.top, VaporwaveSpacing.lg)

            channelFilterGrid

            // Message Filter
            VaporwaveSectionHeader("MESSAGE FILTER", icon: "slider.horizontal.3")
                .padding(.top, VaporwaveSpacing.lg)

            messageFilterToggles
        }
        .padding(VaporwaveSpacing.md)
    }

    private var channelFilterGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 8), spacing: 4) {
            ForEach(1...16, id: \.self) { channel in
                Button(action: { midiRouter.toggleChannel(channel) }) {
                    Text("\(channel)")
                        .font(VaporwaveTypography.label())
                        .foregroundColor(midiRouter.enabledChannels.contains(channel) ? VaporwaveColors.deepBlack : VaporwaveColors.textTertiary)
                        .frame(width: 36, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(midiRouter.enabledChannels.contains(channel) ? VaporwaveColors.neonCyan : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(midiRouter.enabledChannels.contains(channel) ? VaporwaveColors.neonCyan : VaporwaveColors.textTertiary.opacity(0.3), lineWidth: 1)
                        )
                }
            }
        }
        .padding(VaporwaveSpacing.md)
        .glassCard()
    }

    private var messageFilterToggles: some View {
        VStack(spacing: VaporwaveSpacing.sm) {
            ForEach(MIDIMessageType.allCases, id: \.self) { type in
                HStack {
                    Image(systemName: type.icon)
                        .foregroundColor(VaporwaveColors.neonCyan)
                        .frame(width: 24)

                    Text(type.name)
                        .font(VaporwaveTypography.body())
                        .foregroundColor(VaporwaveColors.textPrimary)

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { midiRouter.enabledMessageTypes.contains(type) },
                        set: { _ in midiRouter.toggleMessageType(type) }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: VaporwaveColors.neonCyan))
                }
            }
        }
        .padding(VaporwaveSpacing.md)
        .glassCard()
    }

    // MARK: - Mappings View

    private var mappingsView: some View {
        VStack(spacing: VaporwaveSpacing.md) {
            HStack {
                VaporwaveSectionHeader("MIDI MAPPINGS", icon: "arrow.left.arrow.right")

                Spacer()

                Button(action: { showMIDILearn = true }) {
                    HStack(spacing: VaporwaveSpacing.sm) {
                        Image(systemName: "plus.circle.fill")
                        Text("MIDI Learn")
                    }
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.neonPink)
                    .padding(.horizontal, VaporwaveSpacing.md)
                    .padding(.vertical, VaporwaveSpacing.sm)
                    .background(VaporwaveColors.neonPink.opacity(0.2))
                    .cornerRadius(16)
                }
                .neonGlow(color: VaporwaveColors.neonPink, radius: 6)
            }

            if midiRouter.mappings.isEmpty {
                VaporwaveEmptyState(
                    icon: "pianokeys",
                    title: "No Mappings",
                    message: "Use MIDI Learn to map controllers to parameters",
                    actionTitle: "Start MIDI Learn",
                    action: { showMIDILearn = true }
                )
            } else {
                ForEach(midiRouter.mappings, id: \.id) { mapping in
                    MIDIMappingRow(mapping: mapping, onDelete: {
                        midiRouter.removeMapping(mapping.id)
                    })
                }
            }

            // Quick Mappings Presets
            VaporwaveSectionHeader("QUICK PRESETS", icon: "star")
                .padding(.top, VaporwaveSpacing.lg)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: VaporwaveSpacing.sm) {
                QuickPresetCard(name: "Ableton Push", icon: "square.grid.3x3", color: VaporwaveColors.neonPurple) {
                    midiRouter.loadPreset(.abletonPush)
                }
                QuickPresetCard(name: "Novation Launch", icon: "square.grid.4x3.fill", color: VaporwaveColors.neonCyan) {
                    midiRouter.loadPreset(.novationLaunch)
                }
                QuickPresetCard(name: "Akai MPK", icon: "pianokeys.inverse", color: VaporwaveColors.neonPink) {
                    midiRouter.loadPreset(.akaiMPK)
                }
                QuickPresetCard(name: "Generic CC", icon: "slider.horizontal.3", color: VaporwaveColors.coral) {
                    midiRouter.loadPreset(.genericCC)
                }
            }
        }
        .padding(VaporwaveSpacing.md)
    }

    // MARK: - MPE View

    private var mpeView: some View {
        VStack(spacing: VaporwaveSpacing.md) {
            VaporwaveSectionHeader("MPE CONFIGURATION", icon: "waveform.path.ecg")

            // MPE Status
            HStack {
                VStack(alignment: .leading, spacing: VaporwaveSpacing.xs) {
                    Text("MIDI Polyphonic Expression")
                        .font(VaporwaveTypography.body())
                        .foregroundColor(VaporwaveColors.textPrimary)

                    Text("Per-note pitch bend, slide, pressure")
                        .font(VaporwaveTypography.caption())
                        .foregroundColor(VaporwaveColors.textTertiary)
                }

                Spacer()

                Toggle("", isOn: $midiRouter.mpeEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: VaporwaveColors.neonPurple))
            }
            .padding(VaporwaveSpacing.md)
            .glassCard()

            if midiRouter.mpeEnabled {
                // Zone Configuration
                VaporwaveSectionHeader("ZONE CONFIGURATION", icon: "rectangle.split.3x1")
                    .padding(.top, VaporwaveSpacing.md)

                VStack(spacing: VaporwaveSpacing.md) {
                    // Lower Zone
                    MPEZoneConfig(
                        title: "Lower Zone",
                        masterChannel: 1,
                        memberChannels: midiRouter.lowerZoneChannels,
                        pitchBendRange: $midiRouter.lowerPitchBend,
                        color: VaporwaveColors.neonCyan,
                        onChannelsChanged: { midiRouter.setLowerZoneChannels($0) }
                    )

                    // Upper Zone
                    MPEZoneConfig(
                        title: "Upper Zone",
                        masterChannel: 16,
                        memberChannels: midiRouter.upperZoneChannels,
                        pitchBendRange: $midiRouter.upperPitchBend,
                        color: VaporwaveColors.neonPink,
                        onChannelsChanged: { midiRouter.setUpperZoneChannels($0) }
                    )
                }

                // Per-Note Controllers
                VaporwaveSectionHeader("PER-NOTE CONTROLLERS", icon: "dial.high")
                    .padding(.top, VaporwaveSpacing.md)

                VStack(spacing: VaporwaveSpacing.sm) {
                    PerNoteControllerRow(name: "Pitch Bend", cc: "PB", value: midiRouter.lastPitchBend, color: VaporwaveColors.neonCyan)
                    PerNoteControllerRow(name: "Pressure", cc: "AT", value: midiRouter.lastPressure, color: VaporwaveColors.neonPink)
                    PerNoteControllerRow(name: "Slide (CC74)", cc: "74", value: midiRouter.lastSlide, color: VaporwaveColors.neonPurple)
                    PerNoteControllerRow(name: "Expression", cc: "11", value: midiRouter.lastExpression, color: VaporwaveColors.coral)
                }
                .padding(VaporwaveSpacing.md)
                .glassCard()

                // Voice Allocation
                VaporwaveSectionHeader("VOICE ALLOCATION", icon: "person.3")
                    .padding(.top, VaporwaveSpacing.md)

                Picker("Mode", selection: $midiRouter.voiceAllocationMode) {
                    Text("Round Robin").tag(VoiceAllocationMode.roundRobin)
                    Text("LRU").tag(VoiceAllocationMode.lru)
                    Text("Low Priority").tag(VoiceAllocationMode.lowPriority)
                    Text("High Priority").tag(VoiceAllocationMode.highPriority)
                }
                .pickerStyle(.segmented)
                .padding(VaporwaveSpacing.md)
                .glassCard()
            }
        }
        .padding(VaporwaveSpacing.md)
    }
}

// MARK: - Supporting Views

struct MIDIDeviceRow: View {
    let device: MIDIDeviceInfo
    let isInput: Bool
    let isEnabled: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack {
            Image(systemName: isInput ? "arrow.down.circle" : "arrow.up.circle")
                .foregroundColor(isInput ? VaporwaveColors.neonCyan : VaporwaveColors.neonPink)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(VaporwaveTypography.body())
                    .foregroundColor(VaporwaveColors.textPrimary)

                Text(device.manufacturer)
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.textTertiary)
            }

            Spacer()

            if device.supportsMIDI2 {
                Text("2.0")
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.neonPurple)
                    .padding(.horizontal, VaporwaveSpacing.sm)
                    .padding(.vertical, 2)
                    .background(VaporwaveColors.neonPurple.opacity(0.2))
                    .cornerRadius(4)
            }

            Toggle("", isOn: Binding(get: { isEnabled }, set: { _ in onToggle() }))
                .toggleStyle(SwitchToggleStyle(tint: isInput ? VaporwaveColors.neonCyan : VaporwaveColors.neonPink))
        }
        .padding(VaporwaveSpacing.md)
        .glassCard()
    }
}

struct RoutingMatrixCell: View {
    let isRouted: Bool
    let onToggle: () -> Void
    var color: Color = VaporwaveColors.neonCyan

    var body: some View {
        Button(action: onToggle) {
            RoundedRectangle(cornerRadius: 4)
                .fill(isRouted ? color : Color.clear)
                .frame(width: 60, height: 30)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isRouted ? color : VaporwaveColors.textTertiary.opacity(0.3), lineWidth: 1)
                )
                .overlay(
                    Image(systemName: isRouted ? "arrow.right" : "")
                        .font(.system(size: 12))
                        .foregroundColor(VaporwaveColors.deepBlack)
                )
        }
        .neonGlow(color: isRouted ? color : .clear, radius: 4)
    }
}

struct MIDIMappingRow: View {
    let mapping: MIDIMappingItem
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(mapping.parameterName)
                    .font(VaporwaveTypography.body())
                    .foregroundColor(VaporwaveColors.textPrimary)

                Text("Ch \(mapping.channel) • CC \(mapping.cc)")
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.neonCyan)
            }

            Spacer()

            // Value Indicator
            VaporwaveProgressRing(
                progress: Double(mapping.lastValue) / 127.0,
                color: VaporwaveColors.neonPurple,
                lineWidth: 3,
                size: 30
            )

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(VaporwaveColors.textTertiary)
            }
        }
        .padding(VaporwaveSpacing.md)
        .glassCard()
    }
}

struct QuickPresetCard: View {
    let name: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: VaporwaveSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)

                Text(name)
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(VaporwaveSpacing.md)
            .glassCard()
        }
        .neonGlow(color: color, radius: 6)
    }
}

struct MPEZoneConfig: View {
    let title: String
    let masterChannel: Int
    let memberChannels: Int
    let pitchBendRange: Binding<Int>
    let color: Color
    let onChannelsChanged: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: VaporwaveSpacing.sm) {
            HStack {
                Text(title)
                    .font(VaporwaveTypography.body())
                    .foregroundColor(color)

                Spacer()

                Text("Master: Ch \(masterChannel)")
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.textTertiary)
            }

            HStack {
                Text("Member Channels")
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.textSecondary)

                Spacer()

                Stepper("\(memberChannels)", value: Binding(
                    get: { memberChannels },
                    set: { onChannelsChanged($0) }
                ), in: 0...15)
                .labelsHidden()
            }

            HStack {
                Text("Pitch Bend Range")
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.textSecondary)

                Spacer()

                Picker("", selection: pitchBendRange) {
                    Text("±2").tag(2)
                    Text("±12").tag(12)
                    Text("±24").tag(24)
                    Text("±48").tag(48)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
        }
        .padding(VaporwaveSpacing.md)
        .glassCard()
    }
}

struct PerNoteControllerRow: View {
    let name: String
    let cc: String
    let value: Float
    let color: Color

    var body: some View {
        HStack {
            Text(cc)
                .font(VaporwaveTypography.label())
                .foregroundColor(color)
                .frame(width: 30)

            Text(name)
                .font(VaporwaveTypography.caption())
                .foregroundColor(VaporwaveColors.textSecondary)

            Spacer()

            // Value Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(VaporwaveColors.textTertiary.opacity(0.2))

                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(value))
                }
            }
            .frame(width: 80, height: 8)

            Text(String(format: "%.0f", value * 127))
                .font(VaporwaveTypography.label())
                .foregroundColor(VaporwaveColors.textTertiary)
                .frame(width: 30, alignment: .trailing)
        }
    }
}

struct MIDILearnSheet: View {
    @Binding var isPresented: Bool
    let onMapped: (MIDIMappingItem) -> Void
    @State private var isListening = false
    @State private var detectedCC: Int?
    @State private var detectedChannel: Int?
    @State private var selectedParameter: String = "Filter Cutoff"

    let availableParameters = [
        "Filter Cutoff", "Filter Resonance", "Volume", "Pan",
        "Reverb Send", "Delay Send", "Attack", "Release",
        "LFO Rate", "LFO Depth", "Coherence Threshold", "BPM"
    ]

    var body: some View {
        ZStack {
            VaporwaveGradients.background.ignoresSafeArea()

            VStack(spacing: VaporwaveSpacing.lg) {
                Text("MIDI LEARN")
                    .font(VaporwaveTypography.sectionTitle())
                    .foregroundColor(VaporwaveColors.textPrimary)
                    .neonGlow(color: VaporwaveColors.neonPink, radius: 10)

                // Listening Indicator
                ZStack {
                    Circle()
                        .fill(isListening ? VaporwaveColors.neonPink.opacity(0.3) : VaporwaveColors.textTertiary.opacity(0.1))
                        .frame(width: 120, height: 120)

                    Circle()
                        .stroke(isListening ? VaporwaveColors.neonPink : VaporwaveColors.textTertiary, lineWidth: 2)
                        .frame(width: 120, height: 120)

                    VStack {
                        Image(systemName: isListening ? "waveform" : "pianokeys")
                            .font(.system(size: 32))
                            .foregroundColor(isListening ? VaporwaveColors.neonPink : VaporwaveColors.textSecondary)

                        Text(isListening ? "Listening..." : "Ready")
                            .font(VaporwaveTypography.caption())
                            .foregroundColor(VaporwaveColors.textSecondary)
                    }
                }
                .neonGlow(color: isListening ? VaporwaveColors.neonPink : .clear, radius: 20)

                if let cc = detectedCC, let channel = detectedChannel {
                    Text("Detected: Ch \(channel) CC \(cc)")
                        .font(VaporwaveTypography.body())
                        .foregroundColor(VaporwaveColors.neonCyan)
                }

                // Parameter Picker
                VStack(alignment: .leading, spacing: VaporwaveSpacing.sm) {
                    Text("MAP TO PARAMETER")
                        .font(VaporwaveTypography.label())
                        .foregroundColor(VaporwaveColors.textTertiary)

                    Picker("Parameter", selection: $selectedParameter) {
                        ForEach(availableParameters, id: \.self) { param in
                            Text(param).tag(param)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(VaporwaveSpacing.md)
                    .glassCard()
                }

                Spacer()

                // Action Buttons
                HStack(spacing: VaporwaveSpacing.md) {
                    Button(action: { isPresented = false }) {
                        Text("Cancel")
                            .vaporwaveButton(isActive: false)
                    }

                    Button(action: {
                        if isListening {
                            // Stop listening
                            isListening = false
                        } else {
                            // Start listening
                            isListening = true
                            detectedCC = nil
                            detectedChannel = nil
                        }
                    }) {
                        Text(isListening ? "Stop" : "Start Learning")
                            .vaporwaveButton(isActive: true, activeColor: VaporwaveColors.neonPink)
                    }

                    if detectedCC != nil {
                        Button(action: {
                            if let cc = detectedCC, let channel = detectedChannel {
                                let mapping = MIDIMappingItem(
                                    id: UUID(),
                                    parameterName: selectedParameter,
                                    channel: channel,
                                    cc: cc,
                                    lastValue: 0
                                )
                                onMapped(mapping)
                                isPresented = false
                            }
                        }) {
                            Text("Save")
                                .vaporwaveButton(isActive: true, activeColor: VaporwaveColors.neonCyan)
                        }
                    }
                }
            }
            .padding(VaporwaveSpacing.xl)
        }
    }
}

// MARK: - View Models & Models

@MainActor
class MIDIRouterViewModel: ObservableObject {
    @Published var inputDevices: [MIDIDeviceInfo] = []
    @Published var outputDevices: [MIDIDeviceInfo] = []
    @Published var enabledInputs: Set<UUID> = []
    @Published var enabledOutputs: Set<UUID> = []
    @Published var isReceiving = false
    @Published var isSending = false
    @Published var virtualSourceActive = true
    @Published var mappings: [MIDIMappingItem] = []
    @Published var enabledChannels: Set<Int> = Set(1...16)
    @Published var enabledMessageTypes: Set<MIDIMessageType> = Set(MIDIMessageType.allCases)
    @Published var routes: [(from: UUID, to: UUID)] = []
    @Published var virtualRoutes: Set<UUID> = []

    // MPE
    @Published var mpeEnabled = false
    @Published var lowerZoneChannels = 8
    @Published var upperZoneChannels = 7
    @Published var lowerPitchBend = 48
    @Published var upperPitchBend = 48
    @Published var voiceAllocationMode: VoiceAllocationMode = .roundRobin
    @Published var lastPitchBend: Float = 0.5
    @Published var lastPressure: Float = 0
    @Published var lastSlide: Float = 0.5
    @Published var lastExpression: Float = 0.7

    init() {
        // Simulate some devices
        inputDevices = [
            MIDIDeviceInfo(id: UUID(), name: "Ableton Push 3", manufacturer: "Ableton", supportsMIDI2: true),
            MIDIDeviceInfo(id: UUID(), name: "Arturia KeyLab", manufacturer: "Arturia", supportsMIDI2: false),
            MIDIDeviceInfo(id: UUID(), name: "MIDI Keyboard", manufacturer: "Generic", supportsMIDI2: false)
        ]
        outputDevices = [
            MIDIDeviceInfo(id: UUID(), name: "Ableton Push 3", manufacturer: "Ableton", supportsMIDI2: true),
            MIDIDeviceInfo(id: UUID(), name: "Hardware Synth", manufacturer: "Roland", supportsMIDI2: false)
        ]
        enabledInputs = Set(inputDevices.map { $0.id })
        enabledOutputs = Set(outputDevices.map { $0.id })
    }

    func toggleInput(_ id: UUID) { if enabledInputs.contains(id) { enabledInputs.remove(id) } else { enabledInputs.insert(id) } }
    func toggleOutput(_ id: UUID) { if enabledOutputs.contains(id) { enabledOutputs.remove(id) } else { enabledOutputs.insert(id) } }
    func toggleChannel(_ ch: Int) { if enabledChannels.contains(ch) { enabledChannels.remove(ch) } else { enabledChannels.insert(ch) } }
    func toggleMessageType(_ type: MIDIMessageType) { if enabledMessageTypes.contains(type) { enabledMessageTypes.remove(type) } else { enabledMessageTypes.insert(type) } }
    func isRouted(from: UUID, to: UUID) -> Bool { routes.contains { $0.from == from && $0.to == to } }
    func toggleRoute(from: UUID, to: UUID) { if isRouted(from: from, to: to) { routes.removeAll { $0.from == from && $0.to == to } } else { routes.append((from, to)) } }
    func isRoutedToVirtual(from: UUID) -> Bool { virtualRoutes.contains(from) }
    func toggleVirtualRoute(from: UUID) { if virtualRoutes.contains(from) { virtualRoutes.remove(from) } else { virtualRoutes.insert(from) } }
    func addMapping(_ mapping: MIDIMappingItem) { mappings.append(mapping) }
    func removeMapping(_ id: UUID) { mappings.removeAll { $0.id == id } }
    func loadPreset(_ preset: MIDIPreset) { /* Load preset mappings */ }
    func setLowerZoneChannels(_ count: Int) { lowerZoneChannels = count }
    func setUpperZoneChannels(_ count: Int) { upperZoneChannels = count }
}

struct MIDIDeviceInfo: Identifiable {
    let id: UUID
    let name: String
    let manufacturer: String
    let supportsMIDI2: Bool
}

struct MIDIMappingItem: Identifiable {
    let id: UUID
    let parameterName: String
    let channel: Int
    let cc: Int
    var lastValue: Int
}

enum MIDIMessageType: String, CaseIterable {
    case noteOn = "Note On"
    case noteOff = "Note Off"
    case controlChange = "Control Change"
    case pitchBend = "Pitch Bend"
    case aftertouch = "Aftertouch"
    case programChange = "Program Change"

    var name: String { rawValue }
    var icon: String {
        switch self {
        case .noteOn: return "play.circle"
        case .noteOff: return "stop.circle"
        case .controlChange: return "slider.horizontal.3"
        case .pitchBend: return "arrow.up.arrow.down"
        case .aftertouch: return "hand.tap"
        case .programChange: return "list.number"
        }
    }
}

enum MIDIPreset {
    case abletonPush, novationLaunch, akaiMPK, genericCC
}

enum VoiceAllocationMode: String, CaseIterable {
    case roundRobin = "Round Robin"
    case lru = "LRU"
    case lowPriority = "Low Priority"
    case highPriority = "High Priority"
}

// MARK: - Preview

#Preview {
    MIDIRoutingView()
}
