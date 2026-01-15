import SwiftUI

/// SwiftUI Hardware Picker View - Phase 10000 ULTIMATE
/// Select and configure audio interfaces, MIDI controllers, lighting, and more
/// Supports ALL cross-platform device combinations
struct HardwarePickerView: View {

    @StateObject private var viewModel = HardwarePickerViewModel()
    @State private var selectedCategory: HardwareCategory = .audioInterfaces
    @State private var showingSessionSetup = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category Picker
                categoryPicker

                // Content based on category
                ScrollView {
                    switch selectedCategory {
                    case .audioInterfaces:
                        audioInterfacesList
                    case .midiControllers:
                        midiControllersList
                    case .lighting:
                        lightingList
                    case .video:
                        videoList
                    case .broadcast:
                        broadcastList
                    case .vrAr:
                        vrArList
                    case .wearables:
                        wearablesList
                    case .crossPlatform:
                        crossPlatformView
                    }
                }
            }
            .navigationTitle("Hardware Ecosystem")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingSessionSetup = true
                    } label: {
                        Label("New Session", systemImage: "plus.circle.fill")
                    }
                    .accessibilityLabel("Create new hardware session")
                    .accessibilityHint("Opens session setup wizard")
                }
            }
            .sheet(isPresented: $showingSessionSetup) {
                SessionSetupView()
            }
        }
    }

    // MARK: - Category Picker

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(HardwareCategory.allCases, id: \.self) { category in
                    CategoryButton(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Audio Interfaces List

    private var audioInterfacesList: some View {
        LazyVStack(spacing: 12) {
            ForEach(AudioInterfaceRegistry.AudioInterfaceBrand.allCases, id: \.self) { brand in
                let interfaces = viewModel.audioInterfaces.filter { $0.brand == brand }
                if !interfaces.isEmpty {
                    Section {
                        ForEach(interfaces, id: \.id) { interface in
                            AudioInterfaceCard(interface: interface)
                        }
                    } header: {
                        SectionHeader(title: brand.rawValue, count: interfaces.count)
                    }
                }
            }
        }
        .padding()
    }

    // MARK: - MIDI Controllers List

    private var midiControllersList: some View {
        LazyVStack(spacing: 12) {
            ForEach(MIDIControllerRegistry.MIDIControllerBrand.allCases, id: \.self) { brand in
                let controllers = viewModel.midiControllers.filter { $0.brand == brand }
                if !controllers.isEmpty {
                    Section {
                        ForEach(controllers, id: \.id) { controller in
                            MIDIControllerCard(controller: controller)
                        }
                    } header: {
                        SectionHeader(title: brand.rawValue, count: controllers.count)
                    }
                }
            }
        }
        .padding()
    }

    // MARK: - Lighting List

    private var lightingList: some View {
        LazyVStack(spacing: 12) {
            Section {
                ForEach(viewModel.dmxControllers, id: \.id) { controller in
                    DMXControllerCard(controller: controller)
                }
            } header: {
                SectionHeader(title: "DMX Controllers", count: viewModel.dmxControllers.count)
            }

            Section {
                ForEach(viewModel.smartLights, id: \.name) { light in
                    SmartLightCard(name: light.name, protocol: light.protocol)
                }
            } header: {
                SectionHeader(title: "Smart Lighting", count: viewModel.smartLights.count)
            }
        }
        .padding()
    }

    // MARK: - Video List

    private var videoList: some View {
        LazyVStack(spacing: 12) {
            Section {
                ForEach(viewModel.cameras, id: \.id) { camera in
                    CameraCard(camera: camera)
                }
            } header: {
                SectionHeader(title: "Cameras", count: viewModel.cameras.count)
            }

            Section {
                ForEach(viewModel.captureCards, id: \.id) { card in
                    CaptureCardView(card: card)
                }
            } header: {
                SectionHeader(title: "Capture Cards", count: viewModel.captureCards.count)
            }
        }
        .padding()
    }

    // MARK: - Broadcast List

    private var broadcastList: some View {
        LazyVStack(spacing: 12) {
            Section {
                ForEach(viewModel.videoSwitchers, id: \.id) { switcher in
                    VideoSwitcherCard(switcher: switcher)
                }
            } header: {
                SectionHeader(title: "Video Switchers", count: viewModel.videoSwitchers.count)
            }

            Section {
                ForEach(viewModel.streamingPlatforms, id: \.name) { platform in
                    StreamingPlatformCard(platform: platform)
                }
            } header: {
                SectionHeader(title: "Streaming Platforms", count: viewModel.streamingPlatforms.count)
            }
        }
        .padding()
    }

    // MARK: - VR/AR List

    private var vrArList: some View {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.vrArDevices, id: \.id) { device in
                VRARDeviceCard(device: device)
            }
        }
        .padding()
    }

    // MARK: - Wearables List

    private var wearablesList: some View {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.wearables, id: \.id) { device in
                WearableCard(device: device)
            }
        }
        .padding()
    }

    // MARK: - Cross-Platform View

    private var crossPlatformView: some View {
        LazyVStack(spacing: 16) {
            // Predefined combinations
            Section {
                ForEach(DeviceCombinationPresets.crossEcosystemCombinations.prefix(10), id: \.name) { combo in
                    DeviceCombinationCard(combination: combo)
                }
            } header: {
                SectionHeader(title: "Cross-Platform Combinations", count: DeviceCombinationPresets.crossEcosystemCombinations.count)
            }

            // Custom combination builder
            Section {
                CustomCombinationBuilder()
            } header: {
                Text("Build Custom Combination")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
    }
}

// MARK: - Hardware Category

enum HardwareCategory: String, CaseIterable {
    case audioInterfaces = "Audio"
    case midiControllers = "MIDI"
    case lighting = "Lighting"
    case video = "Video"
    case broadcast = "Broadcast"
    case vrAr = "VR/AR"
    case wearables = "Wearables"
    case crossPlatform = "Cross-Platform"

    var icon: String {
        switch self {
        case .audioInterfaces: return "waveform"
        case .midiControllers: return "pianokeys"
        case .lighting: return "lightbulb.fill"
        case .video: return "video.fill"
        case .broadcast: return "antenna.radiowaves.left.and.right"
        case .vrAr: return "visionpro"
        case .wearables: return "applewatch"
        case .crossPlatform: return "link.circle.fill"
        }
    }
}

// MARK: - Category Button

struct CategoryButton: View {
    let category: HardwareCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: category.icon)
                    .font(.title2)
                Text(category.rawValue)
                    .font(.caption)
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? Color.accentColor : Color(.systemGray6))
            .cornerRadius(12)
        }
        .accessibilityLabel("\(category.rawValue) category")
        .accessibilityHint("Double tap to view \(category.rawValue.lowercased())")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            Text("\(count)")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color(.systemGray5))
                .cornerRadius(8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(count) items")
        .padding(.top, 8)
    }
}

