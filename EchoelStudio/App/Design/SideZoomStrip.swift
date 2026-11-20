import EchoelCore
import SwiftUI

/// A zoom strip at the side of a timeline (Michael on 10084: "Navigation und das Zoomen besser
/// mit Slider an der Seite"): touch or drag anywhere on it to set the zoom, the top most zoomed
/// in. Arrange's bars take the same travel for every doubling (`ArrangeZoom.position`); the piano
/// roll's few levels share the strip evenly. Double-tap returns to the standard zoom. With
/// VoiceOver it is one adjustable element: swipe up or down zooms in or out by one step. Drawn
/// with a border and a plain thumb — no pill, no glow.
struct SideZoomStrip: View {
    /// Where the zoom sits, 0 (most zoomed out) … 1 (most zoomed in).
    let position: Double
    let spoken: String
    let hint: String
    /// Sets the zoom at a strip position, 0 … 1.
    let setPosition: (Double) -> Void
    /// One step in (true) or out (false).
    let step: (Bool) -> Void
    let reset: () -> Void

    private static let width: CGFloat = 32
    private static let thumbHeight: CGFloat = 6

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            let shown = position.isFinite ? CGFloat(Swift.min(Swift.max(position, 0), 1)) : 0
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: Theme.Radius.small)
                    .fill(Theme.Color.surface.opacity(0.92))
                RoundedRectangle(cornerRadius: Theme.Radius.small)
                    .stroke(Theme.Color.border, lineWidth: 1)
                VStack {
                    Image(systemName: "plus.magnifyingglass")
                    Spacer(minLength: 0)
                    Image(systemName: "minus.magnifyingglass")
                }
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textTertiary)
                .padding(.vertical, Theme.Space.xs)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.Color.text)
                    .frame(width: Self.width - 10, height: Self.thumbHeight)
                    .offset(y: -shown * Swift.max(0, height - Self.thumbHeight))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        guard height > 0 else { return }
                        setPosition(Double(1 - drag.location.y / height))
                    }
            )
        }
        .frame(width: Self.width)
        .onTapGesture(count: 2) { reset() }
        .accessibilityElement()
        .accessibilityLabel("Zoom")
        .accessibilityValue(spoken)
        .accessibilityHint(hint)
        .accessibilityAdjustableAction { direction in
            step(direction == .increment)
        }
    }
}

extension SideZoomStrip {
    /// Arrange's strip: the width of the bars.
    init(zoom: Binding<Double>) {
        self.init(position: ArrangeZoom.position(zoom.wrappedValue),
                  spoken: ArrangeZoom.spoken(zoom.wrappedValue),
                  hint: "Swipe up to widen the bars, down to narrow them.",
                  setPosition: { zoom.wrappedValue = ArrangeZoom.value(atPosition: $0) },
                  step: { zoomIn in
                      zoom.wrappedValue = zoomIn ? ArrangeZoom.zoomedIn(zoom.wrappedValue)
                          : ArrangeZoom.zoomedOut(zoom.wrappedValue)
                  },
                  reset: { zoom.wrappedValue = ArrangeZoom.base })
    }

    /// A strip over a few fixed levels, spread evenly from the first (bottom) to the last (top).
    init(levels: [Double], index: Int, standard: Double, spoken: String, hint: String,
         set: @escaping (Double) -> Void) {
        let last = levels.count - 1
        self.init(position: last > 0 ? Double(index) / Double(last) : 0,
                  spoken: spoken, hint: hint,
                  setPosition: { position in
                      guard last >= 0, position.isFinite else { return }
                      let chosen = Int((Swift.min(Swift.max(position, 0), 1) * Double(last)).rounded())
                      set(levels[Swift.min(Swift.max(chosen, 0), last)])
                  },
                  step: { zoomIn in
                      guard last >= 0 else { return }
                      set(levels[Swift.min(Swift.max(index + (zoomIn ? 1 : -1), 0), last)])
                  },
                  reset: { set(standard) })
    }
}
