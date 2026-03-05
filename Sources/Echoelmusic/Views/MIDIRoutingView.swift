import SwiftUI

// MARK: - MIDI Routing View
// Professional MIDI 1.0/2.0/MPE routing matrix inspired by Ableton/Reaper
// EchoelBrand Design System

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
            EchoelBrand.bgDeep.ignoresSafeArea()

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
            VStack(alignment: .leading, spacing: EchoelSpacing.xs) {
                Text("MIDI CONTROL")
                    .font(EchoelBrandFont.sectionTitle())
                    .foregroundColor(EchoelBrand.textPrimary)

                Text("MIDI 1.0 / 2.0 / MPE")
                    .font(EchoelBrandFont.caption())
                    .foregroundColor(EchoelBrand.sky)
            }

            Spacer()

            // MIDI Activity Indicator
            HStack(spacing: EchoelSpacing.sm) {
                Circle()
                    .fill(midiRouter.isReceiving ? EchoelBrand.sky : EchoelBrand.textTertiary)
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut(duration: 0.1), value: midiRouter.isReceiving)

                Text("IN")
                    .font(EchoelBrandFont.label())
                    .foregroundColor(EchoelBrand.textSecondary)

                Circle()
                    .fill(midiRouter.isSending ? EchoelBrand.coral : EchoelBrand.textTertiary)
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut(duration: 0.1), value: midiRouter.isSending)

                Text("OUT")
                    .font(EchoelBrandFont.label())
                    .foregroundColor(EchoelBrand.textSecondary)
            }
            .padding(.horizontal, EchoelSpacing.md)
            .padding(.vertical, EchoelSpacing.sm)
            .glassCard()
        }
        .padding(EchoelSpacing.md)
    }

    // MARK: - Tab Bar

    private var tabBarView: some View {
        HStack(spacing: EchoelSpacing.sm) {
            ForEach(MIDITab.allCases, id: \.self) { tab in
                midiTabButton(tab)
            }
        }
        .padding(.horizontal, EchoelSpacing.md)
        .padding(.bottom, EchoelSpacing.md)
    }

    private func midiTabButton(_ tab: MIDITab) -> some View {
        let isActive = selectedTab == tab
        let fgColor: Color = isActive ? EchoelBrand.bgDeep : EchoelBrand.textSecondary
        let fillColor: Color = isActive ? EchoelBrand.sky : Color.clear
        let strokeColor: Color = isActive ? EchoelBrand.sky : EchoelBrand.textTertiary
        let glowColor: Color = isActive ? EchoelBrand.sky : .clear

        return Button(action: {
            withAnimation(EchoelAnimation.smooth) {
                selectedTab = tab
            }
        }) {
            Text(tab.rawValue)
                .font(EchoelBrandFont.caption())
                .foregroundColor(fgColor)
                .padding(.horizontal, EchoelSpacing.md)
                .padding(.vertical, EchoelSpacing.sm)
                .background(Capsule().fill(fillColor))
                .overlay(Capsule().stroke(strokeColor, lineWidth: 1))
        }
        .neonGlow(color: glowColor, radius: 8)
    }

    // MARK: - Devices View

    private var devicesView: some View {
        VStack(spacing: EchoelSpacing.md) {
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
                .padding(.top, EchoelSpacing.xl)

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
                .padding(.top, EchoelSpacing.xl)

            VStack(spacing: EchoelSpacing.sm) {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundColor(EchoelBrand.violet)

                    Text("Echoelmusic MIDI 2.0 Output")
                        .font(EchoelBrandFont.body())
                        .foregroundColor(EchoelBrand.textPrimary)

                    Spacer()

                    Text("UMP")
                        .font(EchoelBrandFont.label())
                        .foregroundColor(EchoelBrand.sky)
                        .padding(.horizontal, EchoelSpacing.sm)
                        .padding(.vertical, EchoelSpacing.xs)
                        .background(EchoelBrand.sky.opacity(0.2))
                        .cornerRadius(4)

                    VaporwaveStatusIndicator(isActive: midiRouter.virtualSourceActive, activeColor: EchoelBrand.violet)
                }

                Text("32-bit resolution • Per-note controllers • UMP protocol")
                    .font(EchoelBrandFont.caption())
                    .foregroundColor(EchoelBrand.textTertiary)
            }
            .padding(EchoelSpacing.md)
            .glassCard()
        }
        .padding(EchoelSpacing.md)
    }

    private func emptyDeviceState(message: String) -> some View {
        HStack {
            Image(systemName: "cable.connector.horizontal")
                .foregroundColor(EchoelBrand.textTertiary)
            Text(message)
                .font(EchoelBrandFont.caption())
                .foregroundColor(EchoelBrand.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(EchoelSpacing.xl)
        .glassCard()
    }

    // MARK: - Routing Matrix View

    private var routingMatrixView: some View {
        VStack(spacing: EchoelSpacing.md) {
            VaporwaveSectionHeader("ROUTING MATRIX", icon: "arrow.triangle.branch")

            // Matrix Grid
            VStack(spacing: 2) {
                // Header Row
                HStack(spacing: 2) {
                    Text("IN / OUT")
                        .font(EchoelBrandFont.label())
                        .foregroundColor(EchoelBrand.textTertiary)
                        .frame(width: 80)

                    ForEach(midiRouter.outputDevices, id: \.id) { output in
                        Text(String(output.name.prefix(8)))
                            .font(EchoelBrandFont.label())
                            .foregroundColor(EchoelBrand.sky)
                            .frame(width: 60)
                            .lineLimit(1)
                    }

                    Text("Virtual")
                        .font(EchoelBrandFont.label())
                        .foregroundColor(EchoelBrand.violet)
                        .frame(width: 60)
                }
                .padding(.vertical, EchoelSpacing.sm)

                // Matrix Rows
                ForEach(midiRouter.inputDevices, id: \.id) { input in
                    HStack(spacing: 2) {
                        Text(String(input.name.prefix(10)))
                            .font(EchoelBrandFont.label())
                            .foregroundColor(EchoelBrand.textSecondary)
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
                            color: EchoelBrand.violet
                        )
                    }
                }
            }
            .padding(EchoelSpacing.md)
            .glassCard()

            // Channel Filter
            VaporwaveSectionHeader("CHANNEL FILTER", icon: "line.3.horizontal.decrease.circle")
                .padding(.top, EchoelSpacing.xl)

            channelFilterGrid

            // Message Filter
            VaporwaveSectionHeader("MESSAGE FILTER", icon: "slider.horizontal.3")
                .padding(.top, EchoelSpacing.xl)

            messageFilterToggles
        }
        .padding(EchoelSpacing.md)
    }

    private var channelFilterGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 8), spacing: 4) {
            ForEach(1...16, id: \.self) { channel in
                Button(action: { midiRouter.toggleChannel(channel) }) {
                    Text("\(channel)")
                        .font(EchoelBrandFont.label())
                        .foregroundColor(midiRouter.enabledChannels.contains(channel) ? EchoelBrand.bgDeep : EchoelBrand.textTertiary)
                        .frame(width: 36, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(midiRouter.enabledChannels.contains(channel) ? EchoelBrand.sky : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(midiRouter.enabledChannels.contains(channel) ? EchoelBrand.sky : EchoelBrand.textTertiary.opacity(0.3), lineWidth: 1)
                        )
                }
            }
        }
        .padding(EchoelSpacing.md)
        .glassCard()
    }

    private var messageFilterToggles: some View {
        VStack(spacing: EchoelSpacing.sm) {
            ForEach(MIDIMessageType.allCases, id: \.self) { type in
                HStack {
                    Image(systemName: type.icon)
                        .foregroundColor(EchoelBrand.sky)
                        .frame(width: 24)

                    Text(type.name)
                        .font(EchoelBrandFont.body())
                        .foregroundColor(EchoelBrand.textPrimary)

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { midiRouter.enabledMessageTypes.contains(type) },
                        set: { _ in midiRouter.toggleMessageType(type) }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: EchoelBrand.sky))
                }
            }
        }
        .padding(EchoelSpacing.md)
        .glassCard()
    }

    // MARK: - Mappings View

    private var mappingsView: some View {
        VStack(spacing: EchoelSpacing.md) {
            HStack {
                VaporwaveSectionHeader("MIDI MAPPINGS", icon: "arrow.left.arrow.right")

                Spacer()

                Button(action: { showMIDILearn = true }) {
                    HStack(spacing: EchoelSpacing.sm) {
                        Image(systemName: "plus.circle.fill")
                        Text("MIDI Learn")
                    }
                    .font(EchoelBrandFont.caption())
                    .foregroundColor(EchoelBrand.coral)
                    .padding(.horizontal, EchoelSpacing.md)
                    .padding(.vertical, EchoelSpacing.sm)
                    .background(EchoelBrand.coral.opacity(0.2))
                    .cornerRadius(16)
                }
                .neonGlow(color: EchoelBrand.coral, radius: 6)
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
                .padding(.top, EchoelSpacing.xl)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: EchoelSpacing.sm) {
                QuickPresetCard(name: "Ableton Push", icon: "square.grid.3x3", color: EchoelBrand.violet) {
                    midiRouter.loadPreset(.abletonPush)
                }
                QuickPresetCard(name: "Novation Launch", icon: "square.grid.4x3.fill", color: EchoelBrand.sky) {
                    midiRouter.loadPreset(.novationLaunch)
                }
                QuickPresetCard(name: "Akai MPK", icon: "pianokeys.inverse", color: EchoelBrand.coral) {
                    midiRouter.loadPreset(.akaiMPK)
                }
                QuickPresetCard(name: "Generic CC", icon: "slider.horizontal.3", color: EchoelBrand.coral) {
                    midiRouter.loadPreset(.genericCC)
                }
            }
        }
        .padding(EchoelSpacing.md)
    }

    // MARK: - MPE View

    private var mpeView: some View {
        VStack(spacing: EchoelSpacing.md) {
            VaporwaveSectionHeader("MPE CONFIGURATION", icon: "waveform.path.ecg")

            // MPE Status
            HStack {
                VStack(alignment: .leading, spacing: EchoelSpacing.xs) {
                    Text("MIDI Polyphonic Expression")
                        .font(EchoelBrandFont.body())
                        .foregroundColor(EchoelBrand.textPrimary)

                    Text("Per-note pitch bend, slide, pressure")
                        .font(EchoelBrandFont.caption())
                        .foregroundColor(EchoelBrand.textTertiary)
                }

                Spacer()

                Toggle("", isOn: $midiRouter.mpeEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: EchoelBrand.violet))
            }
            .padding(EchoelSpacing.md)
            .glassCard()

            if midiRouter.mpeEnabled {
                // Zone Configuration
                VaporwaveSectionHeader("ZONE CONFIGURATION", icon: "rectangle.split.3x1")
                    .padding(.top, EchoelSpacing.md)

                VStack(spacing: EchoelSpacing.md) {
                    // Lower Zone
                    MPEZoneConfig(
                        title: "Lower Zone",
                        masterChannel: 1,
                        memberChannels: midiRouter.lowerZoneChannels,
                        pitchBendRange: $midiRouter.lowerPitchBend,
                        color: EchoelBrand.sky,
                        onChannelsChanged: { midiRouter.setLowerZoneChannels($0) }
                    )

                    // Upper Zone
                    MPEZoneConfig(
                        title: "Upper Zone",
                        masterChannel: 16,
                        memberChannels: midiRouter.upperZoneChannels,
                        pitchBendRange: $midiRouter.upperPitchBend,
                        color: EchoelBrand.coral,
                        onChannelsChanged: { midiRouter.setUpperZoneChannels($0) }
                    )
                }

                // Per-Note Controllers
                VaporwaveSectionHeader("PER-NOTE CONTROLLERS", icon: "dial.high")
                    .padding(.top, EchoelSpacing.md)

                VStack(spacing: EchoelSpacing.sm) {
                    PerNoteControllerRow(name: "Pitch Bend", cc: "PB", value: midiRouter.lastPitchBend, color: EchoelBrand.sky)
                    PerNoteControllerRow(name: "Pressure", cc: "AT", value: midiRouter.lastPressure, color: EchoelBrand.coral)
                    PerNoteControllerRow(name: "Slide (CC74)", cc: "74", value: midiRouter.lastSlide, color: EchoelBrand.violet)
                    PerNoteControllerRow(name: "Expression", cc: "11", value: midiRouter.lastExpression, color: EchoelBrand.coral)
                }
                .padding(EchoelSpacing.md)
                .glassCard()

                // Voice Allocation
                VaporwaveSectionHeader("VOICE ALLOCATION", icon: "person.3")
                    .padding(.top, EchoelSpacing.md)

                Picker("Mode", selection: $midiRouter.voiceAllocationMode) {
                    Text("Round Robin").tag(VoiceAllocationMode.roundRobin)
                    Text("LRU").tag(VoiceAllocationMode.lru)
                    Text("Low Priority").tag(VoiceAllocationMode.lowPriority)
                    Text("High Priority").tag(VoiceAllocationMode.highPriority)
                }
                .pickerStyle(.segmented)
                .padding(EchoelSpacing.md)
                .glassCard()
            }
        }
        .padding(EchoelSpacing.md)
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
                .foregroundColor(isInput ? EchoelBrand.sky : EchoelBrand.coral)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(EchoelBrandFont.body())
                    .foregroundColor(EchoelBrand.textPrimary)

                Text(device.manufacturer)
                    .font(EchoelBrandFont.caption())
                    .foregroundColor(EchoelBrand.textTertiary)
            }

            Spacer()

            if device.supportsMIDI2 {
                Text("2.0")
                    .font(EchoelBrandFont.label())
                    .foregroundColor(EchoelBrand.violet)
                    .padding(.horizontal, EchoelSpacing.sm)
                    .padding(.vertical, 2)
                    .background(EchoelBrand.violet.opacity(0.2))
                    .cornerRadius(4)
            }

            Toggle("", isOn: Binding(get: { isEnabled }, set: { _ in onToggle() }))
                .toggleStyle(SwitchToggleStyle(tint: isInput ? EchoelBrand.sky : EchoelBrand.coral))
        }
        .padding(EchoelSpacing.md)
        .glassCard()
    }
}

