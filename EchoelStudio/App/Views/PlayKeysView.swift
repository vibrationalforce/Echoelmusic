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
                } else {
                    Keyboard(router: engine.live, lowest: clampedLowest)
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
                Button { lowest = clampedLowest - 12 } label: { Image(systemName: "minus") }
                    .buttonStyle(ToolButtonStyle())
                    .disabled(clampedLowest <= Self.lowestC)
                    .accessibilityLabel("Octave Down")
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
            }
        }
    }
}

/// White keys side by side and the black keys over them, as many as the width holds at about
/// 48 points each, from a C upward.
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
            // About 48 pt a white key, so a black key (0.7 of it) stays a finger wide.
            let count = Swift.max(7, Swift.min(22, Int(geometry.size.width / 48)))
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
        .accessibilityLabel("Drum pads")
        .accessibilityAddTraits(.allowsDirectInteraction)
    }
}

/// One key or pad. The first contact plays the note and lifting the finger ends it; a touch the
/// system cancels (a notification pulled down, a call) ends it too, because the gesture state
/// resets, so no note is left hanging. The struck pitch is kept, so the release ends what the
/// press started even when the octave changed under the finger. The screen plays on MIDI
/// channel 16, so a key held here and the same key held on a keyboard on channel 1 are two
/// keys, not one struck twice (`LiveKeys` tells keys apart by channel; the instrument does not
/// hear it).
private struct PlayKey: View {
    enum Style { case white, black, pad }

    let router: LiveRouter
    let note: Int
    let style: Style
    let label: String?

    @GestureState private var touching = false
    @State private var struck: UInt8?

    private static let velocity: UInt8 = 100
    private static let noteOn: UInt8 = 0x9F
    private static let noteOff: UInt8 = 0x8F

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
                        .foregroundStyle(style == .white ? Theme.Color.keyLabel : Theme.Color.textSecondary)
                        .padding(.bottom, style == .pad ? 0 : Theme.Space.xs)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($touching) { _, state, _ in state = true }
                    .onChanged { _ in press() }
                    .onEnded { _ in release() }
            )
            // The safety net for a touch the system cancels: no `onEnded` comes, the state resets.
            .onChange(of: touching) { _, isDown in
                if !isDown { release() }
            }
            .onDisappear { release() }
            .accessibilityLabel(label ?? Keyboard.name(of: note))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { strike() }
    }

    private var fill: Color {
        if struck != nil { return Theme.Color.accent }
        switch style {
        case .white: return Theme.Color.keyWhite
        case .black: return Theme.Color.keyBlack
        case .pad: return Theme.Color.surfaceRaised
        }
    }

    private func press() {
        guard struck == nil, (0...127).contains(note) else { return }
        let pitch = UInt8(note)
        struck = pitch
        router.receive(status: Self.noteOn, pitch, Self.velocity)
    }

    private func release() {
        guard let pitch = struck else { return }
        struck = nil
        router.receive(status: Self.noteOff, pitch, 0)
    }

    /// VoiceOver's activate: a short note, since there is no finger to lift.
    private func strike() {
        press()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            release()
        }
    }
}
