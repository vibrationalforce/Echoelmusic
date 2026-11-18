import EchoelCore
import SwiftUI

/// Cycle Tones, the rightmost view of the studio (founder 2026-11-15, in place of the Sky): tones
/// from natural cycles and measured lines, by category — the planets' cycles (as a list or as the
/// sky itself, with each body's tone under the ring), the lines of hydrogen and everyday
/// molecules, and the musician's own pulse (Body). The category and the look are remembered per window (`SceneStorage`): on an iPad with
/// two windows, one window's switch never starts the other window's sky, its sensors or its camera.
struct CycleTonesSurface: View {
    /// What the tones come from.
    enum Category: String, CaseIterable, Identifiable {
        case planets, molecules, body

        var id: Self { self }

        var title: String {
            switch self {
            case .planets: "Planets"
            case .molecules: "Molecules"
            case .body: "Body"
            }
        }
    }

    /// How the planets' cycles are shown.
    enum Look: String, CaseIterable, Identifiable {
        case list, sky

        var id: Self { self }

        var title: String {
            switch self {
            case .list: "List"
            case .sky: "Sky"
            }
        }
    }

    /// Where the switches are remembered, per window (a convenience, never part of a song).
    /// StudioView reads the same keys to rest the Field window only while the sky shows.
    static let categoryKey = "cycleTones.category"
    static let lookKey = "cycleTones.look"
    @SceneStorage(CycleTonesSurface.categoryKey) private var category: Category = .planets
    @SceneStorage(CycleTonesSurface.lookKey) private var look: Look = .list
    @Environment(StreamingController.self) private var streaming

    /// Whether the sky fills the view for these two switches.
    static func showsSky(category: Category, look: Look) -> Bool {
        category == .planets && look == .sky
    }

    var body: some View {
        VStack(spacing: 0) {
            switches
                // While streaming, the Live badge holds the top right corner: the switches sit below
                // it. (`isOn` changes only at Go Live and Stop.)
                .padding(.top, streaming.isOn ? Theme.Size.touch + Theme.Space.m : 0)
            switch (category, look) {
            case (.planets, .list): CycleTonesList()
            case (.planets, .sky): SkySurface()
            case (.molecules, _): SpectralTonesList()
            case (.body, _): BodyTonesList()
            }
        }
        .background(Theme.Color.background)
    }

