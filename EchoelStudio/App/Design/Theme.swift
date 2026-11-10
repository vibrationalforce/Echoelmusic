import EchoelCore
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
/// Black on `text` (a chosen button's label) is 15.9:1, black on `record` (a recording one's) 5.5:1.
enum Theme {
    enum Color {
        // The values live in `EchoelBrand` (`Plugins/Shared/EchoelBrand.swift`), which the AUv3
        // extension compiles too, so the plugin window and the Studio share ONE source.
        static let background = EchoelBrand.Color.background
        /// Panels and rows (#0e0e12).
        static let surface = EchoelBrand.Color.surface
        /// A control's own fill: the earlier app's 6 % neutral, composited onto `surface` so it
        /// reads the same wherever it sits.
        static let surfaceRaised = EchoelBrand.Color.surfaceRaised
        /// A hairline that separates; it does not announce a control.
        static let border = EchoelBrand.Color.border
        /// The boundary of something operable — a parameter field, a key of the number pad.
        static let borderStrong = EchoelBrand.Color.borderStrong
        static let text = EchoelBrand.Color.text
        static let textSecondary = EchoelBrand.Color.textSecondary
        static let textTertiary = EchoelBrand.Color.textTertiary
        /// Bio-green: the signal colour, for what sounds, is measured or is held under a finger —
        /// a label, a line, a meter, a switch that is on. Never the area behind a label: a chosen
        /// or main control is the off-white tile (`ToolButtonStyle`), as on the earlier instrument.
        static let accent = EchoelBrand.Color.accent
        /// The label on a `text` or `record` fill, and the knob of a switch that is on.
        static let onAccent = EchoelBrand.Color.onAccent
        /// Running, healthy, in range — the same green as the accent, so the app has one.
        static let play = accent
        static let record = EchoelBrand.Color.record
        static let warning = EchoelBrand.Color.warning
        /// The keys of a keyboard (play keys, the piano roll's side).
        static let keyWhite = EchoelBrand.Color.keyWhite
        static let keyBlack = EchoelBrand.Color.keyBlack
        static let keyLabel = EchoelBrand.Color.keyLabel

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
            "Blue", "Indigo", "Violet", "Magenta", "Pink", "Gray",
        ]

        /// A hex key's fill: its pitch's light at the song's concert pitch (`ToneLight.keyFill`),
        /// the colour the Field and the lamp show for that pitch, muted and dark enough that
        /// `text` on it clears AA (`ToneLightTests` measure all 128 notes). Every cell also
        /// carries its name: colour is never the only cue.
        static func pitchFill(_ pitch: Int, concertPitch: Double) -> SwiftUI.Color {
            linear(ToneLight.keyFill(forToneHz: ToneLight.hertz(ofPitch: pitch, concertPitch: concertPitch)))
        }

        /// A linear colour from Core (`ToneLight.RGB`) on screen, gamma-encoded.
        static func linear(_ light: ToneLight.RGB, opacity: Double = 1) -> SwiftUI.Color {
            let shown = light.encoded
            return SwiftUI.Color(red: shown.red, green: shown.green, blue: shown.blue, opacity: opacity)
        }

