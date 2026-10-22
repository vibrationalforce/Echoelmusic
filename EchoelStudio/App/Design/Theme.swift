import SwiftUI

/// The design system. Every colour, size and radius on screen comes from here, so the app
/// reads as one instrument. Dark, muted, high contrast for numbers; colour only where it
/// carries meaning (track identity, record, play, level).
enum Theme {
    enum Color {
        static let background = SwiftUI.Color(white: 0.07)
        static let surface = SwiftUI.Color(white: 0.11)
        static let surfaceRaised = SwiftUI.Color(white: 0.15)
        static let border = SwiftUI.Color(white: 0.22)
        static let text = SwiftUI.Color(white: 0.92)
        static let textSecondary = SwiftUI.Color(white: 0.60)
        /// 0.55 on the 0.07 background is about 5.5:1 — above WCAG AA (4.5:1) for small text.
        static let textTertiary = SwiftUI.Color(white: 0.55)
        static let accent = SwiftUI.Color(red: 0.98, green: 0.62, blue: 0.20)
        static let play = SwiftUI.Color(red: 0.36, green: 0.80, blue: 0.47)
        static let record = SwiftUI.Color(red: 0.93, green: 0.30, blue: 0.30)

        /// The 12 track colours. `Track.colorIndex` stores an index into this list.
        static let tracks: [SwiftUI.Color] = [
            SwiftUI.Color(red: 0.93, green: 0.42, blue: 0.36),
            SwiftUI.Color(red: 0.96, green: 0.62, blue: 0.29),
            SwiftUI.Color(red: 0.94, green: 0.80, blue: 0.33),
            SwiftUI.Color(red: 0.62, green: 0.82, blue: 0.36),
            SwiftUI.Color(red: 0.33, green: 0.77, blue: 0.52),
            SwiftUI.Color(red: 0.30, green: 0.76, blue: 0.76),
            SwiftUI.Color(red: 0.35, green: 0.64, blue: 0.92),
            SwiftUI.Color(red: 0.47, green: 0.50, blue: 0.95),
            SwiftUI.Color(red: 0.64, green: 0.45, blue: 0.93),
            SwiftUI.Color(red: 0.84, green: 0.43, blue: 0.86),
            SwiftUI.Color(red: 0.93, green: 0.42, blue: 0.62),
            SwiftUI.Color(red: 0.66, green: 0.66, blue: 0.68),
        ]

        /// Spoken and shown names, one per colour. Colour is never the only cue: a track is
        /// always also named, and the colour has a word for VoiceOver and colour-blind players.
        static let trackNames = [
            "Red", "Orange", "Yellow", "Lime", "Green", "Teal",
            "Blue", "Indigo", "Violet", "Magenta", "Pink", "Grey",
        ]

        static func track(_ index: Int) -> SwiftUI.Color {
            tracks[wrapped(index)]
        }

        static func trackName(_ index: Int) -> String {
            trackNames[wrapped(index)]
        }

        private static func wrapped(_ index: Int) -> Int {
            ((index % tracks.count) + tracks.count) % tracks.count
        }
    }

    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
    }

    enum Radius {
        static let small: CGFloat = 4
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
    }

    enum Size {
        /// Minimum touch target (Apple HIG).
        static let touch: CGFloat = 44
        static let transportHeight: CGFloat = 56
        static let trackRowHeight: CGFloat = 56
        static let rulerHeight: CGFloat = 24
    }

    enum Font {
        // Text styles, never fixed point sizes: every label follows the reader's Dynamic Type
        // setting. Dense surfaces (the transport) cap the size they grow to, they never opt out.
        static let title = SwiftUI.Font.headline
        static let body = SwiftUI.Font.body
        static let label = SwiftUI.Font.subheadline.weight(.medium)
        static let caption = SwiftUI.Font.caption.weight(.medium)
        /// Numbers that change (tempo, position, levels) use monospaced digits so they never jitter.
        static let value = SwiftUI.Font.headline.monospacedDigit()
        static let valueLarge = SwiftUI.Font.title2.weight(.semibold).monospacedDigit()
    }

    enum Accessibility {
        /// The largest text size a dense control strip grows to. Beyond it the strip would no
        /// longer fit a phone; lists and editors keep scaling all the way.
        static let denseStripLimit = DynamicTypeSize.accessibility2
    }
}

/// The one button style for toolbar and transport controls: solid fill, 8 pt radius,
/// opacity feedback on press (no scaling, no glow).
struct ToolButtonStyle: ButtonStyle {
    var isActive = false
    var activeColor: Color = Theme.Color.accent

    func makeBody(configuration: Configuration) -> some View {
        ToolButtonFace(configuration: configuration, isActive: isActive, activeColor: activeColor)
    }
}

/// The style's look, in a view of its own so it can read whether the button is enabled: a
/// disabled Record, Undo or Play is dimmed instead of looking tappable (audit 2026-10-23).
private struct ToolButtonFace: View {
    let configuration: ButtonStyleConfiguration
    let isActive: Bool
    let activeColor: Color
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .font(Theme.Font.label)
            .foregroundStyle(isActive ? Theme.Color.background : Theme.Color.text)
            .frame(minWidth: Theme.Size.touch, minHeight: Theme.Size.touch)
            .padding(.horizontal, Theme.Space.s)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.medium)
                    .fill(isActive ? activeColor : Theme.Color.surfaceRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.medium)
                    .stroke(Theme.Color.border, lineWidth: isActive ? 0 : 1)
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
