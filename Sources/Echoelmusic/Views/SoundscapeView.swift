#if canImport(SwiftUI)
import SwiftUI

/// Main view — bio-reactive soundscape with live biometric display.
/// Minimal, clean. Science-first: real numbers, no decoration.
struct SoundscapeView: View {

    @Environment(SoundscapeEngine.self) private var engine
    @Environment(EchoelBioEngine.self) private var bio
    @State private var showSettings = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Settings button (top right)
                HStack {
                    Spacer()
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.2))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Settings")
                }
                .padding(.top, 8)

                Spacer()

                // Coherence ring — subtle visual feedback
                coherenceRing

                Spacer()

                // Bio metrics
                bioDisplay

                // Play/Pause
                playButton
                    .padding(.top, 32)
                    .padding(.bottom, 16)

                // Source indicator
                sourceLabel
                    .padding(.bottom, 40)
            }
            .padding(.horizontal, 24)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environment(engine)
        }
    }

    // MARK: - Coherence Ring

    private var coherenceRing: some View {
        let coherence = engine.state.coherence
        let breathPhase = engine.state.breathPhase

        return ZStack {
            // Outer ring — coherence level
            Circle()
                .stroke(
                    Color.white.opacity(0.03 + coherence * 0.12),
                    lineWidth: 1
                )
                .frame(width: 200, height: 200)

            // Inner pulse — breath phase
            Circle()
                .fill(Color.white.opacity(0.02 + breathPhase * 0.06))
                .frame(
                    width: 120 + breathPhase * 40,
                    height: 120 + breathPhase * 40
                )
                .animation(.easeInOut(duration: 1.5), value: breathPhase)

            // Heart rate number
            VStack(spacing: 4) {
                Text("\(Int(engine.state.heartRate))")
                    .font(.system(size: 48, weight: .light, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .contentTransition(.numericText())

                Text("BPM")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.25))
                    .textCase(.uppercase)
                    .kerning(2)
            }
        }
    }

    // MARK: - Bio Display

    private var bioDisplay: some View {
        HStack(spacing: 32) {
            metricItem(
                value: String(format: "%.0f", engine.state.hrv * 100),
                label: "HRV"
            )
            metricItem(
                value: String(format: "%.0f%%", engine.state.coherence * 100),
                label: "Coherence"
            )
            metricItem(
                value: engine.state.circadianPhase.rawValue.capitalized,
                label: "Phase"
            )
        }
    }

    private func metricItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
                .contentTransition(.numericText())

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.2))
                .textCase(.uppercase)
                .kerning(1.5)
        }
    }

    // MARK: - Play Button

    private var playButton: some View {
        Button {
            engine.togglePlayback()
        } label: {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(engine.isPlaying ? 0.08 : 0.05))
                    .frame(width: 72, height: 72)

                if engine.isPlaying {
                    // Pause icon
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.white.opacity(0.5))
                            .frame(width: 3, height: 20)
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.white.opacity(0.5))
                            .frame(width: 3, height: 20)
                    }
                } else {
                    // Play icon (triangle)
                    Image(systemName: "play.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(0.5))
                        .offset(x: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(engine.isPlaying ? "Pause soundscape" : "Play soundscape")
    }

    // MARK: - Source Label

    private var sourceLabel: some View {
        let source = engine.state.source
        let weather = engine.state.weatherCondition

        return VStack(spacing: 4) {
            Text("\(source.displayName) · \(weather.rawValue.capitalized)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.15))
                .kerning(1)

            Text(engine.audioOutputName)
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(.white.opacity(0.1))
        }
    }
}

// MARK: - BioDataSource Display Name

extension BioDataSource {
    var displayName: String {
        switch self {
        case .healthKit, .appleWatch: return "Apple Watch"
        case .chestStrap: return "Chest Strap"
        case .ouraRing: return "Oura Ring"
        case .camera: return "Camera"
        case .arkit: return "Face Tracking"
        case .microphone: return "Microphone"
        case .fallback: return "Simulated"
        }
    }
}
#endif
