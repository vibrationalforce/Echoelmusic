#if canImport(SwiftUI)
import SwiftUI

/// Visual rhythm system with BPM-synced orbs, octave guides, and preset-matched colors.
/// Each Sound World gets its own color palette and movement pattern.
struct RhythmOrbsView: View {

    let bpm: Double
    let orbCount: Int
    let worldColor: WorldColor

    /// Color palette matched to Sound World character
    enum WorldColor {
        case nature(NatureHue)
        case space(SpaceHue)
        case texture(TextureHue)

        enum NatureHue { case underwater, jungle, waterfall, ocean, forest, rain }
        enum SpaceHue { case cave, atmosphere, midnight }
        enum TextureHue { case glass, drift, silk, ember, aurora, void_ }

        var primary: Color {
            switch self {
            case .nature(.underwater): return Color(red: 0.1, green: 0.3, blue: 0.6)
            case .nature(.jungle): return Color(red: 0.2, green: 0.6, blue: 0.15)
            case .nature(.waterfall): return Color(red: 0.3, green: 0.5, blue: 0.7)
            case .nature(.ocean): return Color(red: 0.05, green: 0.2, blue: 0.45)
            case .nature(.forest): return Color(red: 0.3, green: 0.45, blue: 0.2)
            case .nature(.rain): return Color(red: 0.4, green: 0.45, blue: 0.55)
            case .space(.cave): return Color(red: 0.5, green: 0.35, blue: 0.2)
            case .space(.atmosphere): return Color(red: 0.5, green: 0.6, blue: 0.8)
            case .space(.midnight): return Color(red: 0.2, green: 0.15, blue: 0.35)
            case .texture(.glass): return Color(red: 0.7, green: 0.8, blue: 0.9)
            case .texture(.drift): return Color(red: 0.4, green: 0.5, blue: 0.6)
            case .texture(.silk): return Color(red: 0.6, green: 0.5, blue: 0.55)
            case .texture(.ember): return Color(red: 0.7, green: 0.3, blue: 0.1)
            case .texture(.aurora): return Color(red: 0.2, green: 0.6, blue: 0.5)
            case .texture(.void_): return Color(red: 0.15, green: 0.1, blue: 0.2)
            }
        }

        var secondary: Color { primary.opacity(0.5) }

        /// Movement speed multiplier — nature is slower, textures vary
        var speedFactor: Double {
            switch self {
            case .nature(.underwater), .nature(.ocean): return 0.6
            case .nature(.jungle): return 1.2
            case .nature(.waterfall): return 1.4
            case .nature(.rain): return 1.1
            case .nature(.forest): return 0.8
            case .space(.cave): return 0.7
            case .space(.atmosphere): return 0.5
            case .space(.midnight): return 0.65
            case .texture(.glass): return 1.0
            case .texture(.drift): return 0.55
            case .texture(.silk): return 0.45
            case .texture(.ember): return 1.3
            case .texture(.aurora): return 0.5
            case .texture(.void_): return 0.3
            }
        }
    }

