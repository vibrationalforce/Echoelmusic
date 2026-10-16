// ArrangeAutomationTrace.swift
// Echoel — Arrange & Perform item 7a (founder 2026-10-16, "Automation direkt auf dem Canvas"): a
// track's automation is drawn ON its row of the arrangement canvas, at the canvas's own scale, so
// what moves the sound is seen where the parts are. Before, a curve existed only on the Track page
// (`SongAutomationEditor`), at the song's bare length — not at the canvas's.
//
// What this is and is not:
//   · DISPLAY ONLY. No gesture: the canvas file holds exactly one drag and one finger-rate state
//     (`TheArrangeCanvasMovesAPartByDraggingTests`), and the parts' own taps and holds must reach
//     them. Points are edited on the Track page through the one writer `setSongAutomation`; drawing
//     them here is item 7b.
//   · Every curve of the track is drawn, each the way playback reads it: `AutomationLane.value(atTick:)`
//     sampled across the row — so a ramp, a hold before the first point and after the last are
//     the shapes the voice follows, never a second interpolation (#416).
//   · Only per-track curves (`track.<id>.<base>`) belong to a row; global ones have no track.
//
// NEEDS-FOUNDER-VERIFY (7a): draw a Brightness curve on a synth track's Track page (Automation) →
// the same rise and fall shows as a line across that track's row on the canvas, over its parts, at
// the bars the points sit on; zoom the canvas → the line stays on those bars.

import SwiftUI

/// The pure half: which curves a row draws, and where.
enum ArrangeAutomation {

    /// One drawn point: `x` 0…1 across the row (tick / the canvas's song length), `value` 0…1.
    struct Sample: Equatable, Sendable {
        let x: Double
        let value: Double
    }

    /// The curves that move this track: per-track lanes naming it, with at least one point.
    nonisolated static func curves(for laneID: UUID, in lanes: [AutomationLane]) -> [AutomationLane] {
        lanes.filter { !$0.isEmpty && PerTrackParameterKeyPath.parse($0.parameter)?.laneID == laneID }
    }

    /// The curve at `columns` evenly spaced ticks from 0 to `songTicks`, as playback reads it.
    /// Empty for no song, fewer than two columns, or an empty curve. Values are clamped to 0…1.
    nonisolated static func samples(of lane: AutomationLane, songTicks: Int, columns: Int) -> [Sample] {
        guard songTicks > 0, columns >= 2 else { return [] }
        let last = Double(columns - 1)
        return (0..<columns).compactMap { (i: Int) -> Sample? in
            let x = Double(i) / last
            let tick = Int((x * Double(songTicks)).rounded())
            guard let v = lane.value(atTick: tick) else { return nil }
            return Sample(x: x, value: v.clamped(to: 0...1))
        }
    }

    /// One sample every few points of row width — enough for a ramp, bounded for a long piece.
    nonisolated static func columns(forWidth width: Double) -> Int {
        guard width.isFinite, width > 0 else { return 2 }
        return Int((width / 4).rounded()).clamped(to: 2...512)
    }
}

/// The track's curves as thin lines across its canvas row. Draws nothing for a track without one.
struct ArrangeAutomationTrace: View {
    let curves: [AutomationLane]
    let songTicks: Int

    var body: some View {
        if !curves.isEmpty {
            Canvas { context, size in
                let inset: CGFloat = 6
                let height = Swift.max(0, size.height - 2 * inset)
                let columns = ArrangeAutomation.columns(forWidth: Double(size.width))
                for lane in curves {
                    let samples = ArrangeAutomation.samples(of: lane, songTicks: songTicks, columns: columns)
                    guard let first = samples.first else { continue }
                    var path = Path()
                    path.move(to: CGPoint(x: first.x * size.width, y: inset + (1 - first.value) * height))
                    for s in samples.dropFirst() {
                        path.addLine(to: CGPoint(x: s.x * size.width, y: inset + (1 - s.value) * height))
                    }
                    context.stroke(path, with: .color(EchoelTheme.text.opacity(0.6)), lineWidth: 1.5)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)   // the Track page's Automation row speaks the curve
        }
    }
}