// MARK: - Card Views

struct AudioInterfaceCard: View {
    let interface: AudioInterfaceRegistry.AudioInterface

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(interface.model)
                    .font(.headline)
                Text("\(interface.inputs) in / \(interface.outputs) out")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack(spacing: 4) {
                    ForEach(interface.connectionTypes.prefix(3), id: \.self) { conn in
                        Text(conn.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.2))
                            .cornerRadius(4)
                    }
                    if interface.hasDSP {
                        Text("DSP")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }
            Spacer()
            Image(systemName: "checkmark.circle")
                .foregroundColor(.green)
                .opacity(0.5)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct MIDIControllerCard: View {
    let controller: MIDIControllerRegistry.MIDIController

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(controller.model)
                    .font(.headline)
                HStack(spacing: 8) {
                    if controller.pads > 0 {
                        Label("\(controller.pads) pads", systemImage: "square.grid.3x3.fill")
                    }
                    if controller.keys > 0 {
                        Label("\(controller.keys) keys", systemImage: "pianokeys")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
                HStack(spacing: 4) {
                    if controller.hasMPE {
                        Text("MPE")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.2))
                            .cornerRadius(4)
                    }
                    if controller.hasDisplay {
                        Text("Display")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    }
                    if controller.isStandalone {
                        Text("Standalone")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct DMXControllerCard: View {
    let controller: LightingHardwareRegistry.DMXController

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(controller.name)
                    .font(.headline)
                Text("\(controller.brand) - \(controller.universes) universes")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack(spacing: 4) {
                    ForEach(controller.protocols.prefix(3), id: \.self) { proto in
                        Text(proto.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.yellow.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct SmartLightCard: View {
    let name: String
    let `protocol`: LightingHardwareRegistry.LightingProtocol

    var body: some View {
        HStack {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(.yellow)
            VStack(alignment: .leading) {
                Text(name)
                    .font(.headline)
                Text(`protocol`.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct CameraCard: View {
    let camera: VideoHardwareRegistry.Camera

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(camera.model)
                    .font(.headline)
                Text("\(camera.brand.rawValue) - \(camera.maxResolution.rawValue)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack(spacing: 4) {
                    if camera.hasNDI {
                        Text("NDI")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(4)
                    }
                    if camera.isPTZ {
                        Text("PTZ")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct CaptureCardView: View {
    let card: VideoHardwareRegistry.CaptureCard

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(card.model)
                    .font(.headline)
                Text("\(card.brand) - \(card.inputs) inputs - \(card.maxResolution.rawValue)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct VideoSwitcherCard: View {
    let switcher: BroadcastEquipmentRegistry.VideoSwitcher

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(switcher.model)
                    .font(.headline)
                Text("\(switcher.inputs) inputs / \(switcher.outputs) outputs")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack(spacing: 4) {
                    if switcher.hasNDI {
                        Text("NDI")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(4)
                    }
                    if switcher.hasStreaming {
                        Text("Streaming")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct StreamingPlatformCard: View {
    let platform: (name: String, rtmpUrl: String, maxBitrate: Int)

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(platform.name)
                    .font(.headline)
                Text("Max: \(platform.maxBitrate / 1000) Mbps")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "play.circle.fill")
                .foregroundColor(.red)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct VRARDeviceCard: View {
    let device: VRARDeviceRegistry.XRDevice

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(device.model)
                    .font(.headline)
                Text("\(device.brand) - \(device.platform.rawValue)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack(spacing: 4) {
                    if device.hasSpatialAudio {
                        Image(systemName: "ear.fill")
                    }
                    if device.hasEyeTracking {
                        Image(systemName: "eye.fill")
                    }
                    if device.hasHandTracking {
                        Image(systemName: "hand.raised.fill")
                    }
                    if device.hasPassthrough {
                        Image(systemName: "camera.fill")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct WearableCard: View {
    let device: WearableDeviceRegistry.WearableDevice

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(device.model)
                    .font(.headline)
                Text(device.brand)
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack(spacing: 4) {
                    if device.capabilities.contains(.heartRate) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                    }
                    if device.capabilities.contains(.hrv) {
                        Text("HRV")
                            .font(.caption2)
                    }
                    if device.capabilities.contains(.spatialAudio) {
                        Image(systemName: "ear.fill")
                    }
                }
                .font(.caption)
            }
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct DeviceCombinationCard: View {
    let combination: DeviceCombinationPresets.DeviceCombination

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(combination.name)
                .font(.headline)

            HStack(spacing: 8) {
                ForEach(0..<min(combination.devices.count, 4), id: \.self) { index in
                    let device = combination.devices[index]
                    DeviceChip(type: device.type, role: device.role)
                }
            }

            Text(combination.notes)
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                Text("Sync: \(combination.syncMode.rawValue)")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.2))
                    .cornerRadius(6)
                Spacer()
                Button("Use") {
                    // Start session with this combination
                }
                .font(.caption)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct DeviceChip: View {
    let type: DeviceType
    let role: DeviceRole

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: iconFor(type))
                .font(.title3)
            Text(role.rawValue)
                .font(.caption2)
        }
        .padding(8)
        .background(colorFor(type).opacity(0.2))
        .cornerRadius(8)
    }

    private func iconFor(_ type: DeviceType) -> String {
        switch type {
        case .iPhone: return "iphone"
        case .iPad: return "ipad"
        case .mac: return "desktopcomputer"
        case .appleWatch: return "applewatch"
        case .visionPro: return "visionpro"
        case .androidPhone, .androidTablet: return "smartphone"
        case .wearOS: return "watchface.applewatch.case"
        case .windowsPC, .linuxPC: return "pc"
        case .metaQuest: return "visionpro.fill"
        case .metaGlasses: return "eyeglasses"
        case .tesla: return "car.fill"
        case .audioInterface: return "waveform"
        case .midiController: return "pianokeys"
        default: return "circle.fill"
        }
    }

    private func colorFor(_ type: DeviceType) -> Color {
        switch type {
        case .iPhone, .iPad, .mac, .appleWatch, .visionPro, .appleTv: return .blue
        case .androidPhone, .androidTablet, .wearOS: return .green
        case .windowsPC: return .cyan
        case .linuxPC: return .orange
        case .metaQuest, .metaGlasses: return .purple
        case .tesla: return .red
        default: return .gray
        }
    }
}

struct CustomCombinationBuilder: View {
    @State private var selectedDevices: [DeviceType] = []

    var body: some View {
        VStack(spacing: 12) {
            Text("Drag devices to build your custom combination")
                .font(.caption)
                .foregroundColor(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                ForEach([DeviceType.iPhone, .iPad, .mac, .appleWatch, .visionPro,
                         .androidPhone, .androidTablet, .wearOS,
                         .windowsPC, .linuxPC, .metaQuest, .metaGlasses, .tesla], id: \.self) { type in
                    Button {
                        if selectedDevices.contains(type) {
                            selectedDevices.removeAll { $0 == type }
                        } else {
                            selectedDevices.append(type)
                        }
                    } label: {
                        VStack {
                            Image(systemName: iconFor(type))
                            Text(type.rawValue)
                                .font(.caption2)
                        }
                        .padding(8)
                        .frame(minWidth: 80)
                        .background(selectedDevices.contains(type) ? Color.accentColor : Color(.systemGray5))
                        .foregroundColor(selectedDevices.contains(type) ? .white : .primary)
                        .cornerRadius(8)
                    }
                }
            }

            if !selectedDevices.isEmpty {
                Button("Create Session with \(selectedDevices.count) devices") {
                    // Create custom session
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func iconFor(_ type: DeviceType) -> String {
        switch type {
        case .iPhone: return "iphone"
        case .iPad: return "ipad"
        case .mac: return "desktopcomputer"
        case .appleWatch: return "applewatch"
        case .visionPro: return "visionpro"
        case .androidPhone, .androidTablet: return "smartphone"
        case .wearOS: return "watchface.applewatch.case"
        case .windowsPC, .linuxPC: return "pc"
        case .metaQuest: return "visionpro.fill"
        case .metaGlasses: return "eyeglasses"
        case .tesla: return "car.fill"
        default: return "circle.fill"
        }
    }
}

// MARK: - Session Setup View

struct SessionSetupView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                Text("Create Cross-Platform Session")
                    .font(.title2)

                Text("Select devices from your network")
                    .foregroundColor(.secondary)

                Spacer()

                Button("Start Session") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("New Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - View Model

@MainActor
final class HardwarePickerViewModel: ObservableObject {
    let audioInterfaces: [AudioInterfaceRegistry.AudioInterface]
    let midiControllers: [MIDIControllerRegistry.MIDIController]
    let dmxControllers: [LightingHardwareRegistry.DMXController]
    let smartLights: [(name: String, protocol: LightingHardwareRegistry.LightingProtocol)]
    let cameras: [VideoHardwareRegistry.Camera]
    let captureCards: [VideoHardwareRegistry.CaptureCard]
    let videoSwitchers: [BroadcastEquipmentRegistry.VideoSwitcher]
    let streamingPlatforms: [(name: String, rtmpUrl: String, maxBitrate: Int)]
    let vrArDevices: [VRARDeviceRegistry.XRDevice]
    let wearables: [WearableDeviceRegistry.WearableDevice]

    init() {
        let ecosystem = HardwareEcosystem.shared
        audioInterfaces = ecosystem.audioInterfaces.interfaces
        midiControllers = ecosystem.midiControllers.controllers
        dmxControllers = ecosystem.lightingHardware.controllers
        smartLights = ecosystem.lightingHardware.smartLightingSystems
        cameras = ecosystem.videoHardware.cameras
        captureCards = ecosystem.videoHardware.captureCards
        videoSwitchers = ecosystem.broadcastEquipment.switchers
        streamingPlatforms = ecosystem.broadcastEquipment.streamingPlatforms
        vrArDevices = ecosystem.vrArDevices.devices
        wearables = ecosystem.wearableDevices.devices
    }
}

#Preview {
    HardwarePickerView()
}
