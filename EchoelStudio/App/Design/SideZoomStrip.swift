import EchoelCore
import SwiftUI

/// A zoom strip at the side of a timeline (Michael on 10084: "Navigation und das Zoomen besser
/// mit Slider an der Seite"): touch or drag anywhere on it to set how wide the bars are, the top
/// widest; every doubling takes the same travel (`ArrangeZoom.position`). Double-tap returns to
/// the standard width. With VoiceOver it is one adjustable element: swipe up or down zooms in or
/// out by one step. Drawn with a border and a plain thumb — no pill, no glow.
struct SideZoomStrip: View {
    @Binding var zoom: Double

    private static let width: CGFloat = 32
    private static let thumbHeight: CGFloat = 6

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            let position = CGFloat(ArrangeZoom.position(zoom))
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
                    .offset(y: -position * Swift.max(0, height - Self.thumbHeight))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        guard height > 0 else { return }
                        zoom = ArrangeZoom.value(atPosition: Double(1 - drag.location.y / height))
                    }
            )
        }
        .frame(width: Self.width)
        .onTapGesture(count: 2) { zoom = ArrangeZoom.base }
        .accessibilityElement()
        .accessibilityLabel("Zoom")
        .accessibilityValue(ArrangeZoom.spoken(zoom))
        .accessibilityHint("Swipe up to widen the bars, down to narrow them.")
        .accessibilityAdjustableAction { direction in
            zoom = direction == .increment ? ArrangeZoom.zoomedIn(zoom) : ArrangeZoom.zoomedOut(zoom)
        }
    }
}
