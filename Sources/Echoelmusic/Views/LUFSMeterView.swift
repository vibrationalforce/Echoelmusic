#if canImport(SwiftUI)
import SwiftUI

// MARK: - LUFS Meter View
/// Broadcast-standard loudness meter (EBU R128 / ITU-R BS.1770)
/// Shows Momentary LUFS (400ms), Short-Term (3s), and Integrated loudness
/// Target: -14 LUFS (streaming) / -23 LUFS (broadcast)

@MainActor
@Observable
final class LUFSMeterState {

    // MARK: - Loudness Values

    /// Momentary LUFS (400ms window)
    var momentaryLUFS: Float = -70

    /// Short-term LUFS (3s window)
    var shortTermLUFS: Float = -70

    /// Integrated LUFS (entire program)
    var integratedLUFS: Float = -70

    /// True peak dBTP
    var truePeak: Float = -70

    /// Loudness range (LRA) in LU
    var loudnessRange: Float = 0

    // MARK: - Internal Buffers

    /// Ring buffer for momentary (400ms at ~60Hz update = 24 samples)
    private var momentaryBuffer: [Float] = []
    private let momentaryWindow = 24

    /// Ring buffer for short-term (3s at ~60Hz update = 180 samples)
    private var shortTermBuffer: [Float] = []
    private let shortTermWindow = 180

    /// Accumulator for integrated (gated)
    private var integratedSum: Double = 0
    private var integratedCount: Int = 0
    private var peakHold: Float = -70

    // MARK: - Update

    /// Call at ~60Hz with current RMS levels (0-1 linear)
    func update(levelL: Float, levelR: Float) {
        // Convert linear RMS to power (squared)
        let powerL = Double(levelL * levelL)
        let powerR = Double(levelR * levelR)
        let meanPower = (powerL + powerR) / 2.0

        // K-weighted approximation: RMS to LUFS offset ~= -0.691 dB
        // LUFS = -0.691 + 10 * log10(mean_power)
        let instantLUFS: Float
        if meanPower > 1e-10 {
            instantLUFS = Float(-0.691 + 10.0 * log10(meanPower))
        } else {
            instantLUFS = -70
        }

        // True peak tracking (simplified — real TP uses 4x oversampled detection)
        let peakSample = Swift.max(levelL, levelR)
        let peakDB = peakSample > 0 ? 20 * log10(peakSample) : Float(-70)
        peakHold = Swift.max(peakHold, peakDB)
        // Slow decay for peak hold
        peakHold = Swift.max(peakDB, peakHold - 0.05)
        truePeak = peakHold

        // Momentary (400ms sliding window)
        momentaryBuffer.append(instantLUFS)
        if momentaryBuffer.count > momentaryWindow {
            momentaryBuffer.removeFirst(momentaryBuffer.count - momentaryWindow)
        }
        if !momentaryBuffer.isEmpty {
            momentaryLUFS = momentaryBuffer.reduce(Float(0), +) / Float(momentaryBuffer.count)
        }

        // Short-term (3s sliding window)
        shortTermBuffer.append(instantLUFS)
        if shortTermBuffer.count > shortTermWindow {
            shortTermBuffer.removeFirst(shortTermBuffer.count - shortTermWindow)
        }
        if !shortTermBuffer.isEmpty {
            shortTermLUFS = shortTermBuffer.reduce(Float(0), +) / Float(shortTermBuffer.count)
        }

        // Integrated (gated — only count blocks above -70 LUFS absolute gate)
        if instantLUFS > -70 {
            integratedSum += Double(instantLUFS)
            integratedCount += 1
            integratedLUFS = Float(integratedSum / Double(integratedCount))
        }

        // LRA approximation (range between 10th and 95th percentile)
        if shortTermBuffer.count > 10 {
            let sorted = shortTermBuffer.sorted()
            let lowIndex = min(Int(Double(sorted.count) * 0.1), sorted.count - 1)
            let highIndex = min(Int(Double(sorted.count) * 0.95), sorted.count - 1)
            let low = sorted[lowIndex]
            let high = sorted[highIndex]
            loudnessRange = high - low
        }
    }

