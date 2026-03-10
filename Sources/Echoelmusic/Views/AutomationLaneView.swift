#if canImport(SwiftUI)
import SwiftUI

// MARK: - Automation Lane View
/// Professional automation lane editor (Logic Pro / Ableton / Pro Tools style)
/// Shows below each track in the arrangement view
/// Features: breakpoint editing, curve interpolation, parameter selection, draw mode

struct AutomationLaneView: View {
    let track: Track
    let lane: TrackAutomationLane
    let pixelsPerSecond: CGFloat
    let totalDuration: TimeInterval
    let onUpdatePoint: (UUID, UUID, TimeInterval, Float) -> Void
    let onAddPoint: (UUID, UUID, TimeInterval, Float) -> Void
    let onDeletePoint: (UUID, UUID, UUID) -> Void

    @State private var hoveredPointID: UUID?

    private let laneHeight: CGFloat = 60
    private let labelWidth: CGFloat = 80

    private var paramColor: Color {
        switch lane.parameter {
        case .volume: return EchoelBrand.sky
        case .pan: return EchoelBrand.emerald
        case .filterCutoff, .filterResonance: return EchoelBrand.violet
        case .reverbMix, .delayMix, .chorusMix: return Color(red: 1, green: 0.8, blue: 0.2)
        case .compThreshold, .compRatio, .compAttack, .compRelease: return EchoelBrand.coral
        default: return EchoelBrand.textSecondary
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Parameter label
            parameterLabel
                .frame(width: labelWidth)

            // Automation curve canvas
            automationCanvas
        }
        .frame(height: laneHeight)
        .background(EchoelBrand.bgDeep.opacity(0.2))
        .overlay(alignment: .top) {
            Rectangle().fill(EchoelBrand.border).frame(height: 0.5)
        }
    }

    // MARK: - Parameter Label

    private var parameterLabel: some View {
        VStack(spacing: 2) {
            Text(lane.parameter.displayName)
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundColor(paramColor)
                .lineLimit(1)

            // Current value at center
            if let lastPoint = lane.points.last {
                Text(String(format: "%.0f%%", lastPoint.value * 100))
                    .font(.system(size: 7, weight: .medium, design: .monospaced))
                    .foregroundColor(EchoelBrand.textTertiary)
            }

            // Enable/disable
            Circle()
                .fill(lane.isEnabled ? paramColor : EchoelBrand.textTertiary.opacity(0.3))
                .frame(width: 6, height: 6)
        }
        .padding(.horizontal, EchoelSpacing.xs)
        .background(EchoelBrand.bgSurface.opacity(0.5))
        .overlay(alignment: .trailing) {
            Rectangle().fill(EchoelBrand.border).frame(width: 0.5)
        }
    }

    // MARK: - Automation Canvas

    private var automationCanvas: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height

