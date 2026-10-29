import SwiftUI

/// The design system. Every colour, size and radius on screen comes from here, so the app
/// reads as one instrument.
///
/// It carries the identity of the earlier Echoelmusic instrument (`Sources/Echoelmusic/Studio/
/// EchoelTheme.swift`, which mirrors the website's `docs/shared.css`): a black ground, muted
/// #e0e0e0 text, hairline borders, small radii and ONE bio-green accent. Colour appears only where
/// it carries meaning — the accent, record, level, a track's identity — never as decoration.
///
/// Contrast, measured with the WCAG 2.x formula on these exact components (sRGB, translucent
/// tokens composited over each ground), as text / ground — black · surface · surfaceRaised:
/// `text` 15.9 · 14.6 · 13.1, `textSecondary` 6.7 · 6.6 · 6.2, `textTertiary` 5.5 · 5.4 · 5.2,
/// `accent` 11.6 · 10.6 · 9.5, `record` 5.5 · 5.1 · 4.5, `warning` 9.3 · 8.5 · 7.6 — every text
/// token clears AA (4.5:1). `borderStrong` is 3.6:1 (a control's boundary, WCAG 1.4.11 asks 3:1);
/// `border` is 1.2:1 on purpose, a divider that must not compete with what it separates.
/// Black on `accent` (an active button's label) is 11.6:1.
enum Theme {
    enum Color {
        /// The one neutral every grey here is a slice of (#e0e0e0, the website's `--text`).
        private static let neutral = SwiftUI.Color(red: 0.878, green: 0.878, blue: 0.878)

        static let background = SwiftUI.Color.black
        /// Panels and rows (#0e0e12).
        static let surface = SwiftUI.Color(red: 0.055, green: 0.055, blue: 0.070)
        /// A control's own fill: the earlier app's 6 % neutral, composited onto `surface` so it
        /// reads the same wherever it sits.
        static let surfaceRaised = SwiftUI.Color(red: 0.104, green: 0.104, blue: 0.118)
        /// A hairline that separates; it does not announce a control.
        static let border = neutral.opacity(0.10)
        /// The boundary of something operable — a parameter field, a key of the number pad.
        static let borderStrong = neutral.opacity(0.45)
        static let text = neutral
        static let textSecondary = neutral.opacity(0.65)
        static let textTertiary = neutral.opacity(0.58)
        /// Bio-green: the signal colour, for what is active, selected or measured.
        static let accent = SwiftUI.Color(red: 0.30, green: 0.85, blue: 0.55)
        /// The label on an `accent` or `text` fill.
        static let onAccent = SwiftUI.Color.black
        /// Running, healthy, in range — the same green as the accent, so the app has one.
        static let play = accent
        static let record = SwiftUI.Color(red: 0.90, green: 0.30, blue: 0.30)
        static let warning = SwiftUI.Color(red: 0.90, green: 0.62, blue: 0.20)

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

    enum Motion {
        /// A press, a highlight: 120 ms.
        static var quick: Animation { .easeOut(duration: 0.12) }
        /// A state that changes what a control shows: 180 ms. Motion is opacity and colour only,
        /// never scale or position.
        static var standard: Animation { .easeInOut(duration: 0.18) }
        /// How far a pressed control dims.
        static let pressedOpacity: Double = 0.6
    }

    enum Accessibility {
        /// The largest text size a dense control strip grows to. Beyond it the strip would no
        /// longer fit a phone; lists and editors keep scaling all the way.
        static let denseStripLimit = DynamicTypeSize.accessibility2
    }
}

/// The one button style for toolbar and transport controls: solid fill, 8 pt radius, a hairline
/// boundary, opacity feedback on press (no scaling, no glow).
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
            .foregroundStyle(isActive ? Theme.Color.onAccent : Theme.Color.text)
            .frame(minWidth: Theme.Size.touch, minHeight: Theme.Size.touch)
            .padding(.horizontal, Theme.Space.s)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.medium)
                    .fill(isActive ? activeColor : Theme.Color.surfaceRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.medium)
                    .strokeBorder(Theme.Color.border, lineWidth: isActive ? 0 : 1)
            )
            .opacity(isEnabled ? (configuration.isPressed ? Theme.Motion.pressedOpacity : 1) : 0.4)
            .animation(Theme.Motion.quick, value: configuration.isPressed)
    }
}