    /// Reset integrated measurement
    func reset() {
        integratedSum = 0
        integratedCount = 0
        integratedLUFS = -70
        peakHold = -70
        momentaryBuffer.removeAll()
        shortTermBuffer.removeAll()
    }
}

// MARK: - LUFS Meter Compact View (for mixer master strip)

struct LUFSMeterView: View {
    let levelL: Float
    let levelR: Float

    @State private var state = LUFSMeterState()

    var body: some View {
        VStack(spacing: 3) {
            Text("LUFS")
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundColor(EchoelBrand.textTertiary)
                .tracking(1)

            // Momentary loudness bar
            lufsBar(
                label: "M",
                value: state.momentaryLUFS,
                color: lufsColor(state.momentaryLUFS)
            )

            // Short-term
            lufsBar(
                label: "S",
                value: state.shortTermLUFS,
                color: lufsColor(state.shortTermLUFS)
            )

            // Integrated
            lufsBar(
                label: "I",
                value: state.integratedLUFS,
                color: EchoelBrand.sky
            )

            // True Peak
            HStack(spacing: 2) {
                Text("TP")
                    .font(.system(size: 6, weight: .bold, design: .monospaced))
                    .foregroundColor(EchoelBrand.textTertiary)
                    .frame(width: 14, alignment: .leading)
                Text(formatLUFS(state.truePeak))
                    .font(.system(size: 7, weight: .medium, design: .monospaced))
                    .foregroundColor(state.truePeak > -1 ? EchoelBrand.coral : EchoelBrand.textSecondary)
            }
        }
        .padding(.vertical, EchoelSpacing.xs)
        .onChange(of: levelL) { _, _ in
            state.update(levelL: levelL, levelR: levelR)
        }
        .onChange(of: levelR) { _, _ in
            state.update(levelL: levelL, levelR: levelR)
        }
    }

    private func lufsBar(label: String, value: Float, color: Color) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.system(size: 6, weight: .bold, design: .monospaced))
                .foregroundColor(EchoelBrand.textTertiary)
                .frame(width: 10, alignment: .leading)

            // Mini bar meter (-60 to 0 range)
            GeometryReader { geo in
                let normalizedValue = CGFloat(Swift.max(0, Swift.min(1, (value + 60) / 60)))
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(EchoelBrand.bgDeep)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(color)
                        .frame(width: geo.size.width * normalizedValue)

                    // Target line at -14 LUFS (streaming standard)
                    let targetX = geo.size.width * CGFloat((60 - 14) / 60.0)
                    Rectangle()
                        .fill(EchoelBrand.textDisabled)
                        .frame(width: 0.5)
                        .offset(x: targetX)
                }
            }
            .frame(height: 4)

            Text(formatLUFS(value))
                .font(.system(size: 7, weight: .medium, design: .monospaced))
                .foregroundColor(EchoelBrand.textSecondary)
                .frame(width: 28, alignment: .trailing)
        }
    }

    private func formatLUFS(_ value: Float) -> String {
        if value <= -60 { return "-inf" }
        return String(format: "%.1f", value)
    }

    /// Color based on loudness target (-14 LUFS for streaming)
    private func lufsColor(_ lufs: Float) -> Color {
        if lufs > -8 { return EchoelBrand.coral }       // Too loud (clipping risk)
        if lufs > -11 { return EchoelBrand.amber }      // Hot
        if lufs > -16 { return EchoelBrand.emerald }     // Good range for streaming
        if lufs > -24 { return EchoelBrand.sky }         // Broadcast range
        return EchoelBrand.textTertiary                   // Quiet
    }
}

// MARK: - LUFS Meter Full View (standalone)

