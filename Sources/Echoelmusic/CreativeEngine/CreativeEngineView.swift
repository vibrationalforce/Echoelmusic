import SwiftUI

/// Unified Creative Engine View
/// Combines all biometric-reactive visual systems
///
/// **Systems:**
/// - Metal Particle System (HRV-driven)
/// - Fractal Generator (Breathing-synced)
/// - Style Transfer (Heart rate-selected)
/// - Color Mapping (Real-time biometrics)
///
/// **Usage:**
/// ```swift
/// CreativeEngineView(
///     healthKitManager: healthKitManager,
///     mode: .particles
/// )
/// ```
public struct CreativeEngineView: View {

    // MARK: - Mode Selection

    public enum Mode: String, CaseIterable {
        case particles = "Particles"
        case fractals = "Fractals"
        case styleTransfer = "Style Transfer"
        case composite = "Composite"

        var icon: String {
            switch self {
            case .particles: return "sparkles"
            case .fractals: return "triangle.fill"
            case .styleTransfer: return "wand.and.stars"
            case .composite: return "square.stack.3d.up.fill"
            }
        }

        var description: String {
            switch self {
            case .particles: return "HRV-reactive particle field"
            case .fractals: return "Breathing-synchronized fractals"
            case .styleTransfer: return "Neural style transfer"
            case .composite: return "All systems combined"
            }
        }
    }

    // MARK: - Dependencies

    @ObservedObject var healthKitManager: HealthKitManager
    @State private var visualMapper: BiometricVisualMapper
    @State private var styleEngine = StyleTransferEngine()

    // MARK: - State

    var mode: Mode
    @State private var showControls = false

    // MARK: - Initialization

    public init(healthKitManager: HealthKitManager, mode: Mode = .particles) {
        self.healthKitManager = healthKitManager
        self.mode = mode
        _visualMapper = State(initialValue: BiometricVisualMapper(healthKitManager: healthKitManager))
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            // Visual content
            visualContent

            // Overlay controls
            if showControls {
                controlsOverlay
            }

            // Mode toggle button
            VStack {
                HStack {
                    Spacer()

                    Button(action: { showControls.toggle() }) {
                        Image(systemName: showControls ? "xmark.circle.fill" : "gear")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.6))
                            )
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 60)
                }

                Spacer()
            }
        }
        .onAppear {
            visualMapper.startMapping()
        }
        .onDisappear {
            visualMapper.stopMapping()
        }
    }

    // MARK: - Visual Content

    @ViewBuilder
    private var visualContent: some View {
        switch mode {
        case .particles:
            MetalParticleView(visualMapper: visualMapper)

        case .fractals:
            FractalVisualizationView(visualMapper: visualMapper)

        case .styleTransfer:
            StyleTransferPreviewView(healthKitManager: healthKitManager)

        case .composite:
            ZStack {
                // Layer 1: Fractals (background)
                FractalVisualizationView(visualMapper: visualMapper)
                    .opacity(0.4)

                // Layer 2: Particles (foreground)
                MetalParticleView(visualMapper: visualMapper)
                    .opacity(0.8)

                // Layer 3: Color overlay
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                visualMapper.colorScheme.color.opacity(0.2),
                                visualMapper.colorScheme.complementaryColor.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.screen)
            }
        }
    }

    // MARK: - Controls Overlay

    private var controlsOverlay: some View {
        VStack {
            Spacer()

            VStack(spacing: 20) {
                Text("Creative Engine Controls")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                // Biometric readouts
                biometricReadouts

                Divider()
                    .background(Color.white.opacity(0.3))

                // Visual parameters
                visualParameters

                Divider()
                    .background(Color.white.opacity(0.3))

                // Quick presets
                presetButtons
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Color.cyan.opacity(0.5), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Biometric Readouts

    private var biometricReadouts: some View {
        VStack(spacing: 12) {
            Text("Biometric Mappings")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)

            // Heart Rate → Hue
            biometricRow(
                icon: "heart.fill",
                label: "Heart Rate",
                value: "\(Int(healthKitManager.heartRate)) BPM",
                mapping: "→ Hue \(Int(visualMapper.colorScheme.hue))°",
                color: .red
            )

            // HRV → Particles
            biometricRow(
                icon: "waveform.path.ecg",
                label: "HRV Coherence",
                value: "\(Int(healthKitManager.hrvCoherence))%",
                mapping: "→ \(visualMapper.particleConfiguration.particleCount) particles",
                color: .green
            )

            // Breathing → Fractals
            biometricRow(
                icon: "wind",
                label: "Breathing",
                value: "\(String(format: "%.1f", visualMapper.fractalParameters.breathingRate)) BPM",
                mapping: "→ Complexity \(visualMapper.fractalParameters.complexity)",
                color: .cyan
            )

            // Visual Intensity
            biometricRow(
                icon: "gauge",
                label: "Visual Intensity",
                value: "\(Int(visualMapper.visualIntensity * 100))%",
                mapping: "→ Overall arousal",
                color: .orange
            )
        }
    }

    private func biometricRow(icon: String, label: String, value: String, mapping: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 20)

                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))

                Spacer()

                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
            }

            Text(mapping)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))
                .padding(.leading, 24)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Visual Parameters

    private var visualParameters: some View {
        VStack(spacing: 12) {
            Text("Current Configuration")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)

            // Color scheme preview
            HStack(spacing: 12) {
                Circle()
                    .fill(visualMapper.colorScheme.color)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white, lineWidth: 2)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Primary Color")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))

                    Text("H:\(Int(visualMapper.colorScheme.hue))° S:\(Int(visualMapper.colorScheme.saturation * 100))% B:\(Int(visualMapper.colorScheme.brightness * 100))%")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()
            }

            // Triad colors
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(visualMapper.colorScheme.triadicColors[i])
                        .frame(width: 30, height: 30)
                }

                Spacer()

                Text("Triadic Palette")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }

    // MARK: - Preset Buttons

    private var presetButtons: some View {
        VStack(spacing: 12) {
            Text("Quick Presets")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                presetButton(name: "Meditation", icon: "brain", color: .purple) {
                    // Simulate meditative state
                    simulateBiometrics(heartRate: 58, coherence: 92, breathing: 6)
                }

                presetButton(name: "Focus", icon: "eye.fill", color: .blue) {
                    // Simulate focused state
                    simulateBiometrics(heartRate: 72, coherence: 78, breathing: 12)
                }

                presetButton(name: "Energy", icon: "bolt.fill", color: .orange) {
                    // Simulate energized state
                    simulateBiometrics(heartRate: 95, coherence: 65, breathing: 18)
                }
            }
        }
    }

    private func presetButton(name: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20))

                Text(name)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(color, lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Helper Methods

    private func simulateBiometrics(heartRate: Double, coherence: Double, breathing: Double) {
        // This would update the HealthKitManager with simulated values
        // In production: Only use real biometric data
        print("🧪 Simulating: HR=\(heartRate), Coherence=\(coherence), Breathing=\(breathing)")
    }
}

// MARK: - Preview

#Preview {
    CreativeEngineView(
        healthKitManager: HealthKitManager(),
        mode: .composite
    )
}
