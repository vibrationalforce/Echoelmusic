import EchoelCore
import SwiftUI

/// Cycle Tones (W6b): each cycle of the Earth, the Moon, the planets, minor planets and moons as a
/// tone — one over its period, doubled by whole octaves into octave 3 — with the tempo seven
/// octaves lower and the concert pitch that puts the tone exactly on its key (`CycleTone`). The
/// tuning fork on a row tunes the song to that cycle: its key, its concert pitch and, unless a clock,
/// a jam's host or Flow sets the pace, its tempo, as one undo step through the one door. Opened
/// from the Sky page. Arithmetic from the period, never an effect: the page says how each number
/// is made and whose method it is (`CycleLibrary.method`, `.credit`).
///
/// The key and the concert pitch are song-wide values, which are never automated
/// (`Command.setAutomation`), so setting them directly is what the Key menu's writer does too.
struct CycleTonesView: View {
    @Environment(ProjectStore.self) private var store
    @Environment(MIDIInput.self) private var midi
    @Environment(JamSession.self) private var jam: JamSession?
    @Environment(FlowController.self) private var flow: FlowController?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Cycle Tones")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .preferredColorScheme(.dark)
    }

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.Space.m) {
                Text(CycleLibrary.method)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.textSecondary)
                // What the song holds now, so a choice shows what it changed (cold values, Law 6).
                Text("This song: " + CycleToneText.song(store.project))
                    .font(Theme.Font.value)
                    .foregroundStyle(Theme.Color.text)
                ForEach(NaturalCycle.Group.allCases, id: \.self) { group in
                    section(group)
                }
                Text(CycleLibrary.credit)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .padding(.top, Theme.Space.l)
            }
            .padding(Theme.Space.l)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Theme.Color.background)
    }

    @ViewBuilder private func section(_ group: NaturalCycle.Group) -> some View {
        Text(group.title)
            .font(Theme.Font.label)
            .foregroundStyle(Theme.Color.textSecondary)
            .padding(.top, Theme.Space.m)
            .accessibilityAddTraits(.isHeader)
        ForEach(CycleLibrary.all.filter { $0.group == group }) { cycle in
            if let tone = cycle.tone {
                CycleToneRow(cycle: cycle, tone: tone, holds: CycleToneText.holds(store.project, tone),
                             tempoSource: tempoSource, tune: tune)
            }
        }
    }

    /// What sets the pace now, as the tempo field reads it: anything but the song keeps the tempo.
    private var tempoSource: TempoSource {
        TempoSource.current(followsJam: jam?.followsJam == true, followsMIDIClock: midi.followedSource != nil,
                            flows: flow?.lock == .flow)
    }

    private func tune(_ cycle: NaturalCycle, _ tone: CycleTone, _ choice: CycleToneChoice) {
        let key = Command.setKeyRoot(tone.pitch % 12)
        let pitch = Command.setConcertPitch(hertz: CycleToneText.concertPitch(tone))
        let tempo = Command.setTempo(bpm: CycleToneText.tempo(tone))
        let ownTempo = tempoSource == .song
        switch choice {
        case .all:
            let commands = ownTempo ? [key, pitch, tempo] : [key, pitch]
            try? store.perform(commands, title: "Tune to Cycle")
        case .key: try? store.perform(key)
        case .concertPitch: try? store.perform(pitch)
        case .tempo:
            guard ownTempo else { return }
            try? store.perform(tempo)
        }
    }
}

/// What one choice in a row tunes.
enum CycleToneChoice {
    case all, key, concertPitch, tempo
}

