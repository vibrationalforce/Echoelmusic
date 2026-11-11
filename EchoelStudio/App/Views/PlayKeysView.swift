import EchoelCore
import SwiftUI

/// Keys and pads on the screen, so the phone alone plays the live track the way a plugged-in
/// keyboard does. Every touch goes through the one live router (`AudioEngine.live`): the song's
/// key lock, the chosen live track and a running MIDI take apply to it unchanged. A drum track
/// shows its kit as pads; every other instrument track shows a keyboard — piano keys, or the hex
/// keyboard (`HexKeyLayout`), chosen by the header's hexagon button. In a song with a key, the keys
/// show it: a filled dot on its root, a ring on the other tones of its scale (`KeyMark`). Shown,
/// not enforced; Keys Follow Scale stays the switch that bends a key to the scale. Where on a key
/// the finger lands sets how hard it plays (`TouchVelocity`) while Touch Loudness is on.
struct PlayKeysView: View {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    /// The lowest key shown, always a C; kept on this device, never in the song.
    @AppStorage("playKeys.lowestNote") private var lowest = 48
    /// Whether the keys show under the surface; the transport's keys button switches it.
    nonisolated static let shownKey = "playKeys.shown"
    /// Piano keys or the hex keyboard; kept on this device, never in the song.
    @AppStorage("playKeys.hex") private var showsHex = false
    /// Whether the place of a touch on a key sets its loudness; off, every key plays the one
    /// loudness it always played. Kept on this device, never in the song.
    @AppStorage("playKeys.touchLoudness") private var touchLoudness = true

    private static let lowestC = 0
    private static let highestC = 96
    @ScaledMetric(relativeTo: .body) private var keyHeight: CGFloat = 132
    /// A phone on its side has little height: the keys shrink there so the surface above keeps
    /// room for its tracks.
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        let track = engine.liveTrackID(in: store.project).flatMap(store.project.track)
        VStack(spacing: Theme.Space.s) {
            header(track)
            if let track {
                if track.instrument.device == .drums {
                    DrumPads(router: engine.live, compact: isCompact)
                } else if showsHex {
                    HexKeyboard(router: engine.live, lowest: clampedLowest,
                                minimumCell: isCompact ? 44 : 48,
                                context: store.project.context, placesLoudness: touchLoudness)
                        .frame(height: isCompact ? Swift.min(keyHeight, 100) : Swift.min(keyHeight * 1.3, 220))
                } else {
                    Keyboard(router: engine.live, lowest: clampedLowest, context: store.project.context,
                             placesLoudness: touchLoudness)
                        .frame(height: isCompact ? Swift.min(keyHeight, 84) : Swift.min(keyHeight, 180))
                }
            } else {
                Text("Add an instrument track to play it here.")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: Theme.Size.touch)
            }
        }
        .padding(.horizontal, Theme.Space.m)
        .padding(.vertical, isCompact ? Theme.Space.xs : Theme.Space.s)
        .background(Theme.Color.surface)
        // A dense strip like the transport: the keys grow with the text size, up to a limit.
        .dynamicTypeSize(...Theme.Accessibility.denseStripLimit)
    }

    private var isCompact: Bool { verticalSizeClass == .compact }

    private var clampedLowest: Int {
        Swift.min(Swift.max(lowest - lowest % 12, Self.lowestC), Self.highestC)
    }

    private func header(_ track: Track?) -> some View {
        HStack(spacing: Theme.Space.s) {
            Text(track.map { "Plays \($0.name)" } ?? "No instrument track")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textSecondary)
                .lineLimit(1)
            Spacer(minLength: Theme.Space.s)
            if let track, track.instrument.device != .drums {
                Button { touchLoudness.toggle() } label: { Image(systemName: "hand.tap") }
                    .buttonStyle(ToolButtonStyle(isActive: touchLoudness))
                    .accessibilityLabel("Touch Loudness")
                    .accessibilityValue(touchLoudness ? "On" : "Off")
                    .accessibilityHint("On, a key plays softer near its top and harder near its foot. Off, every key plays one loudness.")
                Button { showsHex.toggle() } label: { Image(systemName: "hexagon") }
                    .buttonStyle(ToolButtonStyle(isActive: showsHex))
                    .accessibilityLabel("Hex Keyboard")
                    .accessibilityValue(showsHex ? "On" : "Off")
                    .accessibilityHint("Switches between piano keys and a hex keyboard of thirds and fifths.")
                // Each octave button says where the keys start, so a press is heard to land
                // (W18, m19): VoiceOver reads the new value of the button it pressed.
                Button { lowest = clampedLowest - 12 } label: { Image(systemName: "minus") }
                    .buttonStyle(ToolButtonStyle())
                    .disabled(clampedLowest <= Self.lowestC)
                    .accessibilityLabel("Octave Down")
                    .accessibilityValue("Lowest key \(Keyboard.name(of: clampedLowest))")
                Text(Keyboard.name(of: clampedLowest))
                    .font(Theme.Font.value)
                    .foregroundStyle(Theme.Color.text)
                    .frame(minWidth: Theme.Size.touch)
                    .accessibilityLabel("Lowest Key")
                    .accessibilityValue(Keyboard.name(of: clampedLowest))
                Button { lowest = clampedLowest + 12 } label: { Image(systemName: "plus") }
                    .buttonStyle(ToolButtonStyle())
                    .disabled(clampedLowest >= Self.highestC)
                    .accessibilityLabel("Octave Up")
                    .accessibilityValue("Lowest key \(Keyboard.name(of: clampedLowest))")
            }
        }
    }
}

