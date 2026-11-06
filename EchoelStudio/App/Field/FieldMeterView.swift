import EchoelCore
import EchoelDSP
import SwiftUI

/// The Field as a meter (`FieldMeter`): the master's spectrum, its triggered waveform, or its stereo
/// phase (a goniometer and the correlation as a number and a bar), in place
/// of the picture — one view at a time, so while a meter shows no GPU picture runs. A leaf by
/// construction (Law 6): its own `TimelineView` reads the engine's ear in this body and nowhere
/// above; the views around it hand down nothing live.
///
/// Thin lines on the ground, never filled areas, so no reading can flash the picture; the readings
/// follow the sound with a peak meter's ballistics (`MeterBallistics`). Under Reduce Motion the
/// meter redraws half as often.
struct FieldMeterView: View {
    let meter: FieldMeter
    let reduceMotion: Bool
    @Environment(AudioEngine.self) private var engine
    @State private var listener = FieldMeterListener()

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1.0 / 15 : 1.0 / 30)) { context in
            let reading = listener.reading(from: engine, at: context.date, easing: reduceMotion)
            VStack(spacing: Theme.Space.xs) {
                Canvas { canvas, size in
                    switch meter {
                    case .scope: FieldMeterView.drawScope(reading.trace, in: &canvas, size: size)
                    case .phase: FieldMeterView.drawPhase(reading.phase, in: &canvas, size: size)
                    default: FieldMeterView.drawSpectrum(reading.bands, in: &canvas, size: size)
                    }
                }
                // Below the goniometer, never over it; a dense strip, so its text stops growing
                // where it would no longer fit a small Field window.
                if meter == .phase {
                    PhaseCorrelationBar(correlation: reading.correlation)
                        .dynamicTypeSize(...Theme.Accessibility.denseStripLimit)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Self.accessibilityTitle(meter))
            .accessibilityValue(meter == .phase ? PhaseCorrelationBar.spoken(reading.correlation) : "")
        }
        .background(Theme.Color.background)
        .onAppear { listener.listen(to: engine) }
        .onDisappear { listener.stop() }
    }

    private static func accessibilityTitle(_ meter: FieldMeter) -> String {
        switch meter {
        case .scope: "Oscilloscope of the master output"
        case .phase: "Stereo phase of the master output"
        default: "Spectrum of the master output"
        }
    }

    /// The goniometer: mid up, side across (left on the left), centred in the canvas. The frame is
    /// the diamond every sample pair within full scale stays inside; the mono axis runs up, the
    /// left and right channels' axes are its upper diagonals, marked L and R. The trace is dots,
    /// not chords between them, so it never sweeps a large area on and off.
    private static func drawPhase(_ points: [Float], in canvas: inout GraphicsContext, size: CGSize) {
        guard points.count >= 2 else { return }
        let inset: CGFloat = 12
        let half = (Swift.min(size.width, size.height) - 2 * inset) / 2
        guard half > 0 else { return }
        let centre = CGPoint(x: size.width / 2, y: size.height / 2)
        func place(_ side: CGFloat, _ mid: CGFloat) -> CGPoint {
            CGPoint(x: centre.x + half * side, y: centre.y - half * mid)
        }
        var frame = Path()
        frame.move(to: place(0, 1))
        frame.addLine(to: place(1, 0))
        frame.addLine(to: place(0, -1))
        frame.addLine(to: place(-1, 0))
        frame.closeSubpath()
        frame.move(to: place(0, -1))
        frame.addLine(to: place(0, 1))
        frame.move(to: centre)
        frame.addLine(to: place(-0.5, 0.5))
        frame.move(to: centre)
        frame.addLine(to: place(0.5, 0.5))
        canvas.stroke(frame, with: .color(Theme.Color.border), lineWidth: 1)
        if half > 30 {
            canvas.draw(Text("L").font(Theme.Font.caption).foregroundStyle(Theme.Color.textSecondary),
                        at: place(-0.62, 0.62))
            canvas.draw(Text("R").font(Theme.Font.caption).foregroundStyle(Theme.Color.textSecondary),
                        at: place(0.62, 0.62))
        }
        var dots = Path()
        for pair in 0..<(points.count / 2) {
            let point = place(CGFloat(points[2 * pair]), CGFloat(points[2 * pair + 1]))
            dots.addRect(CGRect(x: point.x - 0.75, y: point.y - 0.75, width: 1.5, height: 1.5))
        }
        canvas.fill(dots, with: .color(Theme.Color.accent))
    }

    private static func drawSpectrum(_ bands: [Double], in canvas: inout GraphicsContext, size: CGSize) {
        guard bands.count > 1 else { return }
        let inset: CGFloat = 12
        let width = size.width - 2 * inset, height = size.height - 2 * inset
        guard width > 0, height > 0 else { return }
        // A grid line every 12 dB, the 0 dB line at the top.
        var grid = Path()
        let steps = Int(SpectrumAnalyzer.meterRangeDecibels / 12)
        for step in 0...steps {
            let y = inset + height * CGFloat(step) / CGFloat(steps)
            grid.move(to: CGPoint(x: inset, y: y))
            grid.addLine(to: CGPoint(x: inset + width, y: y))
        }
        canvas.stroke(grid, with: .color(Theme.Color.border), lineWidth: 1)
        var line = Path()
        for (index, level) in bands.enumerated() {
            let x = inset + width * CGFloat(index) / CGFloat(bands.count - 1)
            let y = inset + height * CGFloat(1 - Swift.min(Swift.max(level, 0), 1))
            if index == 0 { line.move(to: CGPoint(x: x, y: y)) } else { line.addLine(to: CGPoint(x: x, y: y)) }
        }
        canvas.stroke(line, with: .color(Theme.Color.accent), lineWidth: 1.5)
    }

    private static func drawScope(_ trace: [Float], in canvas: inout GraphicsContext, size: CGSize) {
        guard trace.count > 1 else { return }
        let inset: CGFloat = 12
        let width = size.width - 2 * inset, height = size.height - 2 * inset
        guard width > 0, height > 0 else { return }
        var axis = Path()
        axis.move(to: CGPoint(x: inset, y: inset + height / 2))
        axis.addLine(to: CGPoint(x: inset + width, y: inset + height / 2))
        canvas.stroke(axis, with: .color(Theme.Color.border), lineWidth: 1)
        var line = Path()
        for (index, sample) in trace.enumerated() {
            let x = inset + width * CGFloat(index) / CGFloat(trace.count - 1)
            let value = CGFloat(Swift.min(Swift.max(sample, -1), 1))
            let y = inset + height / 2 * (1 - value)
            if index == 0 { line.move(to: CGPoint(x: x, y: y)) } else { line.addLine(to: CGPoint(x: x, y: y)) }
        }
        canvas.stroke(line, with: .color(Theme.Color.accent), lineWidth: 1.5)
    }
}