struct LUFSMeterFullView: View {
    let levelL: Float
    let levelR: Float

    @State private var state = LUFSMeterState()

    var body: some View {
        VStack(spacing: EchoelSpacing.sm) {
            HStack {
                Text("LOUDNESS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(EchoelBrand.textSecondary)
                    .tracking(2)
                Spacer()
                Button {
                    state.reset()
                } label: {
                    Text("RESET")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(EchoelBrand.coral)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: EchoelSpacing.md) {
                lufsReadout("MOMENTARY", value: state.momentaryLUFS, color: lufsColor(state.momentaryLUFS))
                lufsReadout("SHORT-TERM", value: state.shortTermLUFS, color: lufsColor(state.shortTermLUFS))
                lufsReadout("INTEGRATED", value: state.integratedLUFS, color: EchoelBrand.sky)
                lufsReadout("TRUE PEAK", value: state.truePeak, color: state.truePeak > -1 ? EchoelBrand.coral : EchoelBrand.emerald, unit: "dBTP")

                VStack(spacing: 2) {
                    Text("LRA")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundColor(EchoelBrand.textTertiary)
                    Text(String(format: "%.1f", state.loudnessRange))
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .foregroundColor(EchoelBrand.textPrimary)
                    Text("LU")
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundColor(EchoelBrand.textTertiary)
                }
            }

            // Target indicators
            HStack(spacing: EchoelSpacing.lg) {
                targetBadge("-14", label: "Streaming", isHit: abs(state.integratedLUFS - (-14)) < 1)
                targetBadge("-23", label: "Broadcast", isHit: abs(state.integratedLUFS - (-23)) < 1)
                targetBadge("-1", label: "TP Limit", isHit: state.truePeak <= -1, isWarning: state.truePeak > -1)
            }
        }
        .padding(EchoelSpacing.md)
        .modifier(GlassCard())
        .onChange(of: levelL) { _, _ in
            state.update(levelL: levelL, levelR: levelR)
        }
        .onChange(of: levelR) { _, _ in
            state.update(levelL: levelL, levelR: levelR)
        }
    }

    private func lufsReadout(_ label: String, value: Float, color: Color, unit: String = "LUFS") -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundColor(EchoelBrand.textTertiary)
            Text(value <= -60 ? "-inf" : String(format: "%.1f", value))
                .font(.system(size: 20, weight: .medium, design: .monospaced))
                .foregroundColor(color)
            Text(unit)
                .font(.system(size: 7, design: .monospaced))
                .foregroundColor(EchoelBrand.textTertiary)
        }
    }

    private func targetBadge(_ value: String, label: String, isHit: Bool, isWarning: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(isWarning ? EchoelBrand.coral : (isHit ? EchoelBrand.emerald : EchoelBrand.textTertiary))
            Text(label)
                .font(.system(size: 7, design: .monospaced))
                .foregroundColor(EchoelBrand.textTertiary)
        }
        .padding(.horizontal, EchoelSpacing.sm)
        .padding(.vertical, EchoelSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: EchoelRadius.xs)
                .fill(isWarning ? EchoelBrand.coral.opacity(0.1) : (isHit ? EchoelBrand.emerald.opacity(0.1) : Color.clear))
                .overlay(
                    RoundedRectangle(cornerRadius: EchoelRadius.xs)
                        .stroke(isWarning ? EchoelBrand.coral.opacity(0.3) : (isHit ? EchoelBrand.emerald.opacity(0.3) : EchoelBrand.border), lineWidth: 0.5)
                )
        )
    }

    private func lufsColor(_ lufs: Float) -> Color {
        if lufs > -8 { return EchoelBrand.coral }
        if lufs > -11 { return EchoelBrand.amber }
        if lufs > -16 { return EchoelBrand.emerald }
        if lufs > -24 { return EchoelBrand.sky }
        return EchoelBrand.textTertiary
    }
}
#endif