/// White keys side by side and the black keys over them, as many as the width holds at about
/// 48 points each, from a C upward.
private struct Keyboard: View {
    let router: LiveRouter
    let lowest: Int
    /// The song's key, for the marks on the keys.
    let context: MusicalContext
    /// Whether the place of a touch on a key sets its loudness.
    let placesLoudness: Bool

    private static let whiteClasses: Set<Int> = [0, 2, 4, 5, 7, 9, 11]
    /// White keys followed by a black one: C, D, F, G, A.
    private static let blackFollows: Set<Int> = [0, 2, 5, 7, 9]
    private static let names = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]

    static func name(of note: Int) -> String {
        names[((note % 12) + 12) % 12] + String(note / 12 - 1)
    }

    var body: some View {
        GeometryReader { geometry in
            // About 48 pt a white key, so a black key (0.7 of it) stays a finger wide.
            let count = Swift.max(7, Swift.min(22, Int(geometry.size.width / 48)))
            let whites = Self.whiteNotes(from: lowest, count: count)
            let width = geometry.size.width / CGFloat(Swift.max(whites.count, 1))
            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    ForEach(whites, id: \.self) { note in
                        PlayKey(router: router, note: note, style: .white,
                                label: note % 12 == 0 ? Self.name(of: note) : nil, mark: context.keyMark(of: note),
                                placesLoudness: placesLoudness)
                            .frame(width: width)
                    }
                }
                ForEach(Array(whites.enumerated()), id: \.element) { index, note in
                    if Self.blackFollows.contains(note % 12), index < whites.count - 1, note + 1 <= 127 {
                        PlayKey(router: router, note: note + 1, style: .black, label: nil,
                                mark: context.keyMark(of: note + 1), placesLoudness: placesLoudness)
                            .frame(width: width * 0.7, height: geometry.size.height * 0.6)
                            .offset(x: width * CGFloat(index + 1) - width * 0.35)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Keyboard")
        .accessibilityAddTraits(.allowsDirectInteraction)
    }

    private static func whiteNotes(from lowest: Int, count: Int) -> [Int] {
        var notes: [Int] = []
        var note = lowest
        while notes.count < count, note <= 127 {
            if whiteClasses.contains(note % 12) { notes.append(note) }
            note += 1
        }
        return notes
    }
}

/// The hex keyboard: rows of hexagons from the lowest C, a major third to the right, a minor
/// third up-left, a fifth up-right (`HexKeyLayout`), as many cells about `minimumCell` wide as
/// the space holds. Each cell is a `PlayKey`, so it plays exactly as a piano key does.
private struct HexKeyboard: View {
    let router: LiveRouter
    let lowest: Int
    let minimumCell: CGFloat
    /// The song's key and its A4: a cell wears its pitch's light at that A4, as the Field and the
    /// lamp do, and the key's mark.
    let context: MusicalContext
    /// Whether the place of a touch on a cell sets its loudness.
    let placesLoudness: Bool

    var body: some View {
        GeometryReader { geometry in
            let fit = HexKeyLayout.fitting(width: Double(geometry.size.width), height: Double(geometry.size.height),
                                           minimumCell: Double(minimumCell))
            let board = HexKeyLayout(columns: fit.columns, rows: fit.rows, lowest: lowest)
            let cell = geometry.size.width / CGFloat(Swift.max(board.width, 1))
            let boardHeight = CGFloat(board.height) * cell
            let top = Swift.max(0, geometry.size.height - boardHeight)
            ZStack(alignment: .topLeading) {
                ForEach(board.cells) { key in
                    PlayKey(router: router, note: key.pitch,
                            style: .hex(Theme.Color.pitchFill(key.pitch, concertPitch: context.concertPitch)),
                            label: Self.label(of: key.pitch), mark: context.keyMark(of: key.pitch),
                            placesLoudness: placesLoudness)
                        .frame(width: cell, height: cell * CGFloat(HexKeyLayout.heightPerWidth))
                        .position(x: CGFloat(key.x) * cell, y: top + boardHeight - CGFloat(key.y) * cell)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Hex Keyboard")
        .accessibilityAddTraits(.allowsDirectInteraction)
    }

    /// The note's name on its cell; the C's also carry their octave, as on the piano keys.
    private static func label(of pitch: Int) -> String {
        let name = NoteEditing.name(of: pitch)
        return pitch % 12 == 0 ? name : String(name.prefix { !$0.isNumber && $0 != "-" })
    }
}

/// A pointy-top hexagon filling its rectangle's width.
private struct Hexagon: Shape {
    func path(in rect: CGRect) -> Path {
        let inset = rect.insetBy(dx: 1, dy: 1)
        let quarter = inset.height / 4
        var path = Path()
        path.move(to: CGPoint(x: inset.midX, y: inset.minY))
        path.addLine(to: CGPoint(x: inset.maxX, y: inset.minY + quarter))
        path.addLine(to: CGPoint(x: inset.maxX, y: inset.maxY - quarter))
        path.addLine(to: CGPoint(x: inset.midX, y: inset.maxY))
        path.addLine(to: CGPoint(x: inset.minX, y: inset.maxY - quarter))
        path.addLine(to: CGPoint(x: inset.minX, y: inset.minY + quarter))
        path.closeSubpath()
        return path
    }
}

/// The kit as two rows of four pads, kick at the bottom left as on a drum machine.
private struct DrumPads: View {
    let router: LiveRouter
    let compact: Bool
    @ScaledMetric(relativeTo: .body) private var padHeight: CGFloat = 60

    private var rows: [[DrumLane]] {
        let bottomUp = Array(DrumLane.standardKit.reversed())
        let half = bottomUp.count / 2
        return [Array(bottomUp[half...]), Array(bottomUp[..<half])]
    }

    var body: some View {
        VStack(spacing: Theme.Space.s) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: Theme.Space.s) {
                    ForEach(row) { lane in
                        PlayKey(router: router, note: lane.pitch, style: .pad, label: lane.name)
                            .frame(maxWidth: .infinity, minHeight: compact ? Theme.Size.touch : Swift.min(padHeight, 88))
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Drum Pads")
        .accessibilityAddTraits(.allowsDirectInteraction)
    }
}

/// One key or pad. The first contact plays the note and lifting the finger ends it; a touch the
/// system cancels (a notification pulled down, a call) ends it too, because the gesture state
/// resets, so no note is left hanging. The struck pitch is kept, so the release ends what the
/// press started even when the octave changed under the finger. The screen plays on MIDI
/// channel 16, so a key held here and the same key held on a keyboard on channel 1 are two
/// keys, not one struck twice (`LiveKeys` tells keys apart by channel; the instrument does not
/// hear it). A key or a hex cell can play softer near its top and harder near its foot
/// (`TouchVelocity`); each has its whole range, so a short black key plays as loud as a white one.
private struct PlayKey: View {
    enum Style: Equatable { case white, black, pad, hex(Color) }

    let router: LiveRouter
    let note: Int
    let style: Style
    let label: String?
    /// The song's key on this key; a pad wears none.
    var mark = KeyMark.unmarked
    /// Whether the place of a touch along the key sets how hard it plays. A pad never does: it is
    /// a target, not a lever, and plays one loudness wherever it is hit.
    var placesLoudness = false

    @GestureState private var touching = false
    @State private var struck: UInt8?

    private static let noteOn: UInt8 = 0x9F
    private static let noteOff: UInt8 = 0x8F

    var body: some View {
        // The key's own length, so a touch knows how far down the key it landed. The face fills
        // the space as the bare shape did.
        GeometryReader { geometry in
            face(length: geometry.size.height)
        }
    }

    private func face(length: CGFloat) -> some View {
        shape
            .fill(fill)
            .overlay(shape.stroke(Theme.Color.border, lineWidth: 1))
            .overlay(alignment: labelCentred ? .center : .bottom) {
                // On a piano key the mark sits over the name, at the foot of the key; on a hex
                // cell under it.
                VStack(spacing: 2) {
                    if !labelCentred { markDot }
                    if let label {
                        Text(label)
                            .font(Theme.Font.caption)
                            .foregroundStyle(labelColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    if labelCentred { markDot }
                }
                .padding(.bottom, labelCentred ? 0 : Theme.Space.xs)
            }
            // A hexagon is touched only inside its outline: the rows' frames overlap.
            .contentShape(shape)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($touching) { _, state, _ in state = true }
                    .onChanged { value in press(loudness(at: value.startLocation.y, of: length)) }
                    .onEnded { _ in release() }
            )
            // The safety net for a touch the system cancels: no `onEnded` comes, the state resets.
            .onChange(of: touching) { _, isDown in
                if !isDown { release() }
            }
            .onDisappear { release() }
            .accessibilityLabel(spokenName)
            .accessibilityValue(spokenMark)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { strike() }
    }

    private var shape: AnyShape {
        switch style {
        case .pad: return AnyShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
        case .hex: return AnyShape(Hexagon())
        case .white, .black: return AnyShape(RoundedRectangle(cornerRadius: Theme.Radius.small))
        }
    }

    private var labelCentred: Bool {
        switch style {
        case .pad, .hex: return true
        case .white, .black: return false
        }
    }

    /// The key's place in the song's key: a filled dot for the root, a ring for another tone of
    /// the scale — told apart by shape, not by colour.
    @ViewBuilder private var markDot: some View {
        switch mark {
        case .root:
            Circle().fill(markColor).frame(width: 7, height: 7)
        case .scaleTone:
            Circle().stroke(markColor, lineWidth: 1.5).frame(width: 6, height: 6)
        case .unmarked:
            EmptyView()
        }
    }

    private var markColor: Color {
        if struck != nil { return Theme.Color.onAccent }
        switch style {
        case .white: return Theme.Color.keyLabel
        case .hex: return Theme.Color.text
        case .black, .pad: return Theme.Color.textSecondary
        }
    }

    private var spokenMark: String {
        switch mark {
        case .root: return "Root of the key"
        case .scaleTone: return "In the scale"
        case .unmarked: return ""
        }
    }

    private var labelColor: Color {
        switch style {
        case .white: return Theme.Color.keyLabel
        case .hex: return struck != nil ? Theme.Color.onAccent : Theme.Color.text
        case .black, .pad: return Theme.Color.textSecondary
        }
    }

    /// A key is said by its full name with its octave; a pad by its drum.
    private var spokenName: String {
        switch style {
        case .pad: return label ?? Keyboard.name(of: note)
        case .white, .black, .hex: return Keyboard.name(of: note)
        }
    }

    private var fill: Color {
        if struck != nil { return Theme.Color.accent }
        switch style {
        case .white: return Theme.Color.keyWhite
        case .black: return Theme.Color.keyBlack
        case .pad: return Theme.Color.surfaceRaised
        case .hex(let tint): return tint
        }
    }

    /// How hard a touch `offset` points down a key `length` points long plays.
    private func loudness(at offset: CGFloat, of length: CGFloat) -> UInt8 {
        guard placesLoudness else { return TouchVelocity.unplaced }
        return TouchVelocity.velocity(offset: Double(offset), length: Double(length))
    }

    private func press(_ velocity: UInt8) {
        guard struck == nil, (0...127).contains(note) else { return }
        let pitch = UInt8(note)
        struck = pitch
        router.receive(status: Self.noteOn, pitch, velocity)
    }

    private func release() {
        guard let pitch = struck else { return }
        struck = nil
        router.receive(status: Self.noteOff, pitch, 0)
    }

    /// VoiceOver's activate: a short note, since there is no finger to lift — and no place on the
    /// key, so it plays the one loudness.
    private func strike() {
        press(TouchVelocity.unplaced)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            release()
        }
    }
}
