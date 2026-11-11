import EchoelCore
import SwiftUI

/// Keys and pads on the screen, so the phone alone plays the live track the way a plugged-in
/// keyboard does. Every touch goes through the one live router (`AudioEngine.live`): the song's
/// key lock, the chosen live track and a running MIDI take apply to it unchanged. A drum track
/// shows its kit as pads and a sampler whose file is cut into slices one pad per slice
/// (`PlaySurface`); every other instrument track shows a keyboard — piano keys, the hex keyboard
/// (`HexKeyLayout`) or the chords of the song's key (`ChordRow`), chosen in the header's menu. In a song with a key, the keys
/// show it: a filled dot on its root, a ring on the other tones of its scale (`KeyMark`). Shown,
/// not enforced; Keys Follow Scale stays the switch that bends a key to the scale. Where on a key
/// the finger lands sets how hard it plays (`TouchVelocity`) while Touch Loudness is on; both
/// switches sit in the Song menu's key section.
struct PlayKeysView: View {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    /// The lowest key shown, always a C; kept on this device, never in the song.
    @AppStorage("playKeys.lowestNote") private var lowest = 48
    /// Whether the keys show under the surface; the transport's keys button switches it.
    nonisolated static let shownKey = "playKeys.shown"
    /// Piano keys or the hex keyboard; kept on this device, never in the song.
    @AppStorage("playKeys.hex") private var showsHex = false
    /// The chords of the song's key in place of the keys; kept on this device, never in the song.
    @AppStorage("playKeys.chords") private var showsChords = false
    /// Whether the place of a touch on a key sets its loudness; off, every key plays the one
    /// loudness it always played. Kept on this device, never in the song; switched in the Song menu.
    @AppStorage(PlayKeysView.touchLoudnessKey) private var touchLoudness = true
    nonisolated static let touchLoudnessKey = "playKeys.touchLoudness"

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
                playSurface(for: track)
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

    /// What the keys strip plays on, kept as the two switches it has always been stored in.
    private enum KeysLayout: CaseIterable {
        case piano, hex, chords

        var title: String {
            switch self {
            case .piano: "Piano Keys"
            case .hex: "Hex Keyboard"
            case .chords: "Chords"
            }
        }

        var symbol: String {
            switch self {
            case .piano: "pianokeys"
            case .hex: "hexagon"
            case .chords: "rectangle.split.3x1"
            }
        }
    }

    private var layout: Binding<KeysLayout> {
        Binding(get: { showsChords ? .chords : (showsHex ? .hex : .piano) },
                set: { choice in
                    showsChords = choice == .chords
                    showsHex = choice == .hex
                })
    }