/// The meter's hold on the engine's ear and its ballistics. A plain class the view owns: it changes
/// every frame, and nothing observes it.
@MainActor
final class FieldMeterListener {
    private weak var engine: AudioEngine?
    private var bands: [Double] = []
    private var correlation: Float?
    private var phase: [Float] = []
    private var last: Date?

    func listen(to engine: AudioEngine) {
        guard self.engine !== engine else { return }
        stop()
        self.engine = engine
        engine.listenForSpectrum(true, by: ObjectIdentifier(self))
    }

    func stop() {
        engine?.listenForSpectrum(false, by: ObjectIdentifier(self))
        engine = nil
        bands = []
        correlation = nil
        phase = []
        last = nil
    }

    /// The newest reading, the bands eased by the meter's ballistics, the correlation eased over
    /// about a third of a second (a studio correlation meter's pace); the trace as it was captured.
    /// The goniometer as captured, or — with `easing` (Reduce Motion) — halfway from the last one
    /// each frame, so the figure drifts instead of jumping.
    func reading(from engine: AudioEngine, at now: Date, easing: Bool = false) -> FieldSpectrum.MeterReading {
        var fresh = engine.fieldSpectrum.meterReading()
        let seconds = last.map { Swift.min(Swift.max(now.timeIntervalSince($0), 0), 0.1) } ?? 0
        last = now
        if bands.count != fresh.bands.count {
            bands = fresh.bands
        } else {
            for index in bands.indices {
                bands[index] = MeterBallistics.follow(bands[index], fresh.bands[index], after: seconds)
            }
        }
        fresh.bands = bands
        if easing, phase.count == fresh.phase.count {
            for index in phase.indices { phase[index] += (fresh.phase[index] - phase[index]) * 0.5 }
            fresh.phase = phase
        } else {
            phase = fresh.phase
        }
        if let target = fresh.correlation {
            let eased = correlation.map { $0 + (target - $0) * Float(Swift.min(1, seconds / 0.3)) } ?? target
            correlation = eased
            fresh.correlation = eased
        } else {
            correlation = nil
        }
        return fresh
    }
}

/// The correlation under the goniometer: the number first, legible, and a thin bar from −1 to +1
/// with its mark. "—" while a side is silent.
struct PhaseCorrelationBar: View {
    let correlation: Float?

    /// Two decimals, a true minus sign, and 0 without a sign, so the reading does not flicker
    /// between +0.00 and −0.00 around zero.
    static func text(_ correlation: Float?) -> String {
        guard let correlation else { return "—" }
        let rounded = (correlation * 100).rounded() / 100
        if rounded == 0 { return "0.00" }
        let digits = String(format: "%.2f", abs(rounded))
        return (rounded < 0 ? "\u{2212}" : "+") + digits
    }

    /// What VoiceOver says for the reading.
    static func spoken(_ correlation: Float?) -> String {
        guard let correlation else { return "No signal" }
        let rounded = (correlation * 100).rounded() / 100
        let digits = String(format: "%.2f", abs(rounded))
        if rounded == 0 { return "Correlation 0" }
        return "Correlation " + (rounded < 0 ? "minus " : "plus ") + digits
    }

    var body: some View {
        VStack(spacing: Theme.Space.xxs) {
            Text(Self.text(correlation))
                .font(Theme.Font.value)
                .monospacedDigit()
                .foregroundStyle(Theme.Color.text)
            GeometryReader { geometry in
                let width = geometry.size.width
                ZStack(alignment: .leading) {
                    Rectangle().fill(Theme.Color.border).frame(height: 1)
                    Rectangle().fill(Theme.Color.border).frame(width: 1, height: 8).offset(x: width / 2)
                    if let correlation {
                        Rectangle().fill(Theme.Color.accent).frame(width: 2, height: 10)
                            .offset(x: width * CGFloat((correlation + 1) / 2) - 1)
                    }
                }
                .frame(height: 10)
            }
            .frame(height: 10)
            HStack {
                Text("\u{2212}1"); Spacer(); Text("0"); Spacer(); Text("+1")
            }
            .font(Theme.Font.caption)
            .foregroundStyle(Theme.Color.textSecondary)
        }
        .padding(.horizontal, Theme.Space.l)
        .padding(.bottom, Theme.Space.xs)
    }
}