        /// A tone's light drawn as data (the Canvas Field): `saturation` of the way out of its
        /// grey and its brightest channel at `brightness`, as an HSV brightness reads.
        static func tone(_ light: ToneLight.RGB, saturation: Double, brightness: Double) -> SwiftUI.Color {
            let shown = light.encoded
            let peak = Swift.max(shown.peak, 1e-6)
            let keep = Swift.min(Swift.max(saturation.isFinite ? saturation : 0, 0), 1)
            let level = Swift.min(Swift.max(brightness.isFinite ? brightness : 0, 0), 1)
            func channel(_ value: Double) -> Double { (peak - (peak - value) * keep) / peak * level }
            return SwiftUI.Color(red: channel(shown.red), green: channel(shown.green), blue: channel(shown.blue))
        }

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
        /// The gap that draws a hairline between rows and strips laid on the border colour.
        static let hairline = EchoelBrand.Space.hairline
        /// The breath between stacked lines of one status strip, or the cells of a dense grid.
        static let xxs = EchoelBrand.Space.xxs
        static let xs = EchoelBrand.Space.xs
        static let s = EchoelBrand.Space.s
        static let m = EchoelBrand.Space.m
        static let l = EchoelBrand.Space.l
        static let xl = EchoelBrand.Space.xl
    }

    enum Radius {
        static let small = EchoelBrand.Radius.small
        static let medium = EchoelBrand.Radius.medium
        static let large = EchoelBrand.Radius.large
    }

    enum Size {
        /// Minimum touch target (Apple HIG).
        static let touch = EchoelBrand.touch
        static let transportHeight: CGFloat = 56
        static let trackRowHeight: CGFloat = 56
        static let rulerHeight: CGFloat = 24
    }

    enum Font {
        // The brand face, Atkinson Hyperlegible, and every size: `EchoelBrand.Font`, shared with
        // the AUv3 extension (which carries the two font files too). Text styles, never fixed point
        // sizes; dense surfaces cap the size they grow to, they never opt out.
        static let title = EchoelBrand.Font.title
        static let body = EchoelBrand.Font.body
        static let label = EchoelBrand.Font.label
        static let caption = EchoelBrand.Font.caption
        /// Numbers that change (tempo, position, levels) use the face's tabular figures, so they
        /// never jitter.
        static let value = EchoelBrand.Font.value
        static let valueLarge = EchoelBrand.Font.valueLarge
        /// The number a pad is typing: the largest numeral on screen.
        static let display = EchoelBrand.Font.display

        typealias Face = EchoelBrand.Font.Face

        static func brand(_ face: Face, _ size: CGFloat, relativeTo style: SwiftUI.Font.TextStyle) -> SwiftUI.Font {
            EchoelBrand.Font.brand(face, size, relativeTo: style)
        }
    }

    enum Motion {
        /// A press, a highlight: 120 ms.
        static var quick: Animation { EchoelBrand.Motion.quick }
        /// A state that changes what a control shows: 180 ms. Motion is opacity and colour only,
        /// never scale or position.
        static var standard: Animation { EchoelBrand.Motion.standard }
        /// How far a pressed control dims.
        static let pressedOpacity = EchoelBrand.Motion.pressedOpacity
    }

    enum Accessibility {
        /// The largest text size a dense control strip grows to. Beyond it the strip would no
        /// longer fit a phone; lists and editors keep scaling all the way.
        static let denseStripLimit = DynamicTypeSize.accessibility2

        /// Says `announcement` to VoiceOver wherever its focus is — the app's one way to speak
        /// unasked; what is said and when is `Announcement`'s (EchoelCore). Urgent goes at high
        /// priority, which nothing cuts short; queued at low, after what VoiceOver is saying.
        @MainActor static func announce(_ announcement: Announcement) {
            var spoken = AttributedString(announcement.text)
            switch announcement.priority {
            case .urgent: spoken.accessibilitySpeechAnnouncementPriority = .high
            case .normal: break
            case .queued: spoken.accessibilitySpeechAnnouncementPriority = .low
            }
            AccessibilityNotification.Announcement(spoken).post()
        }
    }
}

/// The one button style for toolbar and transport controls: solid fill, 8 pt radius, a hairline
/// boundary, opacity feedback on press (no scaling, no glow).
///
/// A lit button is monochrome, the earlier instrument's rule (`EchoelTheme`): chosen, switched on
/// or the page's one main action, it is the off-white tile with a black label. The only other fill
/// is the record red, a colour with a meaning of its own. The fill is a named case, never a colour
/// handed in, so no call site can lay the bio-green behind a label again. Green is a signal, and a
/// signal is drawn as the label: `isRunning`, for what sounds now, on the plain tile.
struct ToolButtonStyle: ButtonStyle {
    /// What the fill of a lit button says.
    enum Fill {
        /// Chosen, switched on, or the main action: off-white under a black label.
        case chosen
        /// Written into the song now — a take, an automation pass: the record red.
        case recording
    }

    var isActive = false
    var fill: Fill = .chosen
    /// Sounding now (the song plays, a clip plays): the label wears the green, the tile stays plain.
    var isRunning = false

    func makeBody(configuration: Configuration) -> some View {
        ToolButtonFace(configuration: configuration, isActive: isActive, fill: fill, isRunning: isRunning)
    }
}

/// The style's look, in a view of its own so it can read whether the button is enabled: a
/// disabled Record, Undo or Play is dimmed instead of looking tappable (audit 2026-10-23).
private struct ToolButtonFace: View {
    let configuration: ButtonStyleConfiguration
    let isActive: Bool
    let fill: ToolButtonStyle.Fill
    let isRunning: Bool
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .font(Theme.Font.label)
            .foregroundStyle(labelColor)
            .frame(minWidth: Theme.Size.touch, minHeight: Theme.Size.touch)
            .padding(.horizontal, Theme.Space.s)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.medium)
                    .fill(isActive ? fillColor : Theme.Color.surfaceRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.medium)
                    .strokeBorder(Theme.Color.border, lineWidth: isActive ? 0 : 1)
            )
            .opacity(isEnabled ? (configuration.isPressed ? Theme.Motion.pressedOpacity : 1) : 0.4)
            .animation(Theme.Motion.quick, value: configuration.isPressed)
            // The transport, the keys and the bar of views stop growing at the second accessibility
            // size; past it a long press shows the button large, as the system's bars do (W18, m20).
            .accessibilityShowsLargeContentViewer()
    }

    private var fillColor: Color {
        switch fill {
        case .chosen: Theme.Color.text
        case .recording: Theme.Color.record
        }
    }

    /// Black on a lit tile; the green of a signal on a plain one that sounds; else the text colour.
    private var labelColor: Color {
        if isActive { return Theme.Color.onAccent }
        return isRunning ? Theme.Color.play : Theme.Color.text
    }
}
