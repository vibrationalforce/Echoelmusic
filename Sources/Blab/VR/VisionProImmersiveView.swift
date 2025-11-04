import SwiftUI

#if os(visionOS)
import RealityKit
#endif

/// Vision Pro Immersive Audio View
///
/// Full immersive experience for spatial audio control.
///
/// Features:
/// - 3D audio source visualization
/// - Hand gesture controls
/// - Eye gaze interaction
/// - Volumetric UI
/// - Spatial audio presets
///
/// Usage:
/// ```swift
/// ImmersiveSpace(id: "AudioSpace") {
///     VisionProImmersiveView()
/// }
/// ```
@available(iOS 17.0, *)
struct VisionProImmersiveView: View {

    @ObservedObject var visionPro = VisionProManager.shared
    @State private var selectedSource: UUID?
    @State private var showControls = true

    var body: some View {
        ZStack {
            // 3D Audio Source Visualization
            if visionPro.isImmersiveSessionActive {
                audioSourceVisualization
            }

            // Floating controls
            if showControls {
                VStack {
                    Spacer()
                    floatingControls
                        .frame(maxWidth: 600)
                        .padding()
                }
            }
        }
        .onAppear {
            Task {
                do {
                    try await visionPro.startImmersiveSession()
                } catch {
                    print("Failed to start immersive session: \(error)")
                }
            }
        }
        .onDisappear {
            visionPro.endImmersiveSession()
        }
    }

    // MARK: - Audio Source Visualization

    private var audioSourceVisualization: some View {
        ZStack {
            ForEach(visionPro.getVisualizationData()) { point in
                audioSourceSphere(point)
            }
        }
    }

    private func audioSourceSphere(_ point: VisionProManager.VisualizationPoint) -> some View {
        // In real implementation, use RealityKit entities
        // This is a placeholder
        Text("🔊")
            .font(.system(size: 40 * point.size))
            .opacity(point.isActive ? 1.0 : 0.5)
            .onTapGesture {
                selectedSource = point.id
            }
    }

    // MARK: - Floating Controls

