// KammertonWheelView.swift
// Echoelmusic
//
// Concert pitch (Kammerton) tuning wheel with 3 decimal places.
// Rotary wheel for smooth adjustment, preset buttons, and numeric display.
//
// Default: 440.000 Hz (ISO 16)

import SwiftUI
import Combine

// MARK: - Kammerton Wheel View

/// Rotary tuning wheel for setting concert pitch (A4 reference frequency)
public struct KammertonWheelView: View {
    @ObservedObject private var tuning: TuningManager

    /// Drag state for the wheel rotation
    @State private var dragAngle: Double = 0
    @State private var lastDragAngle: Double = 0
    @State private var isEditing: Bool = false
    @State private var editText: String = ""

    /// Haptic feedback generator
    #if os(iOS)
    private let haptic = UIImpactFeedbackGenerator(style: .light)
    #endif

    public init(tuning: TuningManager = .shared) {
        self.tuning = tuning
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Header
            Text("Kammerton")
                .font(.headline)
                .foregroundStyle(.secondary)

            // Frequency display
            frequencyDisplay

            // Tuning wheel
            tuningWheel
                .frame(width: 200, height: 200)

            // Preset buttons
            presetButtons

            // Fine adjustment buttons
            fineAdjustment
        }
        .padding()
    }

    // MARK: - Frequency Display

    private var frequencyDisplay: some View {
        VStack(spacing: 4) {
            if isEditing {
                HStack(spacing: 4) {
                    TextField("Hz", text: $editText)
                        #if os(iOS) || os(visionOS)
                        .keyboardType(.decimalPad)
                        #endif
                        .multilineTextAlignment(.center)
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .frame(width: 180)
                        .onSubmit { commitEdit() }
                    Text("Hz")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(String(format: "%.3f", tuning.concertPitch))
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .onTapGesture {
                            editText = String(format: "%.3f", tuning.concertPitch)
                            isEditing = true
                        }
                    Text("Hz")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            // Cents offset from 440
            if tuning.concertPitch != 440.0 {
                let cents = 1200.0 * Foundation.log2(tuning.concertPitch / 440.0)
                Text(String(format: "%+.1f cents from 440 Hz", cents))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Tuning Wheel

    private var tuningWheel: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [.blue, .cyan, .blue],
                        center: .center
                    ),
                    lineWidth: 8
                )
                .opacity(0.3)

            // Tick marks
            ForEach(0..<60, id: \.self) { tick in
                let isMajor = tick % 5 == 0
                Rectangle()
                    .fill(isMajor ? Color.primary : Color.secondary.opacity(0.4))
                    .frame(width: isMajor ? 2 : 1, height: isMajor ? 16 : 8)
                    .offset(y: -88)
                    .rotationEffect(.degrees(Double(tick) * 6))
            }

            // Needle indicator
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 3, height: 30)
                Spacer()
            }
            .frame(height: 90)
            .rotationEffect(.degrees(pitchToAngle(tuning.concertPitch)))

            // Center display
            VStack(spacing: 2) {
                Text("A4")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.secondary)
                Text(tuning.selectedReference.rawValue.replacingOccurrences(of: " Hz)", with: ")"))
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }

            // Interactive drag area
            Circle()
                .fill(Color.clear)
                .contentShape(Circle())
                .gesture(wheelDragGesture)
        }
    }

    // MARK: - Preset Buttons

    private var presetButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TuningManager.TuningPreset.allCases.filter { $0 != .custom }) { preset in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            tuning.applyPreset(preset)
                        }
                        #if os(iOS)
                        haptic.impactOccurred()
                        #endif
                    } label: {
                        Text(presetLabel(preset))
                            .font(.system(size: 13, weight: tuning.selectedReference == preset ? .bold : .regular))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(tuning.selectedReference == preset
                                          ? Color.accentColor.opacity(0.2)
                                          : Color.secondary.opacity(0.1))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Fine Adjustment

    private var fineAdjustment: some View {
        HStack(spacing: 20) {
            // -1 Hz
            adjustButton(label: "-1", delta: -TuningManager.coarseStep)
            // -0.1 Hz
            adjustButton(label: "-0.1", delta: -0.1)
            // -0.001 Hz
            adjustButton(label: "-0.001", delta: -TuningManager.fineStep)

            // Reset button
            Button {
                withAnimation(.spring(response: 0.3)) {
                    tuning.resetToStandard()
                }
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 14))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.bordered)

            // +0.001 Hz
            adjustButton(label: "+0.001", delta: TuningManager.fineStep)
            // +0.1 Hz
            adjustButton(label: "+0.1", delta: 0.1)
            // +1 Hz
            adjustButton(label: "+1", delta: TuningManager.coarseStep)
        }
    }

    private func adjustButton(label: String, delta: Double) -> some View {
        Button {
            withAnimation(.spring(response: 0.15)) {
                tuning.nudge(by: delta)
            }
            #if os(iOS)
            haptic.impactOccurred()
            #endif
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .frame(minWidth: 44, minHeight: 32)
        }
        .buttonStyle(.bordered)
    }

    // MARK: - Gesture

    private var wheelDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let center = CGPoint(x: 100, y: 100)
                let dx = value.location.x - center.x
                let dy = value.location.y - center.y
                let angle = atan2(dy, dx) * 180 / .pi

                let delta = angleDelta(from: lastDragAngle, to: angle)
                lastDragAngle = angle

                // 1 degree of wheel rotation = 0.1 Hz
                let hzDelta = delta * 0.1
                tuning.nudge(by: hzDelta)
                tuning.selectedReference = .custom
            }
            .onEnded { _ in
                lastDragAngle = 0
            }
    }

    // MARK: - Helpers

    private func pitchToAngle(_ pitch: Double) -> Double {
        // Map pitch range to 0-360 degrees
        // 440 Hz = 0 degrees (top)
        let normalized = (pitch - TuningManager.minimumPitch) / (TuningManager.maximumPitch - TuningManager.minimumPitch)
        return normalized * 300 - 150 // -150 to +150 range
    }

    private func angleDelta(from a: Double, to b: Double) -> Double {
        var delta = b - a
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        return delta
    }

    private func presetLabel(_ preset: TuningManager.TuningPreset) -> String {
        switch preset {
        case .baroque415:  return "415"
        case .verdi432:    return "432"
        case .standard440: return "440"
        case .concert442:  return "442"
        case .concert443:  return "443"
        case .custom:      return "Custom"
        }
    }

    private func commitEdit() {
        isEditing = false
        if let value = Double(editText.replacingOccurrences(of: ",", with: ".")) {
            let clamped = Swift.max(TuningManager.minimumPitch, Swift.min(TuningManager.maximumPitch, value))
            let rounded = (clamped * 1000).rounded() / 1000
            withAnimation(.spring(response: 0.3)) {
                tuning.concertPitch = rounded
                tuning.selectedReference = .custom
            }
        }
    }
}

// MARK: - Compact Variant

/// Compact inline tuning display for toolbars / settings rows
public struct KammertonCompactView: View {
    @ObservedObject private var tuning: TuningManager

    public init(tuning: TuningManager = .shared) {
        self.tuning = tuning
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "tuningfork")
                .foregroundStyle(.secondary)

            Text(String(format: "A4 = %.3f Hz", tuning.concertPitch))
                .font(.system(size: 13, weight: .medium, design: .monospaced))

            Stepper("", value: $tuning.concertPitch,
                    in: TuningManager.minimumPitch...TuningManager.maximumPitch,
                    step: 0.001)
            .labelsHidden()
        }
    }
}

// MARK: - Preview

#if DEBUG
struct KammertonWheelView_Previews: PreviewProvider {
    static var previews: some View {
        KammertonWheelView()
            .preferredColorScheme(.dark)
    }
}
#endif
