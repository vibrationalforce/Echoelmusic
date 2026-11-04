import EchoelCore
import SwiftUI

/// The Field as a small window over the other views (wave W3): the picture stays in sight while
/// the song is arranged and mixed, and fullscreen is one tap away. The transport's Field Window
/// switch shows and hides it — under More on a phone held upright, where the transport has no room
/// for it; it hides itself while the Field is the chosen view, so one picture is
/// drawn at a time. Not a modal — it is layered over the view, and the fullscreen is too (Law 7:
/// the one `.sheet(item:)` keeps its enum).
struct FieldWindow: View {
    /// Whether the window shows over the views; kept on this device, never in the song.
    nonisolated static let shownKey = "field.window.shown"

    let expand: () -> Void
    let close: () -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        VStack(spacing: 0) {
            Button(action: expand) {
                FieldView()
                    .frame(width: width, height: width * 10 / 16)
                    // The picture takes no touches of its own: the whole card is the door.
                    .allowsHitTesting(false)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Field")
            .accessibilityHint("Opens the Field in full screen.")
            Divider().overlay(Theme.Color.border)
            HStack(spacing: 0) {
                Button(action: expand) { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                    .buttonStyle(.plain)
                    .frame(width: Theme.Size.touch, height: Theme.Size.touch)
                    .accessibilityLabel("Full Screen")
                Spacer(minLength: 0)
                Button(action: close) { Image(systemName: "xmark") }
                    .buttonStyle(.plain)
                    .frame(width: Theme.Size.touch, height: Theme.Size.touch)
                    .accessibilityLabel("Hide Field Window")
                    // On a phone held upright the switch sits under More, not in the transport (W18).
                    .accessibilityHint("Field Window in the transport, or under More on a phone held upright, shows it again.")
            }
            .font(Theme.Font.label)
            .foregroundStyle(Theme.Color.text)
            .background(Theme.Color.surface)
        }
        .frame(width: width)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.large).stroke(Theme.Color.border, lineWidth: 1))
    }

    /// A card, not a panel: wide enough to read the picture, narrow enough to leave the view under
    /// it usable. A regular width (an iPad, a phone on its side) gets a larger one.
    private var width: CGFloat { horizontalSizeClass == .regular ? 240 : 160 }
}

/// The Field as the chosen view, with its door to fullscreen in the corner.
struct FieldSurface: View {
    let expand: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            FieldView()
            HStack(spacing: Theme.Space.s) {
                FieldPatternMenu()
                Button(action: expand) { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                    .buttonStyle(ToolButtonStyle())
                    .accessibilityLabel("Full Screen")
            }
            .padding(Theme.Space.m)
            FieldBlendMix()
        }
    }
}

/// The Field filling the screen, under the sensor housing and the home indicator; one button leads
/// back. Layered over the studio by `StudioView`, never presented: no modal chain grows for it.
struct FieldFullscreen: View {
    let close: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Theme.Color.background.ignoresSafeArea()
            FieldView().ignoresSafeArea()
            HStack(spacing: Theme.Space.s) {
                FieldPatternMenu()
                Button(action: close) { Image(systemName: "arrow.down.right.and.arrow.up.left") }
                    .buttonStyle(ToolButtonStyle())
                    .accessibilityLabel("Leave Full Screen")
            }
            .padding(Theme.Space.m)
            FieldBlendMix()
        }
    }
}

/// The Field's picture: a menu of the patterns, beside the full-screen button. A named choice, so
/// a picker (never a number); kept on this device, so it changes no song and needs no command.
/// Shown only where the GPU draws the Field — the Canvas draws the rings alone.
struct FieldPatternMenu: View {
    @AppStorage(FieldPattern.storageKey) private var patternName = FieldPattern.rings.rawValue
    @AppStorage(FieldPattern.blendStorageKey) private var partnerName = ""

    var body: some View {
        #if canImport(MetalKit) && canImport(UIKit)
        if MetalField.isAvailable {
            Menu {
                Picker("Pattern", selection: $patternName) {
                    ForEach(FieldPattern.allCases, id: \.rawValue) { pattern in
                        Text(pattern.title).tag(pattern.rawValue)
                    }
                }
                // A second look over the first; its share is the Blend field on the picture.
                Picker("Blend With", selection: $partnerName) {
                    Text("None").tag("")
                    ForEach(FieldPattern.allCases, id: \.rawValue) { pattern in
                        Text(pattern.title).tag(pattern.rawValue)
                    }
                }
                .pickerStyle(.menu)
            } label: {
                Image(systemName: "square.grid.3x3")
            }
            .menuStyle(.button)
            .buttonStyle(ToolButtonStyle())
            .accessibilityLabel("Pattern")
            .accessibilityValue(FieldPattern(stored: patternName).title)
        }
        #endif
    }
}

/// How much of the blended look shows, in Echoel's value field, at the picture's lower left —
/// present only while a second look is chosen. A device setting, so no command and no song change;
/// the renderer eases the share through the flash guard (`FieldLookMotion`), so a fast drag can
/// never strobe the picture.
struct FieldBlendMix: View {
    @AppStorage(FieldPattern.storageKey) private var patternName = FieldPattern.rings.rawValue
    @AppStorage(FieldPattern.blendStorageKey) private var partnerName = ""
    @AppStorage(FieldPattern.blendMixStorageKey) private var mixPercent = FieldPattern.standardMixPercent

    var body: some View {
        #if canImport(MetalKit) && canImport(UIKit)
        if MetalField.isAvailable, let partner = FieldPattern.blend(stored: partnerName),
           partner != FieldPattern(stored: patternName) {
            VStack {
                Spacer(minLength: 0)
                HStack {
                    SettingField(title: "Blend · \(partner.title)", value: Swift.min(Swift.max(mixPercent, 0), 100),
                                 range: 0...100, unit: "%", standard: FieldPattern.standardMixPercent,
                                 spokenUnit: "percent") { mixPercent = $0 }
                        .frame(width: 140)
                    Spacer(minLength: 0)
                }
            }
            .padding(Theme.Space.m)
        }
        #endif
    }
}
