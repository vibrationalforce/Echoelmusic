import SwiftUI

/// Professional mixer view with faders and metering
/// Uses VaporwaveTheme for consistent styling
struct MixerView: View {
    @EnvironmentObject var recordingEngine: RecordingEngine
    @Binding var session: Session

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: VaporwaveSpacing.lg) {
                        // OPTIMIZED: Explicit id binding for better list performance
                        ForEach(session.tracks, id: \.id) { track in
                            MixerChannelStrip(track: track)
                                .frame(width: 100)
                                .environmentObject(recordingEngine)
                        }

                        // Master channel
                        MasterChannelStrip()
                            .frame(width: 100)
                    }
                    .padding()
                }
                .frame(height: geometry.size.height)
            }
            .background(VaporwaveGradients.background)
            .navigationTitle("Mixer")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// Individual mixer channel strip
struct MixerChannelStrip: View {
    @EnvironmentObject var recordingEngine: RecordingEngine
    let track: Track

    var body: some View {
        VStack(spacing: VaporwaveSpacing.md) {
            // Track name
            Text(track.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(VaporwaveColors.textPrimary)
                .lineLimit(1)
                .frame(height: 30)

            // Peak meter
            peakMeterView
                .frame(height: 200)

            // Pan knob
            VStack(spacing: VaporwaveSpacing.xs) {
                Text("PAN")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(VaporwaveColors.textTertiary)

                panKnobView
                    .frame(width: 50, height: 50)

                Text(panString(track.pan))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(VaporwaveColors.textSecondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Pan position: \(panString(track.pan))")

            Spacer()

            // Volume fader
            volumeFaderView
                .frame(height: 150)

            // Volume readout
            Text("\(Int(track.volume * 100))")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(VaporwaveColors.textPrimary)
                .frame(height: 20)
                .accessibilityLabel("Volume: \(Int(track.volume * 100)) percent")

            // Control buttons
            HStack(spacing: VaporwaveSpacing.sm) {
                // Mute button
                Button(action: {
                    recordingEngine.setTrackMuted(track.id, muted: !track.isMuted)
                }) {
                    Text("M")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(track.isMuted ? .black : VaporwaveColors.textPrimary)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(track.isMuted ? VaporwaveColors.coherenceLow : Color.white.opacity(0.2))
                        )
                }
                .accessibilityLabel("Mute \(track.name)")
                .accessibilityValue(track.isMuted ? "Muted" : "Not muted")

                // Solo button
                Button(action: {
                    recordingEngine.setTrackSoloed(track.id, soloed: !track.isSoloed)
                }) {
                    Text("S")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(track.isSoloed ? .black : VaporwaveColors.textPrimary)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(track.isSoloed ? VaporwaveColors.coherenceMedium : Color.white.opacity(0.2))
                        )
                }
                .accessibilityLabel("Solo \(track.name)")
                .accessibilityValue(track.isSoloed ? "Soloed" : "Not soloed")
            }

            // Track type indicator
            HStack(spacing: VaporwaveSpacing.xs) {
                Image(systemName: track.type.icon)
                    .font(.system(size: 8))
                Text(track.type.rawValue)
                    .font(.system(size: 8))
            }
            .foregroundColor(VaporwaveColors.textTertiary)
            .padding(.bottom, VaporwaveSpacing.sm)
        }
        .padding(VaporwaveSpacing.md)
        .glassCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(track.name) channel strip")
    }

    // MARK: - Peak Meter

    private var peakMeterView: some View {
        GeometryReader { geometry in
            VStack(spacing: 2) {
                // Peak meter segments
                ForEach(0..<20, id: \.self) { segment in
                    let segmentLevel = Float(20 - segment) / 20.0
                    let isActive = track.volume >= segmentLevel

                    Rectangle()
                        .fill(isActive ? meterColor(for: segmentLevel) : Color.gray.opacity(0.2))
                        .frame(height: (geometry.size.height - 38) / 20)
                        .cornerRadius(2)
                }
            }
        }
    }

    private func meterColor(for level: Float) -> Color {
        if level > 0.9 {
            return VaporwaveColors.coherenceLow  // Clipping zone
        } else if level > 0.7 {
            return VaporwaveColors.coherenceMedium  // Warning zone
        } else {
            return VaporwaveColors.coherenceHigh  // Safe zone
        }
    }

    // MARK: - Pan Knob

    private var panKnobView: some View {
        ZStack {
            // Knob background
            Circle()
                .fill(VaporwaveColors.deepBlack.opacity(0.5))

            // Knob indicator
            Circle()
                .fill(Color.white)
                .frame(width: 6, height: 6)
                .offset(y: -18)
                .rotationEffect(.degrees(Double(track.pan) * 135))

            // Center dot
            Circle()
                .fill(Color.white.opacity(0.5))
                .frame(width: 4, height: 4)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let center = CGPoint(x: 25, y: 25)
                    let angle = atan2(value.location.y - center.y, value.location.x - center.x)
                    let degrees = angle * 180 / .pi + 90

                    // Map -135 to +135 degrees to -1 to +1 pan
                    var normalizedPan = Float(degrees / 135.0)
                    normalizedPan = max(-1, min(1, normalizedPan))

                    recordingEngine.setTrackPan(track.id, pan: normalizedPan)
                }
        )
    }

