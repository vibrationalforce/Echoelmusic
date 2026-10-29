import SwiftUI

/// The Field as a small window over the other views (wave W3): the picture stays in sight while
/// the song is arranged and mixed, and fullscreen is one tap away. The transport's Field button
/// shows and hides it; it hides itself while the Field is the chosen view, so one picture is
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
                    .accessibilityHint("The Field button in the transport shows it again.")
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
            Button(action: expand) { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                .buttonStyle(ToolButtonStyle())
                .accessibilityLabel("Full Screen")
                .padding(Theme.Space.m)
        }
    }
}

/// The Field filling the screen, under the sensor housing and the home indicator; one button leads
/// back. Layered over the studio by `StudioView`, never presented: no modal chain grows for it.
struct FieldFullscreen: View {
    let close: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            FieldView().ignoresSafeArea()
            Button(action: close) { Image(systemName: "arrow.down.right.and.arrow.up.left") }
                .buttonStyle(ToolButtonStyle())
                .accessibilityLabel("Leave Full Screen")
                .padding(Theme.Space.m)
        }
    }
}