    init(bpm: Double = 120.0, orbCount: Int = 4, worldColor: WorldColor = .nature(.underwater)) {
        self.bpm = bpm
        self.orbCount = orbCount
        self.worldColor = worldColor
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                let effectiveBPM = bpm * worldColor.speedFactor
                let beatDuration = 60.0 / max(effectiveBPM, 20.0)

                // Draw octave guide lines (vertical, faint)
                drawOctaveGuides(context: context, size: size)

                // Draw orbs
                for i in 0..<orbCount {
                    let phaseOffset = Double(i) / Double(orbCount)
                    drawOrb(
                        context: context,
                        size: size,
                        time: now,
                        beatDuration: beatDuration,
                        phaseOffset: phaseOffset,
                        orbIndex: i
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Octave Guide Lines

    private func drawOctaveGuides(context: GraphicsContext, size: CGSize) {
        // 2 octaves across the screen = 3 guide lines (start, middle, end)
        let guides = 3
        let guideColor = worldColor.primary.opacity(0.06)

        for i in 0..<guides {
            let x = CGFloat(i) / CGFloat(guides - 1) * size.width
            let rect = CGRect(x: x - 0.25, y: 0, width: 0.5, height: size.height)
            context.fill(Path(rect), with: .color(guideColor))

            // Octave label at top
            if i > 0 && i < guides {
                let label = i == 1 ? "+1 Oct" : ""
                if !label.isEmpty {
                    var textContext = context
                    textContext.opacity = 0.08
                    let text = Text(label)
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                    textContext.draw(text, at: CGPoint(x: x, y: 12))
                }
            }
        }

        // Subtle horizontal line at playing zone center
        let centerY = size.height * 0.5
        let hRect = CGRect(x: 0, y: centerY - 0.25, width: size.width, height: 0.5)
        context.fill(Path(hRect), with: .color(worldColor.primary.opacity(0.03)))
    }

    // MARK: - Orb Drawing

    private func drawOrb(
        context: GraphicsContext,
        size: CGSize,
        time: TimeInterval,
        beatDuration: TimeInterval,
        phaseOffset: Double,
        orbIndex: Int
    ) {
        let totalPhase = time / beatDuration + phaseOffset
        let t = totalPhase.truncatingRemainder(dividingBy: 1.0)

        // X: sweep left-to-right
        let x = CGFloat(t) * size.width

        // Y: organic parabolic arc with slight wave modulation
        let bounceHeight = size.height * 0.25
        let baseY = size.height * 0.12
        let parabola = -4.0 * CGFloat(t) * (CGFloat(t) - 1.0)
        // Add subtle sine wave for organic feel
        let waveOffset = sin(CGFloat(totalPhase) * 3.0 + CGFloat(orbIndex) * 1.5) * 5.0
        let y = baseY + bounceHeight * (1.0 - parabola) + waveOffset

        // Size varies per orb and pulsates gently
        let baseDiameter: CGFloat = 6.0 + CGFloat(orbIndex % 3) * 2.0
        let breathe = 1.0 + sin(CGFloat(time) * 2.0 + CGFloat(orbIndex)) * 0.15
        let orbSize = baseDiameter * (0.8 + parabola * 0.4) * breathe

        // Opacity: organic fade
        let opacity = 0.2 + parabola * 0.5

        let color = worldColor.primary

        // Trail
        for trail in 0..<4 {
            let trailT = t - Double(trail + 1) * 0.025
            guard trailT > 0 else { continue }
            let trailX = CGFloat(trailT) * size.width
            let trailParabola = -4.0 * CGFloat(trailT) * (CGFloat(trailT) - 1.0)
            let trailWave = sin(CGFloat(totalPhase - Double(trail + 1) * 0.025) * 3.0 + CGFloat(orbIndex) * 1.5) * 5.0
            let trailY = baseY + bounceHeight * (1.0 - trailParabola) + trailWave
            let trailOpacity = opacity * Double(4 - trail) / 5.0 * 0.25
            let trailSize = orbSize * 0.5

            context.fill(
                Path(ellipseIn: CGRect(x: trailX - trailSize / 2, y: trailY - trailSize / 2, width: trailSize, height: trailSize)),
                with: .color(color.opacity(trailOpacity))
            )
        }

        // Glow
        let glowSize = orbSize * 3.0
        context.fill(
            Path(ellipseIn: CGRect(x: x - glowSize / 2, y: y - glowSize / 2, width: glowSize, height: glowSize)),
            with: .color(color.opacity(opacity * 0.1))
        )

        // Main orb
        context.fill(
            Path(ellipseIn: CGRect(x: x - orbSize / 2, y: y - orbSize / 2, width: orbSize, height: orbSize)),
            with: .color(color.opacity(opacity))
        )
    }
}
#endif
