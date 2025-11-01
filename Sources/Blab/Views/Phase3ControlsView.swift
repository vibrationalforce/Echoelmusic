import SwiftUI

/// Phase 3 Controls: Spatial Audio + Visual Mapping + LED Control
/// Complete UI for all Phase 3 features
struct Phase3ControlsView: View {
    @ObservedObject var spatialEngine: SpatialAudioEngine
    @ObservedObject var visualMapper: MIDIToVisualMapper
    @ObservedObject var push3Controller: Push3LEDController
    @ObservedObject var lightMapper: MIDIToLightMapper

    @State private var selectedTab: Tab = .spatial

    enum Tab: String, CaseIterable {
        case spatial = "Spatial"
        case visual = "Visual"
        case led = "LED"
        case dmx = "DMX"

        var icon: String {
            switch self {
            case .spatial: return "waveform.circle"
            case .visual: return "eye.circle"
            case .led: return "grid.circle"
            case .dmx: return "light.beacon.max"
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Picker
                Picker("Phase 3 Controls", selection: $selectedTab) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        Label(tab.rawValue, systemImage: tab.icon)
                            .tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Tab Content
                ScrollView {
                    switch selectedTab {
                    case .spatial:
                        SpatialAudioControlsSection(engine: spatialEngine)
                    case .visual:
                        VisualMappingControlsSection(mapper: visualMapper)
                    case .led:
                        Push3LEDControlsSection(controller: push3Controller)
                    case .dmx:
                        DMXLightControlsSection(mapper: lightMapper)
                    }
                }
            }
            .navigationTitle("Phase 3 Controls")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Spatial Audio Controls

struct SpatialAudioControlsSection: View {
    @ObservedObject var engine: SpatialAudioEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            SectionHeader(
                title: "Spatial Audio Engine",
                icon: "waveform.circle.fill",
                isActive: engine.isActive
            )

            // Enable/Disable
            Toggle("Enable Spatial Audio", isOn: $engine.isActive)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)

            if engine.isActive {
                // Mode Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Spatial Mode")
                        .font(.headline)

                    ForEach(SpatialAudioEngine.SpatialMode.allCases, id: \.self) { mode in
                        SpatialModeButton(
                            mode: mode,
                            isSelected: engine.currentMode == mode
                        ) {
                            engine.currentMode = mode
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)

                // Head Tracking
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Head Tracking (CMMotionManager)", isOn: $engine.headTrackingEnabled)

                    if engine.headTrackingEnabled {
                        Text("Using device motion sensors for 3D audio positioning")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)

                // Spatial Sources Display
                if !engine.spatialSources.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Active Sources: \(engine.spatialSources.count)")
                            .font(.headline)

                        ForEach(engine.spatialSources, id: \.id) { source in
                            SpatialSourceRow(source: source)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
            }
        }
        .padding()
    }
}

struct SpatialModeButton: View {
    let mode: SpatialAudioEngine.SpatialMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.rawValue)
                        .font(.subheadline)
                        .bold()
                    Text(mode.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.2) : Color(.tertiarySystemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct SpatialSourceRow: View {
    let source: SpatialSource

    var body: some View {
        HStack {
            Image(systemName: "speaker.wave.2.circle.fill")
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text("Source \(source.id.uuidString.prefix(8))")
                    .font(.caption)
                    .bold()
                Text("Position: (\(String(format: "%.2f", source.position.x)), \(String(format: "%.2f", source.position.y)), \(String(format: "%.2f", source.position.z)))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(String(format: "%.0f dB", source.gain))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Visual Mapping Controls

struct VisualMappingControlsSection: View {
    @ObservedObject var mapper: MIDIToVisualMapper

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            SectionHeader(
                title: "Visual Mapping",
                icon: "eye.circle.fill",
                isActive: true // Always active when MIDI is present
            )

            // Cymatics Parameters
            VStack(alignment: .leading, spacing: 12) {
                Text("Cymatics (Chladni Patterns)")
                    .font(.headline)

                ParameterSlider(
                    label: "Frequency",
                    value: $mapper.cymaticsParameters.frequency,
                    range: 20...2000,
                    unit: "Hz"
                )

                ParameterSlider(
                    label: "Amplitude",
                    value: $mapper.cymaticsParameters.amplitude,
                    range: 0...1,
                    unit: ""
                )

                ParameterSlider(
                    label: "Hue (HRV-driven)",
                    value: $mapper.cymaticsParameters.hue,
                    range: 0...1,
                    unit: ""
                )
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)

            // Mandala Parameters
            VStack(alignment: .leading, spacing: 12) {
                Text("Mandala")
                    .font(.headline)

                Stepper("Petal Count: \(mapper.mandalaParameters.petalCount)", value: $mapper.mandalaParameters.petalCount, in: 6...12)

                ParameterSlider(
                    label: "Petal Size",
                    value: $mapper.mandalaParameters.petalSize,
                    range: 0...1,
                    unit: ""
                )

                ParameterSlider(
                    label: "Rotation Speed",
                    value: $mapper.mandalaParameters.rotationSpeed,
                    range: 0...2,
                    unit: "rad/s"
                )

                ParameterSlider(
                    label: "Hue",
                    value: $mapper.mandalaParameters.hue,
                    range: 0...1,
                    unit: ""
                )
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)

            // Waveform Parameters
            VStack(alignment: .leading, spacing: 12) {
                Text("Waveform")
                    .font(.headline)

                ParameterSlider(
                    label: "Thickness",
                    value: $mapper.waveformParameters.thickness,
                    range: 1...10,
                    unit: "px"
                )

                ParameterSlider(
                    label: "Smoothness",
                    value: $mapper.waveformParameters.smoothness,
                    range: 0...1,
                    unit: ""
                )
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)

            // Spectral Parameters
            VStack(alignment: .leading, spacing: 12) {
                Text("Spectral (FFT)")
                    .font(.headline)

                ParameterSlider(
                    label: "Bar Width",
                    value: $mapper.spectralParameters.barWidth,
                    range: 1...20,
                    unit: "px"
                )

                ParameterSlider(
                    label: "Sensitivity",
                    value: $mapper.spectralParameters.sensitivity,
                    range: 0...2,
                    unit: ""
                )
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)

            // Particle Parameters
            VStack(alignment: .leading, spacing: 12) {
                Text("Particles")
                    .font(.headline)

                Stepper("Particle Count: \(mapper.particleParameters.particleCount)", value: $mapper.particleParameters.particleCount, in: 50...500, step: 50)

                ParameterSlider(
                    label: "Particle Size",
                    value: $mapper.particleParameters.particleSize,
                    range: 1...10,
                    unit: "px"
                )

                ParameterSlider(
                    label: "Speed",
                    value: $mapper.particleParameters.speed,
                    range: 0...2,
                    unit: ""
                )

                ParameterSlider(
                    label: "Gravity",
                    value: $mapper.particleParameters.gravity,
                    range: -1...1,
                    unit: ""
                )
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .padding()
    }
}

// MARK: - Push 3 LED Controls

struct Push3LEDControlsSection: View {
    @ObservedObject var controller: Push3LEDController

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            SectionHeader(
                title: "Ableton Push 3 LED",
                icon: "grid.circle.fill",
                isActive: controller.isConnected
            )

            // Connection Status
            HStack {
                Image(systemName: controller.isConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(controller.isConnected ? .green : .red)

                Text(controller.isConnected ? "Push 3 Connected" : "Push 3 Not Connected")
                    .font(.subheadline)

                Spacer()

                if !controller.isConnected {
                    Button("Scan") {
                        // Trigger rescan
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)

            if controller.isConnected {
                // Pattern Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("LED Pattern")
                        .font(.headline)

                    ForEach(Push3LEDController.LEDPattern.allCases, id: \.self) { pattern in
                        LEDPatternButton(
                            pattern: pattern,
                            isSelected: controller.currentPattern == pattern
                        ) {
                            controller.currentPattern = pattern
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)

                // Brightness Control
                VStack(alignment: .leading, spacing: 8) {
                    Text("Brightness: \(Int(controller.brightness * 100))%")
                        .font(.headline)

                    Slider(value: $controller.brightness, in: 0...1)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)

                // LED Grid Preview
                VStack(alignment: .leading, spacing: 8) {
                    Text("8x8 LED Grid")
                        .font(.headline)

                    Text("Bio-reactive feedback based on HRV, heart rate, and gestures")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Simple grid visualization
                    LEDGridPreview()
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
        }
        .padding()
    }
}

struct LEDPatternButton: View {
    let pattern: Push3LEDController.LEDPattern
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(pattern.rawValue)
                        .font(.subheadline)
                        .bold()
                    Text(pattern.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .padding()
            .background(isSelected ? Color.green.opacity(0.2) : Color(.tertiarySystemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct LEDGridPreview: View {
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height) / 8
            VStack(spacing: 2) {
                ForEach(0..<8, id: \.self) { row in
                    HStack(spacing: 2) {
                        ForEach(0..<8, id: \.self) { col in
                            Rectangle()
                                .fill(Color.blue.opacity(0.3))
                                .frame(width: size, height: size)
                                .cornerRadius(2)
                        }
                    }
                }
            }
        }
        .aspectRatio(1.0, contentMode: .fit)
    }
}

// MARK: - DMX Light Controls

struct DMXLightControlsSection: View {
    @ObservedObject var mapper: MIDIToLightMapper

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            SectionHeader(
                title: "DMX/Art-Net Lighting",
                icon: "light.beacon.max.fill",
                isActive: mapper.isConnected
            )

            // Connection Status
            HStack {
                Image(systemName: mapper.isConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(mapper.isConnected ? .green : .red)

                VStack(alignment: .leading, spacing: 2) {
                    Text(mapper.isConnected ? "Art-Net Connected" : "Art-Net Disconnected")
                        .font(.subheadline)
                    if mapper.isConnected {
                        Text("Universe: 512 channels")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if !mapper.isConnected {
                    Button("Connect") {
                        // Trigger connection
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)

            if mapper.isConnected {
                // Light Scene Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Light Scene")
                        .font(.headline)

                    ForEach(MIDIToLightMapper.LightScene.allCases, id: \.self) { scene in
                        LightSceneButton(
                            scene: scene,
                            isSelected: mapper.currentScene == scene
                        ) {
                            mapper.currentScene = scene
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)

                // Master Intensity
                VStack(alignment: .leading, spacing: 8) {
                    Text("Master Intensity: \(Int(mapper.masterIntensity * 100))%")
                        .font(.headline)

                    Slider(value: $mapper.masterIntensity, in: 0...1)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)

                // Bio-Reactive Controls
                VStack(alignment: .leading, spacing: 12) {
                    Text("Bio-Reactive Controls")
                        .font(.headline)

                    Toggle("HRV → Hue Mapping", isOn: $mapper.hrvToHueEnabled)
                    Toggle("HR → Intensity Mapping", isOn: $mapper.hrToIntensityEnabled)
                    Toggle("Gesture → Strobe", isOn: $mapper.gestureStrobeEnabled)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)

                // DMX Channel Info
                VStack(alignment: .leading, spacing: 8) {
                    Text("DMX Configuration")
                        .font(.headline)

                    HStack {
                        Text("Protocol:")
                        Spacer()
                        Text("Art-Net (UDP Port 6454)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Universe:")
                        Spacer()
                        Text("512 channels")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Fixtures:")
                        Spacer()
                        Text("RGBW + Dimmers")
                            .foregroundColor(.secondary)
                    }
                }
                .font(.caption)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
        }
        .padding()
    }
}

struct LightSceneButton: View {
    let scene: MIDIToLightMapper.LightScene
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(scene.rawValue)
                        .font(.subheadline)
                        .bold()
                    Text(scene.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.orange)
                }
            }
            .padding()
            .background(isSelected ? Color.orange.opacity(0.2) : Color(.tertiarySystemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Helper Views

struct SectionHeader: View {
    let title: String
    let icon: String
    let isActive: Bool

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isActive ? .green : .secondary)

            Text(title)
                .font(.title2)
                .bold()

            Spacer()

            if isActive {
                Text("ACTIVE")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(4)
            } else {
                Text("INACTIVE")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
            }
        }
    }
}

struct ParameterSlider: View {
    let label: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text("\(String(format: "%.2f", value)) \(unit)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Slider(value: $value, in: range)
        }
    }
}

// MARK: - Preview

struct Phase3ControlsView_Previews: PreviewProvider {
    static var previews: some View {
        Phase3ControlsView(
            spatialEngine: SpatialAudioEngine(),
            visualMapper: MIDIToVisualMapper(),
            push3Controller: Push3LEDController(),
            lightMapper: MIDIToLightMapper()
        )
    }
}
