//
//  NoteGridZoom.swift
//  Echoelmusic — Studio (DAW shell S9b, founder 2026-10-02: „Alles auf professionellstem Level")
//
//  The note grid's TIME zoom — the Notes page's twin of the Arrange canvas's (S9a). A sixteenth
//  is drawn at one of three widths: an overview of a long part, the grid's width since M1, and a
//  step a fingertip can hit. The grid's canvas, its playhead line and its velocity lane all take
//  the ONE width the grid computes from this level, so a note, its stem and the line can never
//  disagree about where a step is.
//
//  ⭐ A VIEW, NOT AN EDIT. The level is local to the open grid (like Lower/Higher): nothing is
//  written, nothing is saved, nothing is on Undo, and another part opens at the default.
//
//  ⭐ THE STEP IN VIEW STAYS IN VIEW. A wider column alone grows to the right of the left edge,
//  so the bar you were looking at would slide away. `anchoredOffset` keeps the song position
//  under an anchor (the middle of the view for a button, the fingers for a pinch) where it was,
//  inside what the new content can scroll.
//
//  Pure and Foundation-only, so every rule here is driven end to end by
//  `TheNoteGridZoomsItsTimeTests`.
//

import Foundation

enum NoteGridZoom {

    /// The width of one sixteenth on screen, narrow to wide. The middle one is the grid's width
    /// since M1, so a part opens exactly as it always did.
    nonisolated static let stepWidths: [Double] = [11, 22, 44]

    /// The level a grid opens at — the M1 width.
    nonisolated static let defaultLevel = 1

    /// `level` kept inside the list of widths.
    nonisolated static func clampedLevel(_ level: Int) -> Int {
        Swift.min(Swift.max(level, 0), stepWidths.count - 1)
    }

    /// The column width at `level`; a level outside the list reads as its nearest end.
    nonisolated static func stepWidth(atLevel level: Int) -> Double {
        stepWidths[clampedLevel(level)]
    }

    /// The level `delta` steps away, kept inside the list. Overflow-safe for any `delta`.
    nonisolated static func level(_ level: Int, steppedBy delta: Int) -> Int {
        let span = stepWidths.count
        return clampedLevel(clampedLevel(level) + Swift.min(Swift.max(delta, -span), span))
    }

    /// How many levels a released pinch of `magnification` moves: none inside a dead zone of
    /// about a quarter either way (so a touch that only wobbles changes nothing), otherwise the
    /// nearest whole doubling, at least one. A pinch that reports nothing usable moves nothing.
    nonisolated static func levelDelta(forPinch magnification: Double) -> Int {
        guard magnification.isFinite, magnification > 0 else { return 0 }
        let doublings = Foundation.log2(magnification)
        guard abs(doublings) >= 0.32 else { return 0 }
        let whole = Swift.max(1, Int(abs(doublings).rounded().clamped(to: 0...64)))
        return doublings > 0 ? whole : -whole
    }

    /// The scroll offset that keeps the song position under `anchor` (points from the visible
    /// left edge) in place when a column goes from `oldWidth` to `newWidth`. The content is
    /// `steps × width` wide, so a point at content x maps to x × new / old; the offset is that
    /// minus the anchor, kept inside what the new content can scroll. Unusable inputs fall back
    /// to the left edge (0), never to a NaN or a negative offset.
    nonisolated static func anchoredOffset(_ offset: Double, anchor: Double,
                                           from oldWidth: Double, to newWidth: Double,
                                           steps: Int, viewWidth: Double) -> Double {
        guard oldWidth.isFinite, oldWidth > 0, newWidth.isFinite, newWidth > 0,
              viewWidth.isFinite, viewWidth > 0, steps > 0 else { return 0 }
        let oldMax = Swift.max(0, Double(steps) * oldWidth - viewWidth)
        let newMax = Swift.max(0, Double(steps) * newWidth - viewWidth)
        let start = offset.clamped(to: 0...oldMax)
        let point = anchor.clamped(to: 0...viewWidth)
        return ((start + point) * newWidth / oldWidth - point).clamped(to: 0...newMax)
    }
}
