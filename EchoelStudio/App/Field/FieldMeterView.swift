import EchoelCore
import EchoelDSP
import SwiftUI

/// The Field as a meter (`FieldMeter`): the master's spectrum, or its triggered waveform, in place
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
                default: FieldMeterView.drawSpectrum(reading.bands, in: &canvas, size: size)
                }
            }
        }
        .background(Theme.Color.background)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(meter == .scope ? "Oscilloscope of the master output" : "Spectrum of the master output")
        .onAppear { listener.listen(to: engine) }
        .onDisappear { listener.stop() }
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
        last = nil
    }

    /// The newest reading, the bands eased by the meter's ballistics; the trace as it was captured.
    func reading(from engine: AudioEngine, at now: Date) -> (bands: [Double], trace: [Float]) {
        let fresh = engine.fieldSpectrum.meterReading()
        let seconds = last.map { Swift.min(Swift.max(now.timeIntervalSince($0), 0), 0.1) } ?? 0
        last = now
        if bands.count != fresh.bands.count {
            bands = fresh.bands
        } else {
            for index in bands.indices {
                bands[index] = MeterBallistics.follow(bands[index], fresh.bands[index], after: seconds)
            }
        }
        return (bands, fresh.trace)
    }
}