/// One cycle: what it is, its numbers, and the tuning fork that tunes the song to it.
private struct CycleToneRow: View {
    let cycle: NaturalCycle
    let tone: CycleTone
    /// Which of this cycle's values the song holds now.
    let holds: CycleToneText.Holds
    let tempoSource: TempoSource
    let tune: (NaturalCycle, CycleTone, CycleToneChoice) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Space.s) {
            VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                HStack(spacing: Theme.Space.xs) {
                    Text(cycle.body + CycleToneText.dot + cycle.cycle)
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.text)
                    if holds.keyAndPitch {
                        Image(systemName: "checkmark")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Color.accent)
                    }
                }
                Text(CycleToneText.numbers(tone))
                    .font(Theme.Font.value)
                    .foregroundStyle(Theme.Color.text)
                Text(CycleToneText.derivation(cycle, tone))
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(CycleToneText.spoken(cycle, tone))
            .accessibilityValue(holds.keyAndPitch ? "The song is tuned to it" : "")
            Spacer(minLength: 0)
            menu
        }
        .padding(.vertical, Theme.Space.xs)
    }

    private var ownTempo: Bool { tempoSource == .song }

    private var menu: some View {
        Menu {
            item(ownTempo ? "Key, Concert Pitch and Tempo" : "Key and Concert Pitch",
                 held: holds.keyAndPitch && (!ownTempo || holds.tempo)) { tune(cycle, tone, .all) }
            Divider()
            item("Key \u{00B7} " + CycleToneText.keyName(tone), held: holds.key) { tune(cycle, tone, .key) }
            item("Concert Pitch \u{00B7} A = " + NumberText.string(CycleToneText.concertPitch(tone), decimals: 2, unit: "Hz"),
                 held: holds.concertPitch) { tune(cycle, tone, .concertPitch) }
            item("Tempo \u{00B7} " + CycleToneText.tempoText(tone), held: holds.tempo) { tune(cycle, tone, .tempo) }
                .disabled(!ownTempo)
            if let follows = tempoFollows {
                // Why the tempo item is dimmed: what sets the pace (TempoSource).
                Text(follows)
            }
        } label: {
            Image(systemName: "tuningfork")
                .frame(minWidth: Theme.Size.touch, minHeight: Theme.Size.touch)
                .contentShape(Rectangle())
        }
        .foregroundStyle(Theme.Color.textSecondary)
        .accessibilityLabel("Tune the Song")
        .accessibilityValue(cycle.body + ", " + cycle.cycle)
        .accessibilityHint(hint)
    }

    /// A choice; a checkmark when the song already holds it, as the Key menu marks its concert pitch.
    private func item(_ title: String, held: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            if held {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }

    private var tempoFollows: String? {
        switch tempoSource {
        case .song: nil
        case .flow: "Flow Sets the Tempo"
        case .midiClock: "Tempo Follows an External Clock"
        case .jam: "Tempo Follows the Jam"
        }
    }

    private var hint: String {
        switch tempoSource {
        case .song: "Sets the song's key, concert pitch or tempo to this cycle's."
        case .flow: "Sets the song's key and concert pitch to this cycle's. Flow sets the tempo now."
        case .midiClock: "Sets the song's key and concert pitch to this cycle's. The tempo is following an external clock."
        case .jam: "Sets the song's key and concert pitch to this cycle's. The tempo is following the jam."
        }
    }
}

/// The numbers the page and the sky's centre line show, formatted in one place. The page's
/// paragraphs, section titles and the sky's one-word cycle names come from `CycleLibrary`, where a
/// test reads them; the units and the menu words here are not read by a test.
///
/// Spelling: a pitch with its octave reads as the keys and the piano roll spell it ("G♯3"); the
/// key alone as the song's Key menu names it ("A♭"), so the item names the key the menu will show.
enum CycleToneText {
    /// The separator of the page's lines, as the Key menu and the app's lists write it.
    static let dot = " \u{00B7} "

    /// Which of a cycle's values the song holds now.
    struct Holds {
        let key: Bool
        let concertPitch: Bool
        let tempo: Bool
        var keyAndPitch: Bool { key && concertPitch }
    }

    static func holds(_ project: Project, _ tone: CycleTone) -> Holds {
        let context = project.context
        return Holds(key: context.root == tone.pitch % 12,
                     concertPitch: abs(context.concertPitch - concertPitch(tone)) < 0.005,
                     tempo: abs(project.tempo - tempo(tone)) < 0.005)
    }

    /// "Key C · A = 440.00 Hz · 120 BPM" — what the song holds now.
    static func song(_ project: Project) -> String {
        let context = project.context
        return "Key " + MusicalContext.rootNames[((context.root % 12) + 12) % 12]
            + dot + "A = " + NumberText.string(context.concertPitch, decimals: 2, unit: "Hz")
            + dot + NumberText.string(project.tempo, decimalsUpTo: 2, unit: "BPM")
    }

