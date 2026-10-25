import EchoelCore
import SwiftUI

/// Keys and pads on the screen, so the phone alone plays the live track the way a plugged-in
/// keyboard does. Every touch goes through the one live router (`AudioEngine.live`): the song's
/// key lock, the chosen live track and a running MIDI take apply to it unchanged. A drum track
/// shows its kit as pads; every other instrument track shows a keyboard.
struct PlayKeysView: View {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    /// The lowest key shown, always a C; kept on this device, never in the song.
    @AppStorage("playKeys.lowestNote") private var lowest = 48
    /// Whether the keys show under the surface; the transport's keys button switches it.
    nonisolated static let shownKey = "playKeys.shown"

    private static let lowestC = 0
    private static let highestC = 96
    @ScaledMetric(relativeTo: .body) private var keyHeight: CGFloat = 132

    var body: some View {
        let track = engine.liveTrackID(in: store.project).flatMap(store.project.track)
        VStack(spacing: Theme.Space.s) {
            header(track)
            if let track {
                if track.instrument.device == .drums {
                    DrumPads(router: engine.live)
                } else {
                    Keyboard(router: engine.live, lowest: clampedLowest)
                        .frame(height: keyHeight)
                }
            } else {
                Text("Add an instrument track to play it here.")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: Theme.Size.touch)
            }
        }
        .padding(.horizontal, Theme.Space.m)
        .padding(.vertical, Theme.Space.s)
        .background(Theme.Color.surface)
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
            if let track, track.instrument.device != .drums {
                Button { lowest = clampedLowest - 12 } label: { Image(systemName: "minus") }
                    .buttonStyle(ToolButtonStyle())
                    .disabled(clampedLowest <= Self.lowestC)
                    .accessibilityLabel("Octave down")
                Text(Keyboard.name(of: clampedLowest))
                    .font(Theme.Font.value)
                    .foregroundStyle(Theme.Color.text)
                    .frame(minWidth: 36)
                    .accessibilityLabel("Lowest key")
                    .accessibilityValue(Keyboard.name(of: clampedLowest))
                Button { lowest = clampedLowest + 12 } label: { Image(systemName: "plus") }
                    .buttonStyle(ToolButtonStyle())
                    .disabled(clampedLowest >= Self.highestC)
                    .accessibilityLabel("Octave up")
            }
        }
    }
}

/// White keys side by side and the black keys over them, as many as the width holds at about
/// 40 points each, from a C upward.
private struct Keyboard: View {
    let router: LiveRouter
    let lowest: Int

    private static let whiteClasses: Set<Int> = [0, 2, 4, 5, 7, 9, 11]
    /// White keys followed by a black one: C, D, F, G, A.
    private static let blackFollows: Set<Int> = [0, 2, 5, 7, 9]
    private static let names = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]

    static func name(of note: Int) -> String {
        names[((note % 12) + 12) % 12] + String(note / 12 - 1)
    }

    var body: some View {
        GeometryReader { geometry in
            let count = Swift.max(7, Swift.min(22, Int(geometry.size.width / 40)))
            let whites = Self.whiteNotes(from: lowest, count: count)
            let width = geometry.size.width / CGFloat(Swift.max(whites.count, 1))
            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    ForEach(whites, id: \.self) { note in
                        PlayKey(router: router, note: note, style: .white,
                                label: note % 12 == 0 ? Self.name(of: note) : nil)
                            .frame(width: width)
                    }
                }
                ForEach(Array(whites.enumerated()), id: \.element) { index, note in
                    if Self.blackFollows.contains(note % 12), index < whites.count - 1, note + 1 <= 127 {
                        PlayKey(router: router, note: note + 1, style: .black, label: nil)
                            .frame(width: width * 0.6, height: geometry.size.height * 0.6)
                            .offset(x: width * CGFloat(index + 1) - width * 0.3)
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

/// The kit as two rows of four pads, kick at the bottom left as on a drum machine.
private struct DrumPads: View {
    let router: LiveRouter
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
                            .frame(maxWidth: .infinity, minHeight: padHeight)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Drum pads")
        .accessibilityAddTraits(.allowsDirectInteraction)
    }
}

/// One key or pad. A touch plays the note and lifting the finger ends it; a touch the system
/// cancels (a notification pulled down, a call) ends it too, because the gesture state resets,
/// so no note is left hanging. The struck pitch is kept, so the release ends what the press
/// started even when the octave changed under the finger.
private struct PlayKey: View {
    enum Style { case white, black, pad }

    let router: LiveRouter
    let note: Int
    let style: Style
    let label: String?

    @GestureState private var touching = false
    @State private var struck: UInt8?

    private static let velocity: UInt8 = 100

    var body: some View {
        RoundedRectangle(cornerRadius: style == .pad ? Theme.Radius.medium : Theme.Radius.small)
            .fill(fill)
            .overlay(
                RoundedRectangle(cornerRadius: style == .pad ? Theme.Radius.medium : Theme.Radius.small)
                    .stroke(Theme.Color.border, lineWidth: 1)
            )
            .overlay(alignment: style == .pad ? .center : .bottom) {
                if let label {
                    Text(label)
                        .font(Theme.Font.caption)
                        .foregroundStyle(style == .white ? Color(white: 0.25) : Theme.Color.textSecondary)
                        .padding(.bottom, style == .pad ? 0 : Theme.Space.xs)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($touching) { _, state, _ in state = true }
            )
            .onChange(of: touching) { _, isDown in
                if isDown { press() } else { release() }
            }
            .onDisappear { release() }
            .accessibilityLabel(label ?? Keyboard.name(of: note))
            .accessibilityAddTraits(.isButton)
    }

    private var fill: Color {
        if struck != nil { return Theme.Color.accent }
        switch style {
        case .white: return Color(white: 0.88)
        case .black: return Color(white: 0.12)
        case .pad: return Theme.Color.surfaceRaised
        }
    }

    private func press() {
        guard struck == nil, (0...127).contains(note) else { return }
        let pitch = UInt8(note)
        struck = pitch
        router.receive(status: 0x90, pitch, Self.velocity)
    }

    private func release() {
        guard let pitch = struck else { return }
        struck = nil
        router.receive(status: 0x80, pitch, 0)
    }
}