    private var switches: some View {
        VStack(spacing: Theme.Space.s) {
            Picker("Category", selection: $category) {
                ForEach(Category.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityHint("Chooses what the tones come from: the planets' cycles, the lines of hydrogen and everyday molecules, or your own pulse.")
            if category == .planets {
                Picker("Show As", selection: $look) {
                    ForEach(Look.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityHint("Shows the cycles as a list of tones, or the sky with each body's tone under the ring.")
            }
        }
        .padding(.horizontal, Theme.Space.m)
        .padding(.vertical, Theme.Space.s)
    }
}

/// The list of the planets' cycle tones (W6b): each cycle of the Earth, the Moon, the planets,
/// minor planets and moons as a tone — one over its period, doubled by whole octaves into octave 3.
struct CycleTonesList: View {
    var body: some View {
        CycleTonePage(method: CycleLibrary.method, credit: CycleLibrary.credit, sections: CycleToneText.cycleSections)
    }
}

/// The list of spectral tones (Molecules): hydrogen's first lines and the vibrations of everyday
/// molecules, each halved by whole octaves into octave 3 (`SpectralLibrary`).
struct SpectralTonesList: View {
    var body: some View {
        CycleTonePage(method: SpectralLibrary.method, credit: SpectralLibrary.credit, sections: CycleToneText.spectralSections)
    }
}

/// The musician's own pulse as a tone (Body, `BodyTones`). The pulse is taken, never followed: the
/// row with the tuning fork shows the pulse as it was at Take Pulse, so its menu is never rebuilt
/// under a finger, and the taken pulse lives only as long as this page — no file keeps it, and the
/// song keeps only the key, tempo or concert pitch the musician then chooses.
///
/// Only where the pulse may leave (`FlowController.mayTakeThePulse`): never from Apple Health, and
/// while the tempo leaves this device only with Share Body Data on. When that turns false, the taken
/// row goes, so no choice can write the pulse into a tempo that leaves; the row above says why.
struct BodyTonesList: View {
    @State private var taken: TakenPulse?
    @Environment(FlowController.self) private var flow

    var body: some View {
        // `mayTakeThePulse` changes with a gesture or a rare event (a clock, a chosen MIDI output
        // appearing, a jam in any window, OSC, Share Body Data), never with the pulse: cold.
        let pulse = taken.flatMap { flow.mayTakeThePulse(from: $0.source) ? $0.beatsPerMinute : nil }
        CycleTonePage(method: BodyTones.method, credit: BodyTones.credit,
                      sections: CycleToneText.bodySections(pulse: pulse),
                      // Asked again at the tuning fork's tap: the gate decides the write, not the drawn row.
                      allowsTuning: { [taken, flow] in taken.map { flow.mayTakeThePulse(from: $0.source) } ?? false }) {
            TakePulseRow(taken: $taken)
        }
    }
}

/// A pulse as Take Pulse held it, with the source it came from.
struct TakenPulse: Equatable {
    let beatsPerMinute: Int
    let source: BodyChannel.Source
}

/// The pulse now, and the button that takes it. A leaf on purpose: the pulse changes about once a
/// second, and only this view reads it (Law 6) — it hosts no menu, and the page above it reads only
/// the pulse once taken. It starts no source; the Song menu's Body Source does. It reads the strap
/// and the camera, as Flow does; Apple Health's pulse is never taken (`BioEgressPolicy` gate 1).
private struct TakePulseRow: View {
    @Binding var taken: TakenPulse?
    @Environment(HeartRateStrap.self) private var strap
    @Environment(CameraPulseSource.self) private var camera
    @Environment(HealthHeartRate.self) private var health
    @Environment(FlowController.self) private var flow
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let reading {
                pulseRow(reading)
            } else {
                note(health.isOn ? BodyTones.healthNotTaken : BodyTones.noSource)
            }
            // Whatever source is on: a pulse taken earlier is put aside for the same reason.
            if !flow.tempoMayCarryThePulse { note(BodyTones.sharingOff) }
        }
    }

    private func pulseRow(_ reading: (pulse: Int?, words: String, source: BodyChannel.Source)) -> some View {
        let pulse = reading.pulse.flatMap { BodyTones.heartbeat(beatsPerMinute: $0) == nil ? nil : $0 }
        let mayTake = flow.mayTakeThePulse(from: reading.source)
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Space.s))
            : AnyLayout(HStackLayout(alignment: .center, spacing: Theme.Space.s))
        return layout {
            VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                Text("Pulse now")
                    .font(Theme.Font.label)
                    .foregroundStyle(Theme.Color.textSecondary)
                Text(pulse.map { NumberText.string(Double($0), decimals: 0, unit: "BPM") } ?? reading.words)
                    .font(Theme.Font.value)
                    .foregroundStyle(pulse == nil ? Theme.Color.textSecondary : Theme.Color.text)
                    .monospacedDigit()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Pulse now")
            .accessibilityValue(pulse.map { "\($0) beats per minute" } ?? reading.words)
            Spacer(minLength: 0)
            Button("Take Pulse") {
                // Asked again at the tap: the gate is the one that decides, not the drawn button.
                guard let pulse, flow.mayTakeThePulse(from: reading.source) else { return }
                taken = TakenPulse(beatsPerMinute: pulse, source: reading.source)
            }
            .buttonStyle(ToolButtonStyle())
            .disabled(pulse == nil || !mayTake)
            .accessibilityHint("Holds the pulse as it is now and turns it into a tone below. The song keeps nothing of it until you choose a key, tempo or concert pitch.")
        }
        .padding(.vertical, Theme.Space.xs)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(Theme.Font.body)
            .foregroundStyle(Theme.Color.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Theme.Space.xs)
    }