    /// Pads for an instrument whose keys pick a sound, keys for one whose keys pick a pitch.
    @ViewBuilder private func playSurface(for track: Track) -> some View {
        switch PlaySurface.surface(for: track.instrument) {
        case .drumPads:
            DrumPads(router: engine.live, compact: isCompact)
        case .slicePads(let count):
            SlicePads(router: engine.live, count: count, compact: isCompact)
        case .keys:
            if showsChords {
                ChordPads(router: engine.live, context: store.project.context, compact: isCompact)
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
        }
    }

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
            if let track, PlaySurface.surface(for: track.instrument) == .keys {
                Menu {
                    Picker("Play On", selection: layout) {
                        ForEach(KeysLayout.allCases, id: \.self) { choice in
                            Label(choice.title, systemImage: choice.symbol).tag(choice)
                        }
                    }
                } label: {
                    Image(systemName: layout.wrappedValue.symbol)
                }
                .menuStyle(.button)
                .buttonStyle(ToolButtonStyle(isActive: layout.wrappedValue != .piano))
                .accessibilityLabel("Play On")
                .accessibilityValue(layout.wrappedValue.title)
                .accessibilityHint("Piano keys, a hex keyboard of thirds and fifths, or the chords of the song's key.")
            }
            if let track, PlaySurface.surface(for: track.instrument) == .keys, !showsChords {
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
    /// How far down a white key the black keys reach, as a share of its length.
    private static let blackLength: CGFloat = 0.6
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
                                placesLoudness: placesLoudness, ownFrom: Self.blackLength)
                            .frame(width: width)
                    }
                }
                ForEach(Array(whites.enumerated()), id: \.element) { index, note in
                    if Self.blackFollows.contains(note % 12), index < whites.count - 1, note + 1 <= 127 {
                        PlayKey(router: router, note: note + 1, style: .black, label: nil,
                                mark: context.keyMark(of: note + 1), placesLoudness: placesLoudness)
                            .frame(width: width * 0.7, height: geometry.size.height * Self.blackLength)
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

/// A sliced sample as pads, one per slice from `SampleSlice.firstNote`, the first at the bottom
/// left as on a drum machine (`PlaySurface.padRows`): four to a row, eight where the screen is wide.
private struct SlicePads: View {
    let router: LiveRouter
    let count: Int
    let compact: Bool
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ScaledMetric(relativeTo: .body) private var padHeight: CGFloat = 60

    private var columns: Int { compact || horizontalSizeClass == .regular ? 8 : 4 }

    var body: some View {
        let shown = PlaySurface.padRows(count: count, columns: columns)
        // Up to two rows are as tall as the kit's pads at their smallest; more are a finger high
        // each, so sixteen pads on a phone leave the song its room. The height is fixed, as the
        // keyboard's is: the strip does not take the free height from the view above.
        let height = compact || shown.count > 2 ? Theme.Size.touch : Swift.min(padHeight, 88)
        VStack(spacing: Theme.Space.s) {
            ForEach(shown, id: \.self) { row in
                HStack(spacing: Theme.Space.s) {
                    ForEach(row, id: \.self) { index in
                        // VoiceOver reads the pads 1 to N, as the slice editor lists them; the
                        // picture stays a drum machine's, the first pad at the bottom left.
                        PlayKey(router: router, note: SampleSlice.firstNote + index, style: .pad,
                                label: String(index + 1), spokenAs: "Pad \(index + 1)",
                                readingOrder: Double(count - index))
                            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
                    }
                    // A short top row keeps the pads' width: empty places fill it.
                    ForEach(row.count..<Swift.max(row.count, columns), id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Slice Pads")
        .accessibilityAddTraits(.allowsDirectInteraction)
    }
}

/// The chords of the song's key as a row of pads: one finger on one pad plays its chord — three
/// voices led from the chord before and its root under them (`ChordRow`) — for as long as the
/// finger stays down. It writes nothing of its own; a running take records it as it records any
/// key. One chord sounds at a time: a pad pressed while another sounds ends that one first, so two
/// fingers never stack two chords into a cluster. The chord played last is kept while the row
/// shows, for the voices to lead from; a change of the song's key or scale ends what sounds and
/// forgets it, and a change of its swing, tuning or A4 leaves a held chord sounding. Like the
/// keys, it plays on MIDI channel 16 through the one live router.
private struct ChordPads: View {
    let router: LiveRouter
    let context: MusicalContext
    let compact: Bool
    @ScaledMetric(relativeTo: .body) private var padHeight: CGFloat = 60
    @State private var last: ChordRow.Press?
    /// The pad sounding now and its notes, so its release ends exactly what its press started.
    @State private var held: Int?
    @State private var sounding: [UInt8] = []

    private static let velocity: UInt8 = 100
    private static let noteOn: UInt8 = 0x9F
    private static let noteOff: UInt8 = 0x8F

    var body: some View {
        let row = ChordRow.entries(in: context)
        Group {
            if row.isEmpty {
                Text("Give the song a key in the Song menu to play its chords here.")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: Theme.Size.touch)
            } else {
                // Narrow gaps, so seven pads stay a finger wide on a phone in portrait.
                HStack(spacing: Theme.Space.xs) {
                    ForEach(row.indices, id: \.self) { index in
                        ChordPad(label: row[index].label, spoken: row[index].chord.spokenName,
                                 isDown: held == index,
                                 press: { press(index) }, release: { release(index) })
                            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Chords")
                .accessibilityAddTraits(.allowsDirectInteraction)
            }
        }
        .onChange(of: row) { _, _ in
            endSounding()
            last = nil
        }
        .onDisappear {
            endSounding()
            last = nil
        }
    }

    private var height: CGFloat { compact ? Theme.Size.touch : Swift.min(padHeight, 88) }

    private func press(_ index: Int) {
        endSounding()
        guard let chord = ChordRow.press(index, in: context, after: last) else { return }
        let notes = chord.notes.compactMap { (pitch: Int) -> UInt8? in
            (0...127).contains(pitch) ? UInt8(pitch) : nil
        }
        for pitch in notes { router.receive(status: Self.noteOn, pitch, Self.velocity) }
        sounding = notes
        held = index
        last = chord
    }

    private func release(_ index: Int) {
        guard held == index else { return }
        endSounding()
    }

    private func endSounding() {
        for pitch in sounding { router.receive(status: Self.noteOff, pitch, 0) }
        sounding = []
        held = nil
    }
}

/// One chord pad. The first contact presses it and lifting the finger releases it; a touch the
/// system cancels releases it too, because the gesture state resets.
private struct ChordPad: View {
    let label: String
    let spoken: String
    let isDown: Bool
    let press: () -> Void
    let release: () -> Void

    @GestureState private var touching = false
    @State private var down = false
    /// The chord sounds from VoiceOver's activate and ends on its own; a finger that lands on the
    /// pad meanwhile takes it over and ends it when it lifts.
    @State private var fromActivate = false

    var body: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.medium)
            .fill(isDown ? Theme.Color.accent : Theme.Color.surfaceRaised)
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.medium).stroke(Theme.Color.border, lineWidth: 1))
            .overlay {
                Text(label)
                    .font(Theme.Font.caption)
                    .foregroundStyle(isDown ? Theme.Color.onAccent : Theme.Color.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($touching) { _, state, _ in state = true }
                    .onChanged { _ in
                        fromActivate = false
                        guard !down else { return }
                        down = true
                        press()
                    }
                    .onEnded { _ in lift() }
            )
            .onChange(of: touching) { _, stillTouching in
                if !stillTouching { lift() }
            }
            .onDisappear { lift() }
            .accessibilityLabel(spoken)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { strike() }
    }

    private func lift() {
        guard down else { return }
        down = false
        fromActivate = false
        release()
    }

    /// VoiceOver's activate: a short chord, since there is no finger to lift — unless a finger
    /// took it over meanwhile.
    private func strike() {
        guard !down else { return }
        down = true
        fromActivate = true
        press()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            guard fromActivate else { return }
            lift()
        }
    }
}

/// One key or pad. The first contact plays the note and lifting the finger ends it; a touch the
/// system cancels (a notification pulled down, a call) ends it too, because the gesture state
/// resets, so no note is left hanging. The struck pitch is kept, so the release ends what the
/// press started even when the octave changed under the finger. The screen plays on MIDI
/// channel 16, so a key held here and the same key held on a keyboard on channel 1 are two
/// keys, not one struck twice (`LiveKeys` tells keys apart by channel; the instrument does not
/// hear it). A key or a hex cell can play softer near its top and harder near its foot
/// (`TouchVelocity`). Each has its whole range over the part that is its own — a white piano key
/// from the black keys' foot down — so a white and a black key touched in the middle of their own
/// parts play alike, and a phrase across both stays even.
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
    /// The share of the key's length, from its top, that lies between other keys: a touch there
    /// plays as the top of the key's own part. A white piano key has the black keys' length.
    var ownFrom: CGFloat = 0
    /// What VoiceOver calls a pad whose label is only its number.
    var spokenAs: String?
    /// Where VoiceOver reads this key among its neighbours; higher is earlier, 0 keeps the order
    /// on the screen.
    var readingOrder: Double = 0

    @GestureState private var touching = false
    @State private var struck: UInt8?
    /// The note sounds from VoiceOver's activate and ends on its own; a finger that lands on the
    /// key meanwhile takes it over and ends it when it lifts.
    @State private var fromActivate = false

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
                    .onChanged { value in
                        fromActivate = false
                        press(loudness(at: value.startLocation.y, of: length))
                    }
                    .onEnded { _ in release() }
            )
            // The safety net for a touch the system cancels: no `onEnded` comes, the state resets.
            .onChange(of: touching) { _, isDown in
                if !isDown { release() }
            }
            .onDisappear { release() }
            .accessibilityLabel(spokenName)
            .accessibilitySortPriority(readingOrder)
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

    /// A key is said by its full name with its octave; a kit's pad by its drum, a slice's pad by
    /// its number (`spokenAs`).
    private var spokenName: String {
        switch style {
        case .pad: return spokenAs ?? label ?? Keyboard.name(of: note)
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
        let top = length * ownFrom
        return TouchVelocity.velocity(offset: Double(offset - top), length: Double(length - top))
    }

    private func press(_ velocity: UInt8) {
        guard struck == nil, (0...127).contains(note) else { return }
        let pitch = UInt8(note)
        struck = pitch
        router.receive(status: Self.noteOn, pitch, velocity)
    }

    private func release() {
        fromActivate = false
        guard let pitch = struck else { return }
        struck = nil
        router.receive(status: Self.noteOff, pitch, 0)
    }

    /// VoiceOver's activate: a short note, since there is no finger to lift — and no place on the
    /// key, so it plays the one loudness — unless a finger took it over meanwhile.
    private func strike() {
        guard struck == nil else { return }
        press(TouchVelocity.unplaced)
        fromActivate = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard fromActivate else { return }
            release()
        }
    }
}
