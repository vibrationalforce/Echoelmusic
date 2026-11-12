import SwiftUI

/// The Echoelmusic mark: a bold "E" over three waves of falling opacity, as the app icon and the
/// website draw it (`docs/app-icon.svg`). Drawn, not an image, so it stays crisp at any size and
/// takes the theme's text colour. The coordinates follow the SVG's 100 × 100 view box, and the
/// "E" is set in the app's own bold face at a size fixed to the box, so at large text sizes it
/// never outgrows the waves it stands on. Decorative: the control it sits in says what it does.
struct EchoelMark: View {
    var color: Color = Theme.Color.text

    var body: some View {
        Canvas { context, size in
            // The brand faces register on first use of a brand font; the "E" below names its face
            // directly, so it asks for one first.
            _ = EchoelBrand.Font.title
            let scale = Swift.min(size.width, size.height) / 100
            // Three waves at y = 60, 70 and 80 of the view box, at 0.8, 0.4 and 0.2 opacity.
            for (offset, opacity) in [(CGFloat(0), 0.8), (CGFloat(10), 0.4), (CGFloat(20), 0.2)] {
                context.stroke(Self.wave(offset, scale), with: .color(color.opacity(opacity)),
                               style: StrokeStyle(lineWidth: Swift.max(3 * scale, 1), lineCap: .round))
            }
            let face = EchoelBrand.Font.Face.bold.rawValue
            var letter = context.resolve(Text("E").font(.custom(face, fixedSize: 52 * scale)))
            letter.shading = .color(color)
            context.draw(letter, at: CGPoint(x: 50 * scale, y: 30 * scale), anchor: .center)
        }
        .accessibilityHidden(true)
    }

    /// One wave across the box from x 24 to 76, `offset` below the first.
    private static func wave(_ offset: CGFloat, _ scale: CGFloat) -> Path {
        var path = Path()
        let y = (60 + offset) * scale
        path.move(to: CGPoint(x: 24 * scale, y: y))
        path.addCurve(to: CGPoint(x: 42 * scale, y: y),
                      control1: CGPoint(x: 29 * scale, y: (54 + offset) * scale),
                      control2: CGPoint(x: 37 * scale, y: (54 + offset) * scale))
        path.addCurve(to: CGPoint(x: 58 * scale, y: y),
                      control1: CGPoint(x: 47 * scale, y: (66 + offset) * scale),
                      control2: CGPoint(x: 53 * scale, y: (66 + offset) * scale))
        path.addCurve(to: CGPoint(x: 76 * scale, y: y),
                      control1: CGPoint(x: 63 * scale, y: (54 + offset) * scale),
                      control2: CGPoint(x: 71 * scale, y: (54 + offset) * scale))
        return path
    }
}