    /// The concert pitch to two decimals, as the song's concert-pitch menu shows it.
    static func concertPitch(_ tone: CycleTone) -> Double { (tone.concertPitch * 100).rounded() / 100 }

    /// The tempo to two decimals.
    static func tempo(_ tone: CycleTone) -> Double { (tone.tempo * 100).rounded() / 100 }

    /// The tempo as the tempo field writes it: as few places as it needs, at most two ("63.8 BPM").
    static func tempoText(_ tone: CycleTone) -> String {
        NumberText.string(tempo(tone), decimalsUpTo: 2, unit: "BPM")
    }

    /// The key's name without its octave, as the song's Key menu names it: "C♯", "E♭".
    static func keyName(_ tone: CycleTone) -> String {
        MusicalContext.rootNames[((tone.pitch % 12) + 12) % 12]
    }

    /// "C♯3 · 136.10 Hz · 63.8 BPM" — the pitch spelled as the keys and the piano roll spell it.
    static func numbers(_ tone: CycleTone) -> String {
        figures(tone).joined(separator: dot)
    }

    /// The pitch, the tone in hertz and the tempo, each on its own.
    static func figures(_ tone: CycleTone) -> [String] {
        [NoteEditing.name(of: tone.pitch), NumberText.string(tone.hertz, decimals: 2, unit: "Hz"), tempoText(tone)]
    }

    /// "A = 432.10 Hz · Period 365.24 days, 32 octaves up"
    static func derivation(_ cycle: NaturalCycle, _ tone: CycleTone) -> String {
        "A = " + NumberText.string(concertPitch(tone), decimals: 2, unit: "Hz")
            + dot + "Period " + period(days: cycle.periodDays) + ", " + octaves(tone.octaves)
    }

    /// The row as VoiceOver reads it, commas for the dots.
    static func spoken(_ cycle: NaturalCycle, _ tone: CycleTone) -> String {
        spoken([cycle.body, cycle.cycle, numbers(tone), derivation(cycle, tone)].joined(separator: dot))
    }

    static func period(days: Double) -> String {
        if days < 2 { return NumberText.string(days * 24, decimals: 2, unit: "hours") }
        if days < 3_652.5 { return NumberText.string(days, decimals: 2, unit: "days") }
        return NumberText.string(days / 365.25, decimals: 1, unit: "years")
    }

    static func octaves(_ count: Int) -> String {
        switch count {
        case 0: "in octave 3 as it is"
        case 1: "1 octave up"
        case -1: "1 octave down"
        case let up where up > 0: "\(up) octaves up"
        default: "\(-count) octaves down"
        }
    }

    /// What the line under a body in the sky's ring says: the cycle it is known by, in one word,
    /// and its tone.
    static func skyItems(_ body: SkyBodies.Body) -> [String]? {
        guard let cycle = CycleLibrary.primaryCycle(of: body), let tone = cycle.tone else { return nil }
        return [CycleLibrary.word(of: body)] + figures(tone)
    }

    /// The line drawn under a body in the sky's ring, e.g. "Orbit  ·  F♯3  ·  183.58 Hz  ·  86.05 BPM",
    /// glued as the line above it is. Built once per body: the sky draws it every frame, so a change
    /// of the region's number format shows from the next launch.
    static let skyLines: [SkyBodies.Body: String] = Dictionary(uniqueKeysWithValues: SkyBodies.Body.allCases.compactMap {
        (body: SkyBodies.Body) -> (SkyBodies.Body, String)? in
        skyItems(body).map { (body, $0.map(SkyFrame.glued).joined(separator: SkyFrame.dot)) }
    })

    /// The same lines as VoiceOver reads them, commas between the items, built once.
    static let skySpoken: [SkyBodies.Body: String] = Dictionary(uniqueKeysWithValues: SkyBodies.Body.allCases.compactMap {
        (body: SkyBodies.Body) -> (SkyBodies.Body, String)? in
        skyItems(body).map { (body, $0.joined(separator: ", ")) }
    })

    /// A line as VoiceOver reads it, commas for the dots.
    static func spoken(_ line: String) -> String {
        line.replacingOccurrences(of: dot, with: ", ")
    }
}