    // MARK: - Volume Fader

    private var volumeFaderView: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Fader track
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 30)

                // Fader fill
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [VaporwaveColors.neonCyan, VaporwaveColors.neonPurple]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 30, height: geometry.size.height * CGFloat(track.volume))

                // Fader thumb
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white)
                    .frame(width: 40, height: 20)
                    .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                    .position(
                        x: geometry.size.width / 2,
                        y: geometry.size.height * CGFloat(1 - track.volume)
                    )
            }
            .frame(maxWidth: .infinity)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let normalizedY = 1 - (value.location.y / geometry.size.height)
                        let volume = Float(max(0, min(1, normalizedY)))
                        recordingEngine.setTrackVolume(track.id, volume: volume)
                    }
            )
        }
    }

    // MARK: - Helpers

    private func panString(_ pan: Float) -> String {
        if abs(pan) < 0.01 {
            return "C"
        } else if pan < 0 {
            return "L\(Int(abs(pan) * 100))"
        } else {
            return "R\(Int(pan * 100))"
        }
    }
}

/// Master channel strip
struct MasterChannelStrip: View {
    @EnvironmentObject var recordingEngine: RecordingEngine

    var body: some View {
        VStack(spacing: VaporwaveSpacing.md) {
            // Master label
            Text("MASTER")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(VaporwaveColors.neonPink)
                .frame(height: 30)

            // Peak meter
            masterPeakMeterView
                .frame(height: 200)
                .accessibilityLabel("Master level meter")

            Spacer()

            // Volume readout
            Text("0.0 dB")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(VaporwaveColors.textPrimary)
                .frame(height: 20)
                .accessibilityLabel("Master volume: 0 decibels")

            // Master icon
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 24))
                .foregroundColor(VaporwaveColors.neonPink.opacity(0.5))
                .padding(.bottom, 40)
        }
        .padding(VaporwaveSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(VaporwaveColors.neonPink.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(VaporwaveColors.neonPink.opacity(0.3), lineWidth: 2)
                )
        )
        .neonGlow(color: VaporwaveColors.neonPink, radius: 10)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Master channel strip")
    }

    private var masterPeakMeterView: some View {
        GeometryReader { geometry in
            VStack(spacing: 2) {
                ForEach(0..<20, id: \.self) { segment in
                    let segmentLevel = Float(20 - segment) / 20.0
                    let isActive = recordingEngine.recordingLevel >= segmentLevel

                    Rectangle()
                        .fill(isActive ? meterColor(for: segmentLevel) : Color.gray.opacity(0.2))
                        .frame(height: (geometry.size.height - 38) / 20)
                        .cornerRadius(2)
                }
            }
        }
    }

    private func meterColor(for level: Float) -> Color {
        if level > 0.9 {
            return VaporwaveColors.coherenceLow  // Clipping zone
        } else if level > 0.7 {
            return VaporwaveColors.coherenceMedium  // Warning zone
        } else {
            return VaporwaveColors.coherenceHigh  // Safe zone
        }
    }
}
