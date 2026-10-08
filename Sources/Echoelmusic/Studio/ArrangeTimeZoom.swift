//
//  ArrangeTimeZoom.swift
//  Echoelmusic — DAW shell S9a (founder 2026-10-02, inbox E16 „Zeit zoomen")
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
//  ⭐ THE BARS SPREAD UNDER THE FINGERS (S9a review MED-1). A wider content alone grows to the
//  right of the left edge, so the bar between the fingers would run away from them. The scroll
//  position follows the pinch: the song position under the fingers' starting point stays under
//  it, through the pure `ArrangeCanvas.anchoredOffset`. Back at zoom 1 that offset is 0 by the
//  same rule, so no shifted view can stay behind (MED-2) — and a scroll view whose content fits
//  does not scroll (`.scrollBounceBehavior(.basedOnSize)`), so nothing needs to be disabled.
//
//  ⭐ ONE FINGER IS ENOUGH (MED-6, WCAG 2.5.1). „Zoom out" and „Zoom in" sit under the lanes, 44 pt,
//  word plus symbol, disabled at the two ends; each steps the zoom by two around the middle of
//  what is in view. The pinch is a shortcut, never the only way. `accessibilityZoomAction` steps
//  the same way for an assistive technology that offers a zoom action on this view — whether
//  VoiceOver offers it on a scroll container is a DEVICE PROBE, which is why the buttons exist.
//
//  ⭐ THE FINGER-RATE STATE LIVES HERE, IN ITS OWN LEAF. `pinch` is `@GestureState`, so it
//  resets itself when the gesture ends or a scroll view cancels it, and only this view churns
//  while the fingers move; `zoom` changes once, on release. The scroll offset arrives at scroll
//  rate and is written into `viewport`, a plain reference that SwiftUI does not observe — the
//  offset itself rebuilds nothing (whether the scroll position binding is rewritten once when a
//  pan begins is SwiftUI's business and a device probe, not a per-point cost). Nothing here reads a store, a position in the song or the selection; the
//  canvas file keeps its one `@GestureState` (the part drag), which
//  `TheArrangeCanvasMovesAPartByDraggingTests` pins. The zoom is a view of the song, not an
//  edit: nothing is written, and it is not part of Undo.
//
//  KNOWN LIMITS, stated rather than hidden: a part's hold-and-slide never scrolls the view, so
//  at a zoom past 1 a part moves only as far as the visible bars — pan, then slide again, or use
//  the part bar's step buttons. Two fingers that land on a part may also start its hold; the
//  drag ends when the pinch takes over. During a pinch every lane redraws its note sketch per
//  frame, as it does for any width change.
//
//  DEVICE PROBE, open: the bars spread under the fingers; one finger pans along the song while
//  the names stay put; the two buttons step the zoom; a part's hold-and-slide moves it on the
//  grid the zoom can show (bars, then beats, then steps — GMMW AE-11); the plate's vertical
//  scroll still works with the canvas zoomed.
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

    /// The scroll offset that keeps the song position under `anchor` (points from the visible
    /// left edge) in place when the zoom goes from `oldZoom` to `newZoom`. The content is
    /// `width × zoom` wide, so a point at content x maps to x × new / old; the offset is that
    /// minus the anchor, kept inside what the new content can scroll (0 … width × (new − 1)).
    /// Unusable inputs fall back safely: no width → 0, a NaN anchor or offset → the left edge.
    nonisolated static func anchoredOffset(_ offset: CGFloat, anchor: CGFloat,
                                           from oldZoom: CGFloat, to newZoom: CGFloat,
                                           width: CGFloat) -> CGFloat {
        guard width.isFinite, width > 0 else { return 0 }
        let old = oldZoom.clamped(to: zoomRange)
        let new = newZoom.clamped(to: zoomRange)
        let start = offset.clamped(to: 0...(width * (old - 1)))
        let point = anchor.clamped(to: 0...width)
        return ((start + point) * new / old - point).clamped(to: 0...(width * (new - 1)))
    }
}

/// The song's time axis at a zoom the person chooses with two fingers or two buttons. See the
/// file header.
struct ArrangeTimeZoom<Content: View>: View {

    /// What the scroll view last reported, plus where the current pinch started. A reference
    /// SwiftUI does not observe: written at scroll rate, read only by the gesture and the buttons.
    private final class Viewport {
        var offset: CGFloat = 0
        var width: CGFloat = 0
        /// The offset and zoom when the current pinch began; nil between pinches.
        var pinchStart: (offset: CGFloat, zoom: CGFloat)?
    }