struct RoutingMatrixCell: View {
    let isRouted: Bool
    let onToggle: () -> Void
    var color: Color = EchoelBrand.sky

    var body: some View {
        Button(action: onToggle) {
            RoundedRectangle(cornerRadius: 4)
                .fill(isRouted ? color : Color.clear)
                .frame(width: 60, height: 30)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isRouted ? color : EchoelBrand.textTertiary.opacity(0.3), lineWidth: 1)
                )
                .overlay(
                    Image(systemName: isRouted ? "arrow.right" : "")
                        .font(.system(size: 12))
                        .foregroundColor(EchoelBrand.bgDeep)
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
                    .font(EchoelBrandFont.body())
                    .foregroundColor(EchoelBrand.textPrimary)

                Text("Ch \(mapping.channel) • CC \(mapping.cc)")
                    .font(EchoelBrandFont.caption())
                    .foregroundColor(EchoelBrand.sky)
            }

            Spacer()

            // Value Indicator
            VaporwaveProgressRing(
                progress: Double(mapping.lastValue) / 127.0,
                color: EchoelBrand.violet,
                lineWidth: 3,
                size: 30
            )

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(EchoelBrand.textTertiary)
            }
        }
        .padding(EchoelSpacing.md)
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
            VStack(spacing: EchoelSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)

                Text(name)
                    .font(EchoelBrandFont.caption())
                    .foregroundColor(EchoelBrand.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(EchoelSpacing.md)
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
        VStack(alignment: .leading, spacing: EchoelSpacing.sm) {
            HStack {
                Text(title)
                    .font(EchoelBrandFont.body())
                    .foregroundColor(color)

                Spacer()

                Text("Master: Ch \(masterChannel)")
                    .font(EchoelBrandFont.caption())
                    .foregroundColor(EchoelBrand.textTertiary)
            }

            HStack {
                Text("Member Channels")
                    .font(EchoelBrandFont.caption())
                    .foregroundColor(EchoelBrand.textSecondary)

                Spacer()

                Stepper("\(memberChannels)", value: Binding(
                    get: { memberChannels },
                    set: { onChannelsChanged($0) }
                ), in: 0...15)
                .labelsHidden()
            }

            HStack {
                Text("Pitch Bend Range")
                    .font(EchoelBrandFont.caption())
                    .foregroundColor(EchoelBrand.textSecondary)

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
        .padding(EchoelSpacing.md)
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
                .font(EchoelBrandFont.label())
                .foregroundColor(color)
                .frame(width: 30)

            Text(name)
                .font(EchoelBrandFont.caption())
                .foregroundColor(EchoelBrand.textSecondary)

            Spacer()

            // Value Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(EchoelBrand.textTertiary.opacity(0.2))

                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(value))
                }
            }
            .frame(width: 80, height: 8)

            Text(String(format: "%.0f", value * 127))
                .font(EchoelBrandFont.label())
                .foregroundColor(EchoelBrand.textTertiary)
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
            EchoelBrand.bgDeep.ignoresSafeArea()

            VStack(spacing: EchoelSpacing.xl) {
                Text("MIDI LEARN")
                    .font(EchoelBrandFont.sectionTitle())
                    .foregroundColor(EchoelBrand.textPrimary)
                    .neonGlow(color: EchoelBrand.coral, radius: 10)

                // Listening Indicator
                ZStack {
                    Circle()
                        .fill(isListening ? EchoelBrand.coral.opacity(0.3) : EchoelBrand.textTertiary.opacity(0.1))
                        .frame(width: 120, height: 120)

                    Circle()
                        .stroke(isListening ? EchoelBrand.coral : EchoelBrand.textTertiary, lineWidth: 2)
                        .frame(width: 120, height: 120)

                    VStack {
                        Image(systemName: isListening ? "waveform" : "pianokeys")
                            .font(.system(size: 32))
                            .foregroundColor(isListening ? EchoelBrand.coral : EchoelBrand.textSecondary)

                        Text(isListening ? "Listening..." : "Ready")
                            .font(EchoelBrandFont.caption())
                            .foregroundColor(EchoelBrand.textSecondary)
                    }
                }
                .neonGlow(color: isListening ? EchoelBrand.coral : .clear, radius: 20)

                if let cc = detectedCC, let channel = detectedChannel {
                    Text("Detected: Ch \(channel) CC \(cc)")
                        .font(EchoelBrandFont.body())
                        .foregroundColor(EchoelBrand.sky)
                }

                // Parameter Picker
                VStack(alignment: .leading, spacing: EchoelSpacing.sm) {
                    Text("MAP TO PARAMETER")
                        .font(EchoelBrandFont.label())
                        .foregroundColor(EchoelBrand.textTertiary)

                    Picker("Parameter", selection: $selectedParameter) {
                        ForEach(availableParameters, id: \.self) { param in
                            Text(param).tag(param)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(EchoelSpacing.md)
                    .glassCard()
                }

                Spacer()

                // Action Buttons
                HStack(spacing: EchoelSpacing.md) {
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
                            .vaporwaveButton(isActive: true, activeColor: EchoelBrand.coral)
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
                                .vaporwaveButton(isActive: true, activeColor: EchoelBrand.sky)
                        }
                    }
                }
            }
            .padding(EchoelSpacing.xl)
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

#if DEBUG
#Preview {
    MIDIRoutingView()
}
#endif