    /// The pulse source that is on, its pulse, its words and what it is, in the order the transport
    /// reads them; nil while neither the strap nor the camera is on.
    private var reading: (pulse: Int?, words: String, source: BodyChannel.Source)? {
        if strap.isOn { return (strap.beatsPerMinute, PulseReading.words(for: strap.status), BodyChannel.Source.ble) }
        if camera.isOn { return (camera.beatsPerMinute, PulseReading.words(for: camera.status, cue: camera.cue), BodyChannel.Source.camera) }
        return nil
    }
}

/// One row's content, whatever the tone comes from.
struct ToneItem: Identifiable {
    let id: String
    /// "Jupiter · Orbit (sidereal)", "Water H₂O · Bend (ν₂)".
    let title: String
    let tone: CycleTone
    /// "A = 436.62 Hz · Period 11.86 years, 36 octaves up".
    let derivation: String
    /// The whole row as VoiceOver reads it: plain words, no subscripts or symbols, units in words.
    let spoken: String
    /// The first step of its calculation: where the frequency comes from.
    let origin: String
}

/// A titled group of rows.
struct ToneSection: Identifiable {
    let id: String
    let title: String
    let items: [ToneItem]
}

/// A page of tones: how the numbers are made, what the song holds now, the rows by section, and
/// whose method and numbers they are. The tuning fork on a row tunes the song to that tone through
/// the one door: its key, its tempo (unless a clock, a jam's host or Flow sets the pace), both as
/// one undo step, or, last and on its own, its concert pitch. Arithmetic, never an effect.
///
/// The key and the concert pitch are song-wide values, which are never automated
/// (`Command.setAutomation`), so setting them directly is what the Key menu's writer does too.
/// A page may add its own lines under the song's (`header`): the Body page's Take Pulse.
struct CycleTonePage<Header: View>: View {
    let method: String
    let credit: String
    let sections: [ToneSection]
    /// Asked at every choice before anything is written; the Body page closes it while the pulse
    /// may not go into the song. Planets and Molecules always allow.
    let allowsTuning: () -> Bool
    let header: Header
    @Environment(ProjectStore.self) private var store
    @Environment(MIDIInput.self) private var midi
    @Environment(JamSession.self) private var jam: JamSession?
    @Environment(FlowController.self) private var flow: FlowController?

    init(method: String, credit: String, sections: [ToneSection], allowsTuning: @escaping () -> Bool = { true },
         @ViewBuilder header: () -> Header) {
        self.method = method
        self.credit = credit
        self.sections = sections
        self.allowsTuning = allowsTuning
        self.header = header()
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.Space.m) {
                Text(method)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.textSecondary)
                // What the song holds now, so a choice shows what it changed (cold values, Law 6).
                Text("This song: " + CycleToneText.song(store.project))
                    .font(Theme.Font.value)
                    .foregroundStyle(Theme.Color.text)
                header
                ForEach(sections) { section in
                    Text(section.title)
                        .font(Theme.Font.label)
                        .foregroundStyle(Theme.Color.textSecondary)
                        .padding(.top, Theme.Space.m)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(section.items) { item in
                        CycleToneRow(item: item, holds: CycleToneText.holds(store.project, item.tone),
                                     tempoSource: tempoSource, tune: tune)
                    }
                }
                Text(credit)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .padding(.top, Theme.Space.l)
            }
            .padding(Theme.Space.l)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Theme.Color.background)
    }

    /// What sets the pace now, as the tempo field reads it: anything but the song keeps the tempo.
    private var tempoSource: TempoSource {
        TempoSource.current(followsJam: jam?.followsJam == true, followsMIDIClock: midi.followedSource != nil,
                            flows: flow?.lock == .flow)
    }

    private func tune(_ tone: CycleTone, _ choice: CycleToneChoice) {
        guard allowsTuning() else { return }
        let key = Command.setKeyRoot(tone.pitch % 12)
        let pitch = Command.setConcertPitch(hertz: CycleToneText.concertPitch(tone))
        let tempo = Command.setTempo(bpm: CycleToneText.tempo(tone))
        let ownTempo = tempoSource == .song
        switch choice {
        case .keyAndTempo:
            guard ownTempo else { return }
            try? store.perform([key, tempo], title: "Tune to Tone")
        case .key: try? store.perform(key)
        case .concertPitch: try? store.perform(pitch)
        case .tempo:
            guard ownTempo else { return }
            try? store.perform(tempo)
        }
    }
}