    private let content: Content

    /// The zoom at rest: 1 = the whole song fits the width.
    @State private var zoom: CGFloat = 1
    /// The live factor of a pinch in progress; resets itself on release or cancel.
    @GestureState private var pinch: CGFloat = 1
    @State private var position = ScrollPosition(x: 0)
    @State private var viewport = Viewport()

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        let shown = ArrangeCanvas.zoomed(zoom, by: pinch)
        VStack(alignment: .trailing, spacing: 6) {
            ScrollView(.horizontal) {
                content
                    .containerRelativeFrame(.horizontal) { width, _ in width * shown }
            }
            .scrollPosition($position)
            .scrollIndicators(shown > 1 ? .visible : .hidden)
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            // Reduced to the two numbers the zoom needs (offset as x, visible width as width), so
            // the action fires only when one of them changes.
            .onScrollGeometryChange(for: CGRect.self) { geo in
                CGRect(x: geo.contentOffset.x, y: 0, width: geo.containerSize.width, height: 0)
            } action: { _, now in
                viewport.offset = now.minX
                viewport.width = now.width
            }
            // The scroll view takes its content's height, never a height it is offered: the plate
            // around the canvas scrolls vertically and must not see a greedy row.
            .fixedSize(horizontal: false, vertical: true)
            .simultaneousGesture(
                MagnifyGesture()
                    .updating($pinch) { value, state, _ in state = value.magnification }
                    .onChanged { value in follow(value.magnification, at: value.startAnchor) }
                    .onEnded { value in
                        follow(value.magnification, at: value.startAnchor)
                        zoom = ArrangeCanvas.zoomed(zoom, by: value.magnification)
                        viewport.pinchStart = nil
                    }
            )
            .onChange(of: pinch) { _, now in
                // A cancelled pinch never reaches `onEnded`; its reset to 1 ends it here.
                if now == 1 { viewport.pinchStart = nil }
            }
            .accessibilityZoomAction { action in
                step(by: action.direction == .zoomIn ? 2 : 0.5)
            }
            HStack(spacing: 8) {
                zoomButton("Zoom out", systemImage: "minus.magnifyingglass",
                           hint: "Shows more of the song at once.",
                           enabled: zoom > ArrangeCanvas.zoomRange.lowerBound) { step(by: 0.5) }
                zoomButton("Zoom in", systemImage: "plus.magnifyingglass",
                           hint: "Widens the bars around the middle of the view.",
                           enabled: zoom < ArrangeCanvas.zoomRange.upperBound) { step(by: 2) }
            }
        }
    }

    /// Keeps the song position under the pinch's starting point where it is. `anchor` is that
    /// point as a fraction of the scroll view, which is the visible width.
    private func follow(_ magnification: CGFloat, at anchor: UnitPoint) {
        let start = viewport.pinchStart ?? (offset: viewport.offset, zoom: zoom)
        viewport.pinchStart = start
        let target = ArrangeCanvas.zoomed(start.zoom, by: magnification)
        position.scrollTo(x: ArrangeCanvas.anchoredOffset(start.offset, anchor: anchor.x * viewport.width,
                                                          from: start.zoom, to: target,
                                                          width: viewport.width))
    }

    /// One button press or one assistive zoom action: the zoom times `factor`, around the
    /// middle of what is in view.
    private func step(by factor: CGFloat) {
        let target = ArrangeCanvas.zoomed(zoom, by: factor)
        guard target != zoom else { return }
        let offset = ArrangeCanvas.anchoredOffset(viewport.offset, anchor: viewport.width / 2,
                                                  from: zoom, to: target, width: viewport.width)
        zoom = target
        position.scrollTo(x: offset)
    }

    private func zoomButton(_ word: LocalizedStringKey, systemImage: String, hint: LocalizedStringKey,
                            enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(word, systemImage: systemImage)
                .font(EchoelTheme.font(13, .semibold))
                .foregroundStyle(enabled ? EchoelTheme.text : EchoelTheme.dim)
                .padding(.horizontal, 10)
                .frame(minWidth: 44, minHeight: 44)
                .background(RoundedRectangle(cornerRadius: EchoelTheme.radius).fill(EchoelTheme.fill))
                .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius)
                    .strokeBorder(EchoelTheme.borderStrong, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityHint(hint)
    }
}
