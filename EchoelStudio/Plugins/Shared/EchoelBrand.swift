import CoreText
import Foundation
import SwiftUI

/// The values Echoel's look is made of, in ONE file that the app and the Audio Unit extension
/// both compile (`project.yml`: the app lists it by path, the extension takes all of
/// `Plugins/Shared`), as `PluginUnlock` is shared. The app reads them through `Theme`
/// (`App/Design/Theme.swift`), the plugin window directly — so a synth in AUM, Logic or GarageBand
/// shows the same black, the same greys, the same green and the same face as the Studio, and a
/// change here changes both.
///
/// It holds values only: no view, no Core type, no engine. The extension stays as small as it was;
/// the app's controls (`ParameterField`, the number pad) keep living in `App/Design`, because they
/// write through `ProjectStore`, which a plugin in a foreign host does not have.
///
/// The measured contrast of every token is written above `Theme`.
enum EchoelBrand {
    enum Color {
        /// The one neutral every grey is a slice of (#e0e0e0, the website's `--text`).
        static let neutral = SwiftUI.Color(red: 0.878, green: 0.878, blue: 0.878)

        static let background = SwiftUI.Color.black
        /// Panels and rows (#0e0e12).
        static let surface = SwiftUI.Color(red: 0.055, green: 0.055, blue: 0.070)
        /// A control's own fill: 6 % neutral, composited onto `surface`.
        static let surfaceRaised = SwiftUI.Color(red: 0.104, green: 0.104, blue: 0.118)
        static let border = neutral.opacity(0.10)
        static let borderStrong = neutral.opacity(0.45)
        static let text = neutral
        static let textSecondary = neutral.opacity(0.65)
        static let textTertiary = neutral.opacity(0.58)
        /// Bio-green: what is active, selected or measured.
        static let accent = SwiftUI.Color(red: 0.30, green: 0.85, blue: 0.55)
        static let onAccent = SwiftUI.Color.black
        static let record = SwiftUI.Color(red: 0.90, green: 0.30, blue: 0.30)
        static let warning = SwiftUI.Color(red: 0.90, green: 0.62, blue: 0.20)
        /// A keyboard's keys, as an instrument has them: white keys the light neutral, black keys
        /// a step above the ground so they stay visible on it, and the name on a white key dark.
        static let keyWhite = neutral
        static let keyBlack = SwiftUI.Color(white: 0.12)
        static let keyLabel = SwiftUI.Color(white: 0.25)
    }

    enum Space {
        /// The gap that draws a hairline between rows laid on the border colour.
        static let hairline: CGFloat = 1
        /// The breath between stacked lines of one strip, or the cells of a dense grid.
        static let xxs: CGFloat = 2
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

    /// Minimum touch target (Apple HIG).
    static let touch: CGFloat = 44

    enum Motion {
        /// A press, a highlight: 120 ms.
        static var quick: Animation { .easeOut(duration: 0.12) }
        /// A state that changes what a control shows: 180 ms. Opacity and colour only.
        static var standard: Animation { .easeInOut(duration: 0.18) }
        static let pressedOpacity: Double = 0.6
    }

    enum Font {
        // Atkinson Hyperlegible (Braille Institute, SIL Open Font License 1.1 — the licence travels
        // in each file's own name table). Two faces ship, Regular and Bold, in the app bundle AND in
        // the extension's (both take `App/Design/Fonts`); a custom font synthesises no weight in
        // between, so every token names one. Sizes are relative to a text style, so every label
        // follows Dynamic Type; should a face fail to register, `.custom` falls back to the system
        // face at the same size.
        static let title = brand(.bold, 17, relativeTo: .headline)
        static let body = brand(.regular, 17, relativeTo: .body)
        static let label = brand(.regular, 15, relativeTo: .subheadline)
        static let caption = brand(.regular, 12, relativeTo: .caption)
        /// Numbers that change use tabular figures, so they never jitter.
        static let value = brand(.bold, 17, relativeTo: .headline).monospacedDigit()
        static let valueLarge = brand(.bold, 22, relativeTo: .title2).monospacedDigit()
        static let display = brand(.bold, 30, relativeTo: .largeTitle).monospacedDigit()

        enum Face: String, CaseIterable {
            case regular = "AtkinsonHyperlegible-Regular"
            case bold = "AtkinsonHyperlegible-Bold"
        }

        static func brand(_ face: Face, _ size: CGFloat, relativeTo style: SwiftUI.Font.TextStyle) -> SwiftUI.Font {
            _ = registered
            return .custom(face.rawValue, size: size, relativeTo: style)
        }

        /// The faces in this process's own bundle — the app's, or the extension's when a host runs
        /// the plugin — registered the first time any token is read, without an Info.plist entry.
        private static let registered: Void = {
            for face in Face.allCases {
                guard let url = Bundle.main.url(forResource: face.rawValue, withExtension: "ttf") else { continue }
                // False when the face is already registered; either way it can be drawn.
                _ = CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }()
    }
}