extension CycleTonePage where Header == EmptyView {
    init(method: String, credit: String, sections: [ToneSection]) {
        self.init(method: method, credit: credit, sections: sections, header: { EmptyView() })
    }
}

/// What one choice in a row tunes — offered in the order the survey found most audible and useful:
/// the key, the tempo, both, and the concert pitch last and on its own.
enum CycleToneChoice {
    case key, tempo, keyAndTempo, concertPitch
}

/// One tone: what it is, its numbers, and the tuning fork that tunes the song to it.
private struct CycleToneRow: View {
    let item: ToneItem
    /// Which of this tone's values the song holds now.
    let holds: CycleToneText.Holds
    let tempoSource: TempoSource
    let tune: (CycleTone, CycleToneChoice) -> Void

    private var tone: CycleTone { item.tone }
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            // At the accessibility text sizes the tuning fork goes under the numbers, so no number is cut.
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Space.s))
                : AnyLayout(HStackLayout(alignment: .center, spacing: Theme.Space.s))
            layout {
                summary
                Spacer(minLength: 0)
                menu
            }
            DisclosureGroup("How is this calculated?") {
                VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                    ForEach(Array(CycleToneText.steps(item).enumerated()), id: \.offset) { number, step in
                        Text("\(number + 1). " + step)
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Color.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityLabel("Step \(number + 1): " + CycleToneText.spokenNumbers(step))
                    }
                }
                .padding(.top, Theme.Space.xxs)
            }
            .font(Theme.Font.caption)
            .foregroundStyle(Theme.Color.textSecondary)
        }
        .padding(.vertical, Theme.Space.xs)
    }

    /// What the tone is and its numbers, read as one element.
    private var summary: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xxs) {
            HStack(spacing: Theme.Space.xs) {
                Text(item.title)
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
            Text(item.derivation)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.spoken)
        .accessibilityValue(holds.keyAndPitch ? "The song is tuned to it" : "")
    }

    private var ownTempo: Bool { tempoSource == .song }

    private var menu: some View {
        Menu {
            choice("Key \u{00B7} " + CycleToneText.keyName(tone), held: holds.key) { tune(tone, .key) }
            choice("Tempo \u{00B7} " + CycleToneText.tempoText(tone), held: holds.tempo) { tune(tone, .tempo) }
                .disabled(!ownTempo)
            if ownTempo {
                choice("Key and Tempo", held: holds.key && holds.tempo) { tune(tone, .keyAndTempo) }
            }
            if let follows = tempoFollows {
                // Why the tempo items are dimmed or missing: what sets the pace (TempoSource).
                Text(follows)
            }
            Divider()
            // Last and on its own: the tone exactly on its key, but against recordings at 440 Hz it beats.
            choice("Concert Pitch \u{00B7} A = " + NumberText.string(CycleToneText.concertPitch(tone), decimals: 2, unit: "Hz"),
                 held: holds.concertPitch) { tune(tone, .concertPitch) }
        } label: {
            Image(systemName: "tuningfork")
                .frame(minWidth: Theme.Size.touch, minHeight: Theme.Size.touch)
                .contentShape(Rectangle())
        }
        .foregroundStyle(Theme.Color.textSecondary)
        .accessibilityLabel("Tune the Song")
        .accessibilityValue(item.spoken.components(separatedBy: CycleToneText.spokenBreak).first ?? item.spoken)
        .accessibilityHint(hint)
    }

    /// A choice; a checkmark when the song already holds it, as the Key menu marks its concert pitch.
    private func choice(_ title: String, held: Bool, action: @escaping () -> Void) -> some View {
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
        case .song: "Sets the song's key, tempo or concert pitch to this tone's."
        case .flow: "Sets the song's key or concert pitch to this tone's. Flow sets the tempo now."
        case .midiClock: "Sets the song's key or concert pitch to this tone's. The tempo is following an external clock."
        case .jam: "Sets the song's key or concert pitch to this tone's. The tempo is following the jam."
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

    /// "A = 440.04 Hz · Wavenumber 15233 cm⁻¹, 456.67 THz, 41 octaves down"
    static func derivation(_ line: SpectralLine, _ tone: CycleTone) -> String {
        "A = " + NumberText.string(concertPitch(tone), decimals: 2, unit: "Hz")
            + dot + "Wavenumber " + NumberText.string(line.wavenumber, decimalsUpTo: 2, unit: "cm\u{207B}\u{00B9}")
            + ", " + NumberText.string(line.hertz / 1e12, decimals: 2, unit: "THz") + ", " + octaves(tone.octaves)
    }

    /// A row's calculation, step by step, with its own numbers: where the frequency comes from, the
    /// octaves into octave 3, the nearest key and how far off it the tone lies, the tempo and the A.
    static func steps(_ item: ToneItem) -> [String] {
        let tone = item.tone
        let count = abs(tone.octaves)
        let factor = NumberText.string(Foundation.pow(2, Double(count)), decimals: 0)
        let moved = tone.octaves >= 0 ? "Doubled \(count) times (× \(factor))" : "Halved \(count) times (÷ \(factor))"
        let key = NoteEditing.name(of: tone.pitch)
        let keyHertz = 440 * Foundation.pow(2, Double(tone.pitch - 69) / 12)
        let cents = tone.centsFromKey
        let side = cents < 0 ? "below" : "above"
        let hertz = NumberText.string(tone.hertz, decimals: 2)
        let beat = NumberText.string(60 / tempo(tone), decimals: 2, unit: "s")
        return [
            item.origin,
            moved + ": " + NumberText.string(tone.hertz, decimals: 2, unit: "Hz") + ", its nearest key in octave 3 (tones from "
                + NumberText.string(CycleTone.lowestHertz, decimals: 2) + " to "
                + NumberText.string(CycleTone.highestHertz, decimals: 2, unit: "Hz") + ").",
            "Nearest key: " + key + ", " + NumberText.string(keyHertz, decimals: 2, unit: "Hz") + " when A is 440 Hz; the tone is "
                + NumberText.string(Swift.abs(cents), decimals: 1, unit: "cents") + " " + side + " it.",
            // "≈", not "=": the tempo is rounded from the unrounded tone, so the printed sum can differ in its last place.
            "Tempo: the tone seven octaves lower, " + hertz + " ÷ 128 × 60 ≈ " + tempoText(tone) + ", one beat every " + beat + ".",
            "Concert pitch: the A, to 0.01 Hz, that puts " + key + " on " + hertz + " Hz: A = "
                + NumberText.string(concertPitch(tone), decimals: 2, unit: "Hz") + ".",
        ]
    }

    /// Where a spoken row's name ends and its numbers begin.
    static let spokenBreak = "; "

    /// The numbers, derivation and steps as VoiceOver reads them: units, the sharp and the signs of
    /// the arithmetic in words (no number on these rows carries a sign). "A = " goes before " = ".
    static func spokenNumbers(_ text: String) -> String {
        var spoken = text.replacingOccurrences(of: dot, with: ", ")
        for (symbol, words) in [(" cm\u{207B}\u{00B9}", " per centimetre"), (" THz", " terahertz"), (" Hz", " hertz"),
                                (" BPM", " beats per minute"), ("A = ", "A at "), ("♯", " sharp "), ("×", "times"),
                                ("÷", "divided by"), ("≈", "is about"), (" = ", " equals ")] {
            spoken = spoken.replacingOccurrences(of: symbol, with: words)
        }
        // A number of seconds: "1 s" reads "1 second", "0.94 s" reads "0.94 seconds"; a word that starts
        // with an s is left alone.
        spoken = spoken.replacingOccurrences(of: "(?<![0-9.,])1 s\\b", with: "1 second", options: .regularExpression)
        return spoken.replacingOccurrences(of: "([0-9]) s\\b", with: "$1 seconds", options: .regularExpression)
    }

    /// The planets' rows by section. Built when the page is drawn, so every number on a row follows
    /// the same, current number format.
    static var cycleSections: [ToneSection] {
        NaturalCycle.Group.allCases.map { (group: NaturalCycle.Group) -> ToneSection in
            let items = CycleLibrary.all.filter { $0.group == group }.compactMap { (cycle: NaturalCycle) -> ToneItem? in
                guard let tone = cycle.tone else { return nil }
                let derived = derivation(cycle, tone)
                return ToneItem(id: cycle.id, title: cycle.body + dot + cycle.cycle, tone: tone, derivation: derived,
                                spoken: cycle.body + ", " + cycle.cycle + spokenBreak
                                    + spokenNumbers(numbers(tone) + dot + derived),
                                origin: "Period: " + period(days: cycle.periodDays) + " ("
                                    + NumberText.string(tone.periodSeconds, decimals: 0, unit: "s")
                                    + "); its frequency is one over it.")
            }
            return ToneSection(id: group.rawValue, title: group.title, items: items)
        }
    }

    /// The taken pulse's row, built the same way; no section while no pulse is taken.
    static func bodySections(pulse: Int?) -> [ToneSection] {
        guard let pulse, let tone = BodyTones.heartbeat(beatsPerMinute: pulse) else { return [] }
        let rate = NumberText.string(Double(pulse), decimals: 0, unit: "BPM")
        let beat = NumberText.string(tone.periodSeconds, decimalsUpTo: 4, unit: "s")
        let derived = "A = " + NumberText.string(concertPitch(tone), decimals: 2, unit: "Hz")
            + dot + "One heartbeat every " + beat + ", " + octaves(tone.octaves)
        let item = ToneItem(id: "heartbeat", title: "Pulse " + rate + ", taken", tone: tone, derivation: derived,
                            spoken: "Pulse " + spokenNumbers(rate) + ", taken" + spokenBreak
                                + spokenNumbers(numbers(tone) + dot + derived),
                            origin: "Pulse: " + rate + ", one heartbeat every " + beat + "; its frequency is one over it.")
        return [ToneSection(id: "heartbeat", title: BodyTones.heartbeatTitle, items: [item])]
    }

    /// The molecules' rows by section, built the same way.
    static var spectralSections: [ToneSection] {
        SpectralLine.Kind.allCases.map { (kind: SpectralLine.Kind) -> ToneSection in
            let items = SpectralLibrary.all.filter { $0.kind == kind }.compactMap { (line: SpectralLine) -> ToneItem? in
                guard let tone = line.tone else { return nil }
                let derived = derivation(line, tone)
                return ToneItem(id: line.id, title: line.substance + dot + line.line, tone: tone, derivation: derived,
                                spoken: line.spokenSubstance + ", " + line.spokenLine + spokenBreak
                                    + spokenNumbers(numbers(tone) + dot + derived),
                                origin: "Wavenumber " + NumberText.string(line.wavenumber, decimalsUpTo: 2, unit: "cm\u{207B}\u{00B9}")
                                    + " × speed of light = " + NumberText.string(line.hertz / 1e12, decimals: 2, unit: "THz") + ".")
            }
            return ToneSection(id: kind.rawValue, title: kind.title, items: items)
        }
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
