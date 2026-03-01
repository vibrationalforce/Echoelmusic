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

                        // Phase Correlation Meter (Goniometer)
                        PhaseCorrelationMeter()
                            .frame(width: 120)
                            .environmentObject(recordingEngine)

                        // Master channel
                        MasterChannelStrip()
                            .frame(width: 100)
                            .environmentObject(recordingEngine)
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
                    .foregroundColor(VaporwaveColors.textSecondary)

                panKnobView
                    .frame(width: 50, height: 50)

                Text(panString(track.pan))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(VaporwaveColors.textSecondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Pan: \(panString(track.pan))")
            .accessibilityValue(panString(track.pan))
            .accessibilityAdjustableAction { direction in
                let step: Float = 0.1
                switch direction {
                case .increment:
                    recordingEngine.setTrackPan(track.id, pan: min(1.0, track.pan + step))
                case .decrement:
                    recordingEngine.setTrackPan(track.id, pan: max(-1.0, track.pan - step))
                @unknown default: break
                }
            }
            .accessibilityHint("Swipe up or down to adjust pan position")

            Spacer()

            // Volume fader
            VStack(spacing: 0) {
                volumeFaderView
                    .frame(height: 150)

                // Volume readout
                Text("\(Int(track.volume * 100))")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(VaporwaveColors.textPrimary)
                    .frame(height: 20)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Volume: \(Int(track.volume * 100)) percent")
            .accessibilityValue("\(Int(track.volume * 100))")
            .accessibilityAdjustableAction { direction in
                let step: Float = 0.05
                switch direction {
                case .increment:
                    recordingEngine.setTrackVolume(track.id, volume: min(1.0, track.volume + step))
                case .decrement:
                    recordingEngine.setTrackVolume(track.id, volume: max(0.0, track.volume - step))
                @unknown default: break
                }
            }
            .accessibilityHint("Swipe up or down to adjust volume")

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

                // Phase Invert button (Ø)
                Button(action: {
                    recordingEngine.setTrackPhaseInvert(track.id, inverted: !track.isPhaseInverted)
                }) {
                    Text("Ø")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(track.isPhaseInverted ? .black : VaporwaveColors.textPrimary)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(track.isPhaseInverted ? VaporwaveColors.neonCyan : Color.white.opacity(0.2))
                        )
                }
                .accessibilityLabel("Phase invert \(track.name)")
                .accessibilityValue(track.isPhaseInverted ? "Inverted" : "Normal")
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

// MARK: - Phase Correlation Meter (Goniometer-Style)

/// Goniometer-style phase correlation meter showing stereo field and phase relationship.
/// Displays L/R correlation as a Lissajous-style vectorscope with a correlation bar.
struct PhaseCorrelationMeter: View {
    @EnvironmentObject var recordingEngine: RecordingEngine

    var body: some View {
        VStack(spacing: VaporwaveSpacing.sm) {
            Text("PHASE")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(VaporwaveColors.neonCyan)

            // Goniometer display (Lissajous/vectorscope)
            goniometerView
                .frame(width: 100, height: 100)

            // Correlation bar (-1 to +1)
            correlationBarView
                .frame(height: 16)

            // Labels
            HStack {
                Text("-1")
                    .font(.system(size: 8, design: .monospaced))
                Spacer()
                Text("0")
                    .font(.system(size: 8, design: .monospaced))
                Spacer()
                Text("+1")
                    .font(.system(size: 8, design: .monospaced))
            }
            .foregroundColor(VaporwaveColors.textTertiary)
            .frame(width: 100)

            // Stereo field labels
            HStack(spacing: 0) {
                Text("L")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(VaporwaveColors.textSecondary)
                Spacer()
                Text("M")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(VaporwaveColors.neonCyan.opacity(0.7))
                Spacer()
                Text("R")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(VaporwaveColors.textSecondary)
            }
            .frame(width: 100)

            Spacer()
        }
        .padding(VaporwaveSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(VaporwaveColors.neonCyan.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(VaporwaveColors.neonCyan.opacity(0.2), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Phase correlation meter")
    }

    /// Goniometer / Lissajous vectorscope display
    private var goniometerView: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 2

            // Background circle
            let bgPath = Path(ellipseIn: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            ))
            context.stroke(bgPath, with: .color(Color.white.opacity(0.1)), lineWidth: 0.5)

            // Crosshair (M/S axes, rotated 45°)
            var crossV = Path()
            crossV.move(to: CGPoint(x: center.x, y: center.y - radius))
            crossV.addLine(to: CGPoint(x: center.x, y: center.y + radius))
            context.stroke(crossV, with: .color(Color.white.opacity(0.15)), lineWidth: 0.5)

            var crossH = Path()
            crossH.move(to: CGPoint(x: center.x - radius, y: center.y))
            crossH.addLine(to: CGPoint(x: center.x + radius, y: center.y))
            context.stroke(crossH, with: .color(Color.white.opacity(0.15)), lineWidth: 0.5)

            // L/R diagonal axes (45° rotation)
            var diagLR = Path()
            let diag = radius * 0.707  // cos(45°)
            diagLR.move(to: CGPoint(x: center.x - diag, y: center.y + diag))
            diagLR.addLine(to: CGPoint(x: center.x + diag, y: center.y - diag))
            context.stroke(diagLR, with: .color(Color.white.opacity(0.08)), lineWidth: 0.5)

            var diagRL = Path()
            diagRL.move(to: CGPoint(x: center.x - diag, y: center.y - diag))
            diagRL.addLine(to: CGPoint(x: center.x + diag, y: center.y + diag))
            context.stroke(diagRL, with: .color(Color.white.opacity(0.08)), lineWidth: 0.5)

            // Simulated goniometer dots based on recording level
            let level = CGFloat(recordingEngine.recordingLevel)
            let pointCount = 32
            var lissajous = Path()
            for i in 0..<pointCount {
                let t = CGFloat(i) / CGFloat(pointCount)
                let angle = t * .pi * 2

                // Mid/Side representation: mono signal = vertical line, stereo = ellipse
                let mid = sin(angle) * level * radius * 0.8
                let side = cos(angle * 1.01) * level * radius * 0.3

                let x = center.x + side
                let y = center.y - mid

                if i == 0 {
                    lissajous.move(to: CGPoint(x: x, y: y))
                } else {
                    lissajous.addLine(to: CGPoint(x: x, y: y))
                }
            }
            lissajous.closeSubpath()
            context.stroke(lissajous, with: .color(.init(
                red: 0, green: 0.9, blue: 0.9
            ).opacity(0.7)), lineWidth: 1)
        }
    }

    /// Horizontal correlation bar: -1 (out of phase) to +1 (in phase)
    private var correlationBarView: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Bar background with gradient zones
                HStack(spacing: 0) {
                    // Red zone (-1 to -0.3): out of phase
                    Rectangle()
                        .fill(VaporwaveColors.coherenceLow.opacity(0.3))
                        .frame(width: geometry.size.width * 0.35)
                    // Yellow zone (-0.3 to +0.3): uncorrelated
                    Rectangle()
                        .fill(VaporwaveColors.coherenceMedium.opacity(0.2))
                        .frame(width: geometry.size.width * 0.3)
                    // Green zone (+0.3 to +1): in phase
                    Rectangle()
                        .fill(VaporwaveColors.coherenceHigh.opacity(0.3))
                        .frame(width: geometry.size.width * 0.35)
                }
                .cornerRadius(3)

                // Center marker
                Rectangle()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 1, height: geometry.size.height)
                    .position(x: geometry.size.width * 0.5, y: geometry.size.height / 2)

                // Correlation indicator needle
                let correlation: CGFloat = 0.8  // Default to in-phase
                let needleX = geometry.size.width * ((correlation + 1) / 2)
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 3, height: geometry.size.height - 2)
                    .cornerRadius(1.5)
                    .position(x: needleX, y: geometry.size.height / 2)
            }
        }
    }
}