    private var floatingControls: some View {
        VStack(spacing: 20) {
            // Session info
            HStack {
                Image(systemName: "visionpro")
                    .font(.title2)

                VStack(alignment: .leading) {
                    Text("Immersive Audio")
                        .font(.headline)
                    Text("\(visionPro.audioSources.count) sources active")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: { showControls.toggle() }) {
                    Image(systemName: showControls ? "eye.slash" : "eye")
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(16)

            // Presets
            HStack(spacing: 12) {
                presetButton("Surround", preset: .surroundSound)
                presetButton("Concert", preset: .concertHall)
                presetButton("Studio", preset: .studio)
                presetButton("Nature", preset: .nature)
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(16)

            // Controls
            if let selectedID = selectedSource,
               let source = visionPro.audioSources.first(where: { $0.id == selectedID }) {
                sourceControls(source)
            }
        }
        .glassBackgroundEffect()
    }

    private func presetButton(_ label: String, preset: VisionProManager.SpatialPreset) -> some View {
        Button(action: {
            visionPro.applySpatialPreset(preset)
        }) {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .buttonStyle(.bordered)
    }

    private func sourceControls(_ source: VisionProManager.SpatialAudioSource) -> some View {
        VStack(spacing: 16) {
            Text(source.name)
                .font(.headline)

            HStack {
                Text("Volume")
                Spacer()
                Text(String(format: "%.0f%%", source.volume * 100))
                    .foregroundColor(.secondary)
            }

            // Volume would be controlled via hand gestures in real implementation

            HStack {
                Button("Remove") {
                    visionPro.removeAudioSource(source.id)
                    selectedSource = nil
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
}

/// Vision Pro Control View (for regular windows)
@available(iOS 17.0, *)
struct VisionProControlView: View {

    @ObservedObject var visionPro = VisionProManager.shared
    @State private var showingAddSource = false

    var body: some View {
        Form {
            // Session status
            Section {
                HStack {
                    Image(systemName: visionPro.isImmersiveSessionActive ? "visionpro.fill" : "visionpro")
                        .font(.largeTitle)
                        .foregroundColor(visionPro.isImmersiveSessionActive ? .green : .gray)

                    VStack(alignment: .leading) {
                        Text(visionPro.isImmersiveSessionActive ? "Immersive Session Active" : "Ready")
                            .font(.headline)

                        if visionPro.isImmersiveSessionActive {
                            Text("\(visionPro.audioSources.count) audio sources")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()
                }
                .padding()
            }

            // Audio sources
            Section {
                if visionPro.audioSources.isEmpty {
                    Text("No audio sources")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(visionPro.audioSources) { source in
                        audioSourceRow(source)
                    }
                }
            } header: {
                HStack {
                    Text("Audio Sources")
                    Spacer()
                    Button(action: { showingAddSource = true }) {
                        Image(systemName: "plus.circle")
                    }
                }
            }

            // Tracking status
            Section("Tracking") {
                HStack {
                    Label("Hand Tracking", systemImage: "hand.raised")
                    Spacer()
                    Image(systemName: visionPro.isHandTrackingEnabled ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(visionPro.isHandTrackingEnabled ? .green : .gray)
                }

                HStack {
                    Label("Eye Tracking", systemImage: "eye")
                    Spacer()
                    Image(systemName: visionPro.isEyeTrackingEnabled ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(visionPro.isEyeTrackingEnabled ? .green : .gray)
                }
            }

            // Presets
            Section("Spatial Presets") {
                Button("Surround Sound") {
                    visionPro.applySpatialPreset(.surroundSound)
                }

                Button("Concert Hall") {
                    visionPro.applySpatialPreset(.concertHall)
                }

                Button("Studio") {
                    visionPro.applySpatialPreset(.studio)
                }

                Button("Nature") {
                    visionPro.applySpatialPreset(.nature)
                }

                Button("Meditation") {
                    visionPro.applySpatialPreset(.meditation)
                }
            }

            // Settings
            Section("Settings") {
                NavigationLink("Configuration") {
                    VisionProSettingsView()
                }
            }
        }
        .navigationTitle("Vision Pro")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddSource) {
            AddAudioSourceSheet()
        }
    }

    private func audioSourceRow(_ source: VisionProManager.SpatialAudioSource) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Circle()
                    .fill(Color(source.visualizationColor))
                    .frame(width: 12, height: 12)

                Text(source.name)
                    .font(.headline)

                Spacer()

                if source.isPlaying {
                    Image(systemName: "waveform")
                        .foregroundColor(.green)
                }
            }

            HStack {
                Text("Position: (\(String(format: "%.1f", source.position.x)), \(String(format: "%.1f", source.position.y)), \(String(format: "%.1f", source.position.z)))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text("Volume: \(Int(source.volume * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

@available(iOS 17.0, *)
struct VisionProSettingsView: View {
    @ObservedObject var visionPro = VisionProManager.shared

    var body: some View {
        Form {
            Section("Quality") {
                Picker("Spatial Audio Quality", selection: .constant(visionPro.configuration.spatialAudioQuality)) {
                    Text("Low").tag(VisionProManager.SpatialAudioQuality.low)
                    Text("Medium").tag(VisionProManager.SpatialAudioQuality.medium)
                    Text("High").tag(VisionProManager.SpatialAudioQuality.high)
                    Text("Ultra").tag(VisionProManager.SpatialAudioQuality.ultra)
                }
            }

            Section("Tracking") {
                Toggle("Hand Tracking", isOn: .constant(visionPro.configuration.enableHandTracking))
                Toggle("Eye Tracking", isOn: .constant(visionPro.configuration.enableEyeTracking))
            }

            Section("Immersive Style") {
                Picker("Style", selection: .constant(visionPro.configuration.immersiveStyle)) {
                    Text("Mixed").tag(VisionProManager.ImmersiveStyle.mixed)
                    Text("Progressive").tag(VisionProManager.ImmersiveStyle.progressive)
                    Text("Full").tag(VisionProManager.ImmersiveStyle.full)
                }
            }

            Section("Limits") {
                Stepper("Max Audio Sources: \(visionPro.configuration.maxAudioSources)",
                       value: .constant(visionPro.configuration.maxAudioSources),
                       in: 1...64)
            }
        }
        .navigationTitle("Vision Pro Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

@available(iOS 17.0, *)
struct AddAudioSourceSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var sourceName = ""
    @State private var xPosition: Float = 0
    @State private var yPosition: Float = 0
    @State private var zPosition: Float = 0

    var body: some View {
        NavigationView {
            Form {
                TextField("Source Name", text: $sourceName)

                Section("Position") {
                    HStack {
                        Text("X")
                        Slider(value: $xPosition, in: -10...10)
                        Text(String(format: "%.1f", xPosition))
                            .frame(width: 40)
                    }

                    HStack {
                        Text("Y")
                        Slider(value: $yPosition, in: -10...10)
                        Text(String(format: "%.1f", yPosition))
                            .frame(width: 40)
                    }

                    HStack {
                        Text("Z")
                        Slider(value: $zPosition, in: -10...10)
                        Text(String(format: "%.1f", zPosition))
                            .frame(width: 40)
                    }
                }
            }
            .navigationTitle("Add Audio Source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let source = VisionProManager.SpatialAudioSource(
                            name: sourceName,
                            position: SIMD3(xPosition, yPosition, zPosition)
                        )
                        VisionProManager.shared.placeAudioSource(source)
                        dismiss()
                    }
                    .disabled(sourceName.isEmpty)
                }
            }
        }
    }
}

@available(iOS 17.0, *)
struct VisionProControlView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            VisionProControlView()
        }
    }
}
