import SwiftUI

/// Full-screen visualization view for Apple TV
/// Immersive biofeedback visuals on large displays
struct VisualizationView: View {

    @EnvironmentObject var visualizationManager: TVVisualizationManager
    @EnvironmentObject var connectivity: TVConnectivityManager

    @State private var showControls = true
    @State private var controlsTimer: Timer?

    var body: some View {
        ZStack {
            // Full-screen visualization canvas
            VisualizationCanvas(
                style: visualizationManager.currentStyle,
                intensity: visualizationManager.intensity,
                coherence: averageCoherence
            )
            .ignoresSafeArea()

            // Overlay controls (auto-hide)
            if showControls {
                VStack {
                    // Top bar
                    HStack {
                        // Connected devices indicator
                        HStack(spacing: 8) {
                            Image(systemName: "iphone")
                                .foregroundColor(.white)
                            Text("\(connectivity.connectedDevices.count)")
                                .font(.title3.bold())
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(16)

                        Spacer()

                        // Average coherence
                        if !connectivity.connectedDevices.isEmpty {
                            HStack(spacing: 8) {
                                Text("Coherence")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))

                                Text("\(Int(averageCoherence))%")
                                    .font(.title2.bold())
                                    .foregroundColor(coherenceColor)
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(16)
                        }
                    }
                    .padding()

                    Spacer()

                    // Bottom controls
                    HStack(spacing: 40) {
                        // Style selector
                        ForEach(VisualizationStyle.allCases, id: \.self) { style in
                            Button(action: {
                                visualizationManager.setStyle(style)
                                resetControlsTimer()
                            }) {
                                VStack(spacing: 8) {
                                    Image(systemName: style.icon)
                                        .font(.title)
                                        .foregroundColor(visualizationManager.currentStyle == style ? .cyan : .white)

                                    Text(style.name)
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }
                                .frame(width: 120)
                                .padding()
                                .background(
                                    visualizationManager.currentStyle == style
                                        ? Color.cyan.opacity(0.3)
                                        : Color.black.opacity(0.6)
                                )
                                .cornerRadius(16)
                            }
                            .buttonStyle(.card)
                        }
                    }
                    .padding(.bottom, 60)
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            startControlsTimer()
        }
        .onDisappear {
            stopControlsTimer()
        }
        .focusable()
        .onMoveCommand { direction in
            // Remote interaction shows controls
            showControls = true
            resetControlsTimer()
        }
        .onPlayPauseCommand {
            visualizationManager.togglePlayPause()
            showControls = true
            resetControlsTimer()
        }
    }

    // MARK: - Computed Properties

    private var averageCoherence: Double {
        guard !connectivity.connectedDevices.isEmpty else { return 50.0 }

        let total = connectivity.connectedDevices.reduce(0.0) { $0 + $1.coherence }
        return total / Double(connectivity.connectedDevices.count)
    }

    private var coherenceColor: Color {
        if averageCoherence >= 80 {
            return .green
        } else if averageCoherence >= 60 {
            return .yellow
        } else {
            return .red
        }
    }

    // MARK: - Controls Timer

    private func startControlsTimer() {
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            withAnimation(.easeOut(duration: 0.3)) {
                showControls = false
            }
        }
    }

    private func stopControlsTimer() {
        controlsTimer?.invalidate()
        controlsTimer = nil
    }

    private func resetControlsTimer() {
        stopControlsTimer()
        startControlsTimer()
    }
}

/// Visualization canvas with different styles
struct VisualizationCanvas: View {
    let style: VisualizationStyle
    let intensity: Double
    let coherence: Double

    var body: some View {
        ZStack {
            // Background gradient (reactive to coherence)
            LinearGradient(
                colors: backgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .animation(.easeInOut(duration: 2.0), value: coherence)

            // Style-specific visualization
            switch style {
            case .particles:
                ParticleVisualization(intensity: intensity, coherence: coherence)

            case .waves:
                WaveVisualization(intensity: intensity, coherence: coherence)

            case .mandala:
                MandalaVisualization(intensity: intensity, coherence: coherence)

            case .aurora:
                AuroraVisualization(intensity: intensity, coherence: coherence)

            case .breathing:
                BreathingVisualization(intensity: intensity, coherence: coherence)
            }
        }
    }

    private var backgroundColors: [Color] {
        // Color palette based on coherence level
        if coherence >= 80 {
            return [.blue.opacity(0.3), .purple.opacity(0.3), .cyan.opacity(0.3)]
        } else if coherence >= 60 {
            return [.green.opacity(0.3), .teal.opacity(0.3), .blue.opacity(0.3)]
        } else if coherence >= 40 {
            return [.yellow.opacity(0.3), .orange.opacity(0.3), .pink.opacity(0.3)]
        } else {
            return [.red.opacity(0.3), .orange.opacity(0.3), .yellow.opacity(0.3)]
        }
    }
}

// MARK: - Placeholder Visualizations (to be implemented)

struct ParticleVisualization: View {
    let intensity: Double
    let coherence: Double

    var body: some View {
        Text("Particle Visualization")
            .font(.largeTitle)
            .foregroundColor(.white.opacity(0.3))
    }
}

struct WaveVisualization: View {
    let intensity: Double
    let coherence: Double

    var body: some View {
        Text("Wave Visualization")
            .font(.largeTitle)
            .foregroundColor(.white.opacity(0.3))
    }
}

struct MandalaVisualization: View {
    let intensity: Double
    let coherence: Double

    var body: some View {
        Text("Mandala Visualization")
            .font(.largeTitle)
            .foregroundColor(.white.opacity(0.3))
    }
}

struct AuroraVisualization: View {
    let intensity: Double
    let coherence: Double

    var body: some View {
        Text("Aurora Visualization")
            .font(.largeTitle)
            .foregroundColor(.white.opacity(0.3))
    }
}

struct BreathingVisualization: View {
    let intensity: Double
    let coherence: Double

    var body: some View {
        Text("Breathing Visualization")
            .font(.largeTitle)
            .foregroundColor(.white.opacity(0.3))
    }
}

#Preview {
    VisualizationView()
        .environmentObject(TVVisualizationManager())
        .environmentObject(TVConnectivityManager())
}
