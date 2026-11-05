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
            let reading = listener.reading(from: engine, at: context.date)
            Canvas { canvas, size in
                switch meter {
                case .scope: FieldMeterView.drawScope(reading.trace, in: &canvas, size: size)
                case .phase: FieldMeterView.drawPhase(reading.phase, in: &canvas, size: size)
                default: FieldMeterView.drawSpectrum(reading.bands, in: &canvas, size: size)
                }
            }
            .overlay(alignment: .bottom) {
                if meter == .phase { PhaseCorrelationBar(correlation: reading.correlation) }
            }
        }
        .background(Theme.Color.background)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.accessibilityTitle(meter))
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

    /// The goniometer: mid up, side across, in a square, with the mono axis and the two hard-panned
    /// diagonals as the grid. Thin lines only.
    private static func drawPhase(_ points: [Float], in canvas: inout GraphicsContext, size: CGSize) {
        guard points.count >= 4 else { return }
        let inset: CGFloat = 12
        let side = Swift.min(size.width, size.height - 40) - 2 * inset
        guard side > 0 else { return }
        let centre = CGPoint(x: size.width / 2, y: inset + side / 2)
        let half = side / 2
        var grid = Path()
        grid.move(to: CGPoint(x: centre.x, y: centre.y - half))
        grid.addLine(to: CGPoint(x: centre.x, y: centre.y + half))
        grid.move(to: CGPoint(x: centre.x - half, y: centre.y - half))
        grid.addLine(to: CGPoint(x: centre.x + half, y: centre.y + half))
        grid.move(to: CGPoint(x: centre.x + half, y: centre.y - half))
        grid.addLine(to: CGPoint(x: centre.x - half, y: centre.y + half))
        canvas.stroke(grid, with: .color(Theme.Color.border), lineWidth: 1)
        var line = Path()
        for pair in 0..<(points.count / 2) {
            let x = centre.x + half * CGFloat(points[2 * pair])
            let y = centre.y - half * CGFloat(points[2 * pair + 1])
            if pair == 0 { line.move(to: CGPoint(x: x, y: y)) } else { line.addLine(to: CGPoint(x: x, y: y)) }
        }
        canvas.stroke(line, with: .color(Theme.Color.accent), lineWidth: 1)
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
        last = nil
    }

    /// The newest reading, the bands eased by the meter's ballistics, the correlation eased over
    /// about a third of a second (a studio correlation meter's pace); the trace and the goniometer
    /// as they were captured.
    func reading(from engine: AudioEngine, at now: Date) -> FieldSpectrum.MeterReading {
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
private struct PhaseCorrelationBar: View {
    let correlation: Float?

    var body: some View {
        VStack(spacing: 4) {
            Text(correlation.map { String(format: "%+.2f", $0) } ?? "—")
                .font(.system(.body, design: .monospaced))
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
                Text("−1"); Spacer(); Text("0"); Spacer(); Text("+1")
            }
            .font(.caption2)
            .foregroundStyle(Theme.Color.textSecondary)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }
}
