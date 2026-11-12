import SwiftUI

// The top bar's parts (2026-11-12). The bar of build 10074 drew every control as its own
// outlined tile: seven heavy boxes with uneven gaps and two alignments, which read as clutter. Here a boundary goes
// around a GROUP of controls, never around each one: the deck (Play, Record, Loop), the display
// (position, tempo, Tap), and on iPad the switches. The header's Undo, Redo and More are bare
// glyphs in the text colour, as in the system's navigation bar — the glyph is the control's
// boundary (14.6:1), so they need no outline. Fill appears only for a state: the off-white tile
// for on or chosen, the record red for what is written now; green is a glyph, never a fill.
//
// Everywhere else the app keeps `ToolButtonStyle`.

/// The numeral style one bar uses for both of its readouts.
enum BarNumerals {
    case regular
    case large

    var font: SwiftUI.Font {
        switch self {
        case .regular: Theme.Font.value
        case .large: Theme.Font.valueLarge
        }
    }
}

/// A row of cells inside one outline, with a hairline between neighbours — the build of the
/// app's segmented control (`EchoelSegments`). The cells take the group's full height.
struct BarGroup<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        HStack(spacing: Theme.Space.hairline) {
            content
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(Theme.Color.borderStrong)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.medium)
                .strokeBorder(Theme.Color.borderStrong, lineWidth: 1)
        )
    }
}

/// A key inside a `BarGroup`: a 44 pt touch cell on the raised ground. Lit, it shows a tile inset
/// 4 pt in the cell (radius 4, concentric with the group's 8), so two lit neighbours stay two
/// tiles and never merge into one slab. Unlit, a signal colours the glyph only.
struct BarCellStyle: ButtonStyle {
    /// What an unlit key's glyph says.
    enum Signal {
        /// The text colour.
        case plain
        /// Sounding now: the play green.
        case running
        /// Records when pressed: the record red, so Record is red before it records.
        case record
        /// Needs the musician: Restart Audio.
        case attention
    }

    /// How wide the cell is.
    enum Width {
        /// The 44 pt touch square, wider only around a word.
        case touch
        /// At least this wide.
        case key(CGFloat)
        /// Shares the row with its neighbours (the three-row bar).
        case stretch
    }

    var isActive = false
    var fill: ToolButtonStyle.Fill = .chosen
    var signal: Signal = .plain
    var width: Width = .touch
    /// A word ("Tap", "MIDI", "Write") keeps 8 pt at each side; a glyph sits in the square.
    var padsLabel = false

    func makeBody(configuration: Configuration) -> some View {
        BarCellFace(configuration: configuration, style: self)
    }

    var minWidth: CGFloat {
        switch width {
        case .touch, .stretch: Theme.Size.touch
        case .key(let points): Swift.max(points, Theme.Size.touch)
        }
    }

    var stretches: Bool {
        if case .stretch = width { return true }
        return false
    }
}

/// The cell's look, in a view of its own so it can read whether the button is enabled. Press and
/// disabled dim the label and the lit tile only: the ground stays opaque, so the group's hairlines
/// never show through a dimmed cell.
private struct BarCellFace: View {
    let configuration: ButtonStyleConfiguration
    let style: BarCellStyle
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .font(Theme.Font.body)
            .foregroundStyle(BarLook.label(isActive: style.isActive, signal: style.signal))
            .lineLimit(1)
            .padding(.horizontal, style.padsLabel ? Theme.Space.s : 0)
            .frame(minWidth: style.minWidth, maxWidth: style.stretches ? .infinity : nil,
                   minHeight: Theme.Size.touch, maxHeight: .infinity)
            .background {
                if style.isActive {
                    RoundedRectangle(cornerRadius: Theme.Radius.small)
                        .fill(BarLook.fill(style.fill))
                        .padding(Theme.Space.xs)
                }
            }
            .opacity(isEnabled ? (configuration.isPressed ? Theme.Motion.pressedOpacity : 1) : 0.4)
            .background(Theme.Color.surfaceRaised)
            .contentShape(Rectangle())
            .animation(Theme.Motion.quick, value: configuration.isPressed)
            // The bar stops growing at the second accessibility size; past it a long press shows
            // the key large, as the system's bars do (W18, m20).
            .accessibilityShowsLargeContentViewer()
    }
}

/// Undo, Redo and More in the header: a bare glyph in a 44 pt square, no ground and no outline
/// (with the system's Button Shapes on, an outline inset 4 pt).
/// Lit (More while MIDI Learn or Write Automation is on), it shows the off-white or red tile
/// inset 4 pt, radius 8.
struct BarQuietStyle: ButtonStyle {
    var isActive = false
    var fill: ToolButtonStyle.Fill = .chosen

    func makeBody(configuration: Configuration) -> some View {
        BarQuietFace(configuration: configuration, isActive: isActive, fill: fill)
    }
}

private struct BarQuietFace: View {
    let configuration: ButtonStyleConfiguration
    let isActive: Bool
    let fill: ToolButtonStyle.Fill
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityShowButtonShapes) private var showsShapes

    var body: some View {
        configuration.label
            .font(Theme.Font.body)
            .foregroundStyle(BarLook.label(isActive: isActive, signal: .plain))
            .frame(minWidth: Theme.Size.touch, minHeight: Theme.Size.touch)
            .background {
                if isActive {
                    RoundedRectangle(cornerRadius: Theme.Radius.medium)
                        .fill(BarLook.fill(fill))
                        .padding(Theme.Space.xs)
                }
            }
            // With Button Shapes on (Accessibility › Display & Text Size), the bare glyph gets the
            // control's outline, as the system's own bar buttons get a shape there.
            .overlay {
                if showsShapes && !isActive {
                    RoundedRectangle(cornerRadius: Theme.Radius.medium)
                        .strokeBorder(Theme.Color.borderStrong, lineWidth: 1)
                        .padding(Theme.Space.xs)
                }
            }
            .contentShape(Rectangle())
            .opacity(isEnabled ? (configuration.isPressed ? Theme.Motion.pressedOpacity : 1) : 0.4)
            .animation(Theme.Motion.quick, value: configuration.isPressed)
            .accessibilityShowsLargeContentViewer()
    }
}

/// The bar's one colour rule, shared by its two styles.
private enum BarLook {
    static func fill(_ fill: ToolButtonStyle.Fill) -> Color {
        switch fill {
        case .chosen: Theme.Color.text
        case .recording: Theme.Color.record
        }
    }

    /// Black on a lit tile; otherwise the signal's colour, or the text colour.
    static func label(isActive: Bool, signal: BarCellStyle.Signal) -> Color {
        if isActive { return Theme.Color.onAccent }
        switch signal {
        case .plain: return Theme.Color.text
        case .running: return Theme.Color.play
        case .record: return Theme.Color.record
        case .attention: return Theme.Color.warning
        }
    }
}