            ZStack {
                // Reference lines (0%, 50%, 100%)
                referenceLines(width: width, height: height)

                // Automation curve
                automationCurve(width: width, height: height)

                // Breakpoints
                ForEach(lane.points) { point in
                    breakpointDot(point: point, width: width, height: height)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture()
                    .onEnded { value in
                        guard width > 0, height > 0 else { return }
                        let time = Double(value.location.x / width) * totalDuration
                        let normalizedValue = Float(1.0 - value.location.y / height)
                        let clampedValue = Swift.max(0, Swift.min(1, normalizedValue))
                        onAddPoint(track.id, lane.id, Swift.max(0, time), clampedValue)
                        HapticHelper.impact(.light)
                    }
            )
        }
    }

    private func referenceLines(width: CGFloat, height: CGFloat) -> some View {
        Canvas { context, _ in
            for level in [0.0, 0.25, 0.5, 0.75, 1.0] {
                let y = height * (1.0 - level)
                let line = Path { p in
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: width, y: y))
                }
                let isCenter = level == 0.5
                context.stroke(line, with: .color(paramColor.opacity(isCenter ? 0.15 : 0.06)),
                               lineWidth: isCenter ? 0.5 : 0.25)
            }
        }
        .allowsHitTesting(false)
    }

    private func automationCurve(width: CGFloat, height: CGFloat) -> some View {
        Canvas { context, _ in
            guard lane.points.count >= 2 else {
                // Single point or no points — draw flat line at default
                let val = lane.points.first?.value ?? lane.parameter.defaultValue
                let y = height * CGFloat(1.0 - val)
                let line = Path { p in
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: width, y: y))
                }
                context.stroke(line, with: .color(paramColor.opacity(0.4)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                return
            }

            let sortedPoints = lane.points.sorted { $0.time < $1.time }

            // Build path with interpolation
            var path = Path()
            let resolution: CGFloat = 2 // pixels per sample

            // Extend from start
            let firstX = CGFloat(sortedPoints[0].time / totalDuration) * width
            let firstY = height * CGFloat(1.0 - sortedPoints[0].value)
            path.move(to: CGPoint(x: 0, y: firstY))
            path.addLine(to: CGPoint(x: firstX, y: firstY))

            // Interpolated segments
            for i in 0..<(sortedPoints.count - 1) {
                let p0 = sortedPoints[i]
                let p1 = sortedPoints[i + 1]
                let x0 = CGFloat(p0.time / totalDuration) * width
                let x1 = CGFloat(p1.time / totalDuration) * width
                let y0 = height * CGFloat(1.0 - p0.value)
                let y1 = height * CGFloat(1.0 - p1.value)

                let segmentWidth = x1 - x0
                guard segmentWidth > 0 else { continue }

                let steps = Swift.max(1, Int(segmentWidth / resolution))
                for step in 0...steps {
                    let t = Float(step) / Float(steps)
                    let interpolated: Float
                    switch p0.curveType {
                    case .linear:
                        interpolated = p0.value + (p1.value - p0.value) * t
                    case .exponential:
                        interpolated = p0.value + (p1.value - p0.value) * (t * t)
                    case .logarithmic:
                        interpolated = p0.value + (p1.value - p0.value) * sqrt(t)
                    case .sCurve:
                        let s = t * t * (3.0 - 2.0 * t)
                        interpolated = p0.value + (p1.value - p0.value) * s
                    case .hold:
                        interpolated = step == steps ? p1.value : p0.value
                    }
                    let x = x0 + CGFloat(t) * segmentWidth
                    let y = height * CGFloat(1.0 - interpolated)
                    if step == 0 && i == 0 && firstX == x0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }

            // Extend to end
            if let lastValue = sortedPoints.last?.value {
                let lastY = height * CGFloat(1.0 - lastValue)
                path.addLine(to: CGPoint(x: width, y: lastY))
            }

            // Stroke
            context.stroke(path, with: .color(paramColor), lineWidth: 1.5)

            // Fill below curve
            var fillPath = path
            fillPath.addLine(to: CGPoint(x: width, y: height))
            fillPath.addLine(to: CGPoint(x: 0, y: height))
            fillPath.closeSubpath()
            context.fill(fillPath, with: .color(paramColor.opacity(0.06)))
        }
        .allowsHitTesting(false)
    }

    private func breakpointDot(point: TrackAutomationPoint, width: CGFloat, height: CGFloat) -> some View {
        let x = CGFloat(point.time / totalDuration) * width
        let y = height * CGFloat(1.0 - point.value)
        let isHovered = hoveredPointID == point.id

        return Circle()
            .fill(paramColor)
            .frame(width: isHovered ? 10 : 7, height: isHovered ? 10 : 7)
            .overlay(
                Circle()
                    .stroke(EchoelBrand.textPrimary, lineWidth: isHovered ? 1.5 : 0.5)
            )
            .shadow(color: paramColor.opacity(0.5), radius: isHovered ? 4 : 0)
            .position(x: x, y: y)
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { drag in
                        guard width > 0, height > 0 else { return }
                        let newTime = Swift.max(0, Double(drag.location.x / width) * totalDuration)
                        let newValue = Swift.max(0, Swift.min(1, Float(1.0 - drag.location.y / height)))
                        onUpdatePoint(track.id, lane.id, newTime, newValue)
                    }
            )
            .onTapGesture(count: 2) {
                onDeletePoint(track.id, lane.id, point.id)
                HapticHelper.impact(.medium)
            }
            .onHover { isHovered in
                hoveredPointID = isHovered ? point.id : nil
            }
    }
}

// MARK: - Automation Lane Toggle Button

/// Small button to show/hide automation lanes on a track
struct AutomationToggleButton: View {
    let isShowing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isShowing ? "line.3.crossed.swirl.circle.fill" : "line.3.crossed.swirl.circle")
                .font(.system(size: 11))
                .foregroundColor(isShowing ? Color(red: 1, green: 0.8, blue: 0.2) : EchoelBrand.textTertiary)
                .frame(width: 20, height: 20)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isShowing ? "Hide automation" : "Show automation")
    }
}

// MARK: - Add Automation Parameter Picker

struct AutomationParameterPicker: View {
    let onSelect: (AutomatedParameter) -> Void
    @Environment(\.dismiss) private var dismiss

    // Common parameters shown first
    private let commonParams: [AutomatedParameter] = [
        .volume, .pan, .filterCutoff, .filterResonance,
        .reverbMix, .delayMix, .compThreshold
    ]

    var body: some View {
        NavigationStack {
            List {
                Section("Common") {
                    ForEach(commonParams, id: \.self) { param in
                        Button {
                            onSelect(param)
                            dismiss()
                        } label: {
                            Text(param.displayName)
                                .foregroundColor(EchoelBrand.textPrimary)
                        }
                    }
                }
                Section("All Parameters") {
                    ForEach(AutomatedParameter.allCases, id: \.self) { param in
                        if !commonParams.contains(param) {
                            Button {
                                onSelect(param)
                                dismiss()
                            } label: {
                                Text(param.displayName)
                                    .foregroundColor(EchoelBrand.textPrimary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Automation")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
#endif
