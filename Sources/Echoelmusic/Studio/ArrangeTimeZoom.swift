//
//  ArrangeTimeZoom.swift
//  Echoelmusic — DAW shell S9a (founder 2026-10-02, inbox E18 „Zeit zoomen")
//
//  Two fingers spread the song's TIME. The arrangement's lanes, its bar ruler and its playhead
//  sit inside ONE horizontal scroll view whose content is the visible width times the zoom, so
//  the three can never drift apart — they share one width by construction, not by arithmetic.
//  The track names stand still to the left (`ArrangeCanvasView` keeps them out of this view);
//  at zoom 1 the whole song fits and nothing scrolls, past it one finger pans along the song.
//
//  ⭐ ONE GESTURE, ONE MEANING. Until S9a the two-finger pinch sized the TEXT, from `StudioZoom`
//  on `SurfaceHost` — the ancestor of this canvas — so a time pinch here would have resized the
//  text under it. The text size now has three buttons in Save & Export (`TextSizeRow`), its one
//  writer; this pinch zooms time and nothing else.
//
//  ⭐ THE FINGER-RATE STATE LIVES HERE, IN ITS OWN LEAF. `pinch` is `@GestureState`, so it
//  resets itself when the gesture ends or a scroll view cancels it, and only this view's width
//  churns while the fingers move; `zoom` changes once, on release. Nothing here reads a store,
//  a position or the selection — the canvas file keeps its one `@GestureState` (the part drag),
//  which `TheArrangeCanvasMovesAPartByDraggingTests` pins.
//
//  ACCESSIBILITY: VoiceOver's zoom action (two-finger double-tap-and-hold, or the rotor's zoom)
//  steps the same zoom by a factor of two each way, so the time axis is never pinch-only. The
//  zoom is a view of the song, not an edit: nothing is written, and it is not part of Undo.
//
//  DEVICE PROBE, open: the pinch spreads the bars under the fingers' centre, one finger then
//  pans along the song while the names stay put, a part's hold-and-slide still moves it by whole
//  bars at every zoom, and the vertical scroll of the plate still works with the canvas zoomed.
//

import SwiftUI

extension ArrangeCanvas {

    /// The time zoom's range: 1 shows the whole song in the visible width, 8 shows an eighth of
    /// it — a bar of a 64-bar song is then as wide as an eighth of the screen.
    nonisolated static let zoomRange: ClosedRange<CGFloat> = 1...8

    /// The zoom after a pinch of `factor`, kept inside `zoomRange`. A pinch that reports nothing
    /// usable (NaN, infinity, zero or less) leaves the zoom where it was, clamped.
    nonisolated static func zoomed(_ zoom: CGFloat, by factor: CGFloat) -> CGFloat {
        let current = zoom.clamped(to: zoomRange)
        guard factor.isFinite, factor > 0 else { return current }
        return (current * factor).clamped(to: zoomRange)
    }
}

/// The song's time axis at a zoom the person chooses with two fingers. See the file header.
struct ArrangeTimeZoom<Content: View>: View {

    private let content: Content

    /// The zoom at rest: 1 = the whole song fits the width.
    @State private var zoom: CGFloat = 1
    /// The live factor of a pinch in progress; resets itself on release or cancel.
    @GestureState private var pinch: CGFloat = 1

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        let shown = ArrangeCanvas.zoomed(zoom, by: pinch)
        ScrollView(.horizontal) {
            content
                .containerRelativeFrame(.horizontal) { width, _ in width * shown }
        }
        .scrollIndicators(shown > 1 ? .visible : .hidden)
        .scrollDisabled(shown <= 1)
        // The scroll view takes its content's height, never a height it is offered: the plate
        // around the canvas scrolls vertically and must not see a greedy row.
        .fixedSize(horizontal: false, vertical: true)
        .simultaneousGesture(
            MagnifyGesture()
                .updating($pinch) { value, state, _ in state = value.magnification }
                .onEnded { value in zoom = ArrangeCanvas.zoomed(zoom, by: value.magnification) }
        )
        .accessibilityZoomAction { action in
            zoom = ArrangeCanvas.zoomed(zoom, by: action.direction == .zoomIn ? 2 : 0.5)
        }
    }
}
