import EchoelCore
import SwiftUI

/// The Instrument (W12): the heart of Echoel as a view of its own. The Field on top, playable as
/// the note grid while the grid is switched on (G5), with its bar under it; under that the sound and
/// mood of the track the keys play — the keys under the view play it — and then the body: the
/// pulse, the Body Voice, the tempo lock. While no body source is on, the Body Voice is off and the
/// tempo is Fixed, the body is one row, "Body: Off", that opens to its controls. `InstrumentPage`
/// decides the sections and their order. A fingertip on the rear camera, or a chest strap, and the
/// body plays, with nothing to learn first.
///
/// This body reads only what changes with an edit or a choice: the song, the live track, the lock.
/// The grid, its switch and its settings are leaves of their own, which read the song, the live
/// track and the switches; the touches and the light they leave are read by no body (Law 6).
/// Whether a body source is on is read by `InstrumentBodySections`, which draws the body's sections:
/// it reads only the sources' `isOn`, which follows each source's status. That moves when a source
/// starts, stops, finds or loses its signal, never with the pulse, and redraws the body's sections
/// alone, never the Sound and Mood menus above them. What moves with the body or the clock — the
/// pulse, what is measured, what Flow follows — is read by its own leaf, and no such leaf holds a
/// menu (Law 6), so an open menu here is never torn down by a heartbeat.
struct InstrumentSurface: View {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    @Environment(FlowController.self) private var flow
    /// False while the Field fills the screen: one picture at a time.
    let showsField: Bool
    let expand: () -> Void

    @State private var problem: String?

    /// The tallest the Field grows on a wide screen; on a phone its width sets its height (16:10).
    private static let fieldHeightLimit: CGFloat = 320

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.l) {
                ForEach(InstrumentPage.lead, id: \.self) { section in
                    sectionView(section)
                }
                InstrumentBodySections(bodyVoiceOn: BodyVoice.isOn(in: store.project),
                                       flows: flow.lock == .flow) { section in
                    sectionView(section)
                }
            }
            .padding(Theme.Space.m)
        }
        .background(Theme.Color.background)
    }

    /// One section of the page, as `InstrumentPage` names it.
    @ViewBuilder private func sectionView(_ section: InstrumentPage.Section) -> some View {
        switch section {
        case .field: field
        case .sound: sound
        case .bodyRow: bodyRow
        case .pulse(let showsSafety): pulse(showsSafety: showsSafety)
        case .bodyVoice: bodyVoice
        case .tempo: tempo
        }
    }

    // MARK: Field

    /// The Field card, and under it its bar.
    private var field: some View {
        VStack(alignment: .trailing, spacing: Theme.Space.s) {
            fieldPicture
            fieldBar
        }
    }

    /// The Field, and over it the note grid while the grid is switched on and the keys play a
    /// pitched instrument (`FieldGridView`, the full screen's grid, here over the card's whole
    /// bounds). While the Field fills the screen the card is blank and holds no grid: one window
    /// plays one grid, and the card's notes end as the full screen opens.
    private var fieldPicture: some View {
        ZStack {
            if showsField {
                FieldView()
                FieldGridView(place: .card)
            } else {
                Theme.Color.background
            }
        }
        .aspectRatio(16 / 10, contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: Self.fieldHeightLimit)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.large).stroke(Theme.Color.border, lineWidth: 1))
    }

    /// The card's controls, under the picture rather than on it, so none covers a cell of the grid:
    /// the grid's switch and the way to the full screen, at the trailing edge where the button sat
    /// on the picture before; under them, while the grid shows, Hold and the octave. The full
    /// screen's bar in the same order and in the same two rows, so it fits a phone held upright.
    private var fieldBar: some View {
        VStack(alignment: .trailing, spacing: Theme.Space.s) {
            HStack(spacing: Theme.Space.s) {
                FieldGridSwitch()
                Button(action: expand) { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                    .buttonStyle(ToolButtonStyle())
                    .accessibilityLabel(StudioPlace.fullScreen.title)
                    .accessibilityHint("Opens the Field in full screen.")
            }
            if showsField {
                FieldGridControls()
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    // MARK: Body, off

    /// The body in one row while nothing of it is on: closed, "Body: Off"; open, the controls its
    /// cards would hold — the body-source chooser, the Body Voice switch, the tempo lock. Turning one
    /// of them on brings the cards back (`InstrumentPage`). Its name is the one Learn quotes
    /// (`StudioPlace.bodyOff`), and the whole row is a touch target: it is the page's one door to
    /// the body while the body is off.
    private var bodyRow: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                // Whole and in plain text where a source is chosen: the menu's own header may be
                // cut by iOS at a large text size.
                ParagraphText(BodySourceMenu.safetyLine)
                sourceMenu
                Divider().overlay(Theme.Color.border)
                bodyVoiceControls
                Divider().overlay(Theme.Color.border)
                tempoControls
            }
            .padding(.top, Theme.Space.s)
        } label: {
            // The hint is on the label, the disclosure's button, not on the group, which also holds
            // the row's controls with hints of their own.
            Text(StudioPlace.bodyOff.title)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.text)
                .frame(maxWidth: .infinity, minHeight: Theme.Size.touch, alignment: .leading)
                .contentShape(Rectangle())
                .accessibilityHint("Opens the body source, the Body Voice and the tempo lock.")
        }
        .card()
    }

    // MARK: Pulse

    private func pulse(showsSafety: Bool) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            InstrumentPulse(showsSafety: showsSafety)
            // Out of the pulse's leaf on purpose: a menu redrawn once a second would close itself.
            sourceMenu
        }
        .card()
    }

    /// The body-source chooser as the page shows it: under the pulse, and in the body row.
    private var sourceMenu: some View {
        BodySourceMenu()
            .menuStyle(.button)
            .buttonStyle(ToolButtonStyle())
            .accessibilityHint("A fingertip on the rear camera and flash, or a heart rate strap.")
    }

    // MARK: Body Voice

    private var bodyVoice: some View {
        bodyVoiceControls.card()
    }

    /// The Body Voice's switch, what it does and its routes: on its card, and in the body row.
    private var bodyVoiceControls: some View {
        let project = store.project
        let voice = BodyVoice.track(in: project)
        return VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Toggle("Body Voice", isOn: Binding(get: { BodyVoice.isOn(in: store.project) },
                                               set: { switchBodyVoice($0) }))
                .toggleStyle(EchoelToggleStyle())
                .disabled(!BodyVoice.hasRoom(in: project))
                .accessibilityHint("A pad the keys play; your body shapes its sound.")
            NoteText("The keys play it. Your breath swells its level, coherence opens and brightens its sound, and your pulse sets its vibrato. Silent until switched on.")
            NoteText("Breath is read from the timing of your heartbeats. Breathe slowly and evenly, and it joins after a few breaths.")
            if let problem {
                NoteText(problem, tone: .problem)
            }
            // On, but the keys play another track (chosen in Tracks, or the app started again):
            // one tap gives the voice its keys back, never a silent switch behind the musician.
            if let voice, !voice.mixer.isMuted, engine.liveTrackID(in: project) != voice.id {
                Button("Play on the Keys") { engine.setLiveTrack(voice.id) }
                    .buttonStyle(ToolButtonStyle())
                    .accessibilityHint("The keys under the page play the Body Voice.")
            }
            if let voice {
                // The routes the voice started with, seen and changed like any other (W2).
                ModulateMenu(owner: .track(voice.id))
                    .menuStyle(.button)
                    .buttonStyle(ToolButtonStyle())
                    .accessibilityHint("How the body moves the Body Voice: see and change it here.")
            }
        }
    }

    /// On: the voice's track the first time, else unmuted, and the keys play it. Off: muted, and the
    /// keys go to another instrument track, so they never play a silent one.
    private func switchBodyVoice(_ on: Bool) {
        problem = nil
        guard let change = BodyVoice.switching(on, in: store.project) else { return }
        do {
            try store.perform(change.commands, title: change.title)
        } catch {
            problem = "The Body Voice did not fit: this song holds as many instrument tracks or routes as it can. Remove one, then try again."
            return
        }
        let project = store.project
        guard let voice = BodyVoice.track(in: project) else { return }
        if on {
            engine.setLiveTrack(voice.id)
        } else if engine.liveTrackID(in: project) == voice.id {
            engine.setLiveTrack(project.tracks.first { $0.kind == .instrument && $0.id != voice.id }?.id)
        }
    }

    // MARK: Tempo

    private var tempo: some View {
        tempoControls.card()
    }

    /// The tempo lock and what Flow does now: on its card, and in the body row.
    private var tempoControls: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text("Tempo")
                .font(Theme.Font.label)
                .foregroundStyle(Theme.Color.textSecondary)
                .accessibilityHidden(true)
            EchoelSegments("Tempo", selection: Binding(get: { flow.lock }, set: { flow.setLock($0) }), options: [
                SegmentOption(TempoLock.fixed, "Fixed"),
                SegmentOption(TempoLock.flow, "Flow"),
            ])
            .disabled(!flow.canFlow && flow.lock == .fixed)
            .accessibilityHint("Fixed keeps the tempo where you set it. Flow lets your pulse move it, one step per bar.")
            FlowStatusLine()
        }
    }

    // MARK: Sound and Mood

    @ViewBuilder private var sound: some View {
        let project = store.project
        if let track = engine.liveTrackID(in: project).flatMap(project.track) {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                if track.instrument.device == .synth {
                    soundMenu(track)
                    moodMenu(track)
                    NoteText("Sound and Mood change \(track.name), the track the keys play.")
                } else {
                    NoteText("Sound and Mood shape a synth track; the keys play \(track.name).")
                }
            }
            .card()
        } else {
            NoteText("Add an instrument track; the keys play it.")
        }
    }

    private func soundMenu(_ track: Track) -> some View {
        let engines = SynthParameter.engine.choices
        let chosen = Int(track.instrument.value(.engine).rounded())
        let engineName = engines.indices.contains(chosen) ? engines[chosen] : "–"
        return Menu {
            Section("Preset") {
                ForEach(InstrumentPreset.all, id: \.name) { preset in
                    Button {
                        apply(InstrumentSound.choosing(preset: preset.name, on: track), title: "Choose Sound")
                    } label: {
                        checked(preset.name, preset.name == track.instrument.preset)
                    }
                }
            }
            Section("Engine") {
                ForEach(engines.indices, id: \.self) { index in
                    Button {
                        apply(InstrumentSound.choosing(engine: index, on: track.id), title: "Choose Engine")
                    } label: {
                        checked(engines[index], index == chosen)
                    }
                }
            }
        } label: {
            pickLabel("Sound", value: track.instrument.preset + " · " + engineName)
        }
        .accessibilityLabel("Sound")
        .accessibilityValue(track.instrument.preset + ", " + engineName)
    }

    private func moodMenu(_ track: Track) -> some View {
        let current = InstrumentMood.current(of: track.instrument)
        return Menu {
            ForEach(InstrumentMood.all) { mood in
                Button {
                    apply(mood.commands(for: track.id), title: "Choose Mood")
                } label: {
                    checked(mood.name, mood == current)
                }
            }
        } label: {
            pickLabel("Mood", value: current?.name ?? "None")
        }
        .accessibilityLabel("Mood")
        .accessibilityValue(current?.name ?? "None")
    }

    private func apply(_ commands: [Command], title: String) {
        try? store.perform(commands, title: title)
    }

    @ViewBuilder private func checked(_ title: String, _ chosen: Bool) -> some View {
        if chosen {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }

    private func pickLabel(_ title: String, value: String) -> some View {
        HStack(spacing: Theme.Space.s) {
            Text(title)
                .foregroundStyle(Theme.Color.textSecondary)
            Text(value)
                .foregroundStyle(Theme.Color.text)
                .lineLimit(1)
            Spacer(minLength: 0)
            Image(systemName: "chevron.down")
                .foregroundStyle(Theme.Color.textSecondary)
                .accessibilityHidden(true)
        }
        .font(Theme.Font.body)
        .padding(.horizontal, Theme.Space.m)
        .frame(maxWidth: .infinity, minHeight: Theme.Size.touch, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.medium).fill(Theme.Color.surfaceRaised))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.medium).strokeBorder(Theme.Color.borderStrong, lineWidth: 1))
    }
}

/// The body's sections of the page, as `InstrumentPage` decides them from whether a body source is
/// on (Law 6): the one view of the page that asks, and it reads only the sources' `isOn`, never the
/// rate. `isOn` follows each source's status, which moves when a source starts, stops, finds or
/// loses its signal; that redraws these sections alone, never the Field or the Sound and Mood menus
/// that lead the page.
private struct InstrumentBodySections<Content: View>: View {
    @Environment(HeartRateStrap.self) private var strap
    @Environment(CameraPulseSource.self) private var camera
    @Environment(HealthHeartRate.self) private var health
    @Environment(PhoneMotionSource.self) private var phoneMotion
    let bodyVoiceOn: Bool
    let flows: Bool
    private let content: (InstrumentPage.Section) -> Content

    init(bodyVoiceOn: Bool, flows: Bool, @ViewBuilder content: @escaping (InstrumentPage.Section) -> Content) {
        self.bodyVoiceOn = bodyVoiceOn
        self.flows = flows
        self.content = content
    }

    var body: some View {
        let sourceOn = strap.isOn || camera.isOn || health.isOn || phoneMotion.isOn
        ForEach(InstrumentPage.bodySections(bodySourceOn: sourceOn, bodyVoiceOn: bodyVoiceOn, flows: flows),
                id: \.self, content: content)
    }
}

/// The pulse, large, with the body source and what it measures: the one view of the page that
/// reads the body (Law 6). The rate changes about once a second, the rest when a source starts,
/// stops or finds its signal; it holds no menu, so nothing open closes when it changes.
private struct InstrumentPulse: View {
    @Environment(HeartRateStrap.self) private var strap
    @Environment(CameraPulseSource.self) private var camera
    @Environment(HealthHeartRate.self) private var health
    @Environment(PhoneMotionSource.self) private var phoneMotion
    /// The safety sentence stands under the pulse: while a body source is on (`InstrumentPage`).
    let showsSafety: Bool

    var body: some View {
        let rate: Int? = strap.isOn ? strap.beatsPerMinute
            : (camera.isOn ? camera.beatsPerMinute : (health.isOn ? health.beatsPerMinute : nil))
        let measuring = strap.measuring.union(camera.measuring).union(health.measuring).union(phoneMotion.measuring)
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.s) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(rate == nil ? Theme.Color.textSecondary : Theme.Color.accent)
                Text(rate.map { NumberText.string(Double($0), decimals: 0) } ?? "–")
                    .font(Theme.Font.display)
                    .foregroundStyle(rate == nil ? Theme.Color.textSecondary : Theme.Color.text)
                Text("BPM")
                    .font(Theme.Font.label)
                    .foregroundStyle(Theme.Color.textSecondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Pulse")
            .accessibilityValue(rate.map { "\($0) beats per minute" } ?? "Not measured")
            NoteText(sourceLine(measured: rate != nil))
            NoteText(ModulateMenu.measuringLine(measuring, sourceOn: strap.isOn || camera.isOn || health.isOn || phoneMotion.isOn))
            if showsSafety {
                // The safety line is the page's plainest text, not its smallest: body size, full colour.
                ParagraphText(BodySourceMenu.safetyLine)
            }
        }
    }

    private func sourceLine(measured: Bool) -> String {
        if strap.isOn {
            return measured ? "Heart Rate Strap: measuring." : "Heart Rate Strap: " + PulseReading.words(for: strap.status) + "."
        }
        if camera.isOn {
            return measured ? "Camera: pulse locked." : (CameraPulseCueLine.line(for: camera.status, cue: camera.cue) ?? "Camera: pulse locked.")
        }
        if health.isOn {
            return measured ? "Apple Health: a recent reading, for slow modulation only."
                : "Apple Health: " + PulseReading.words(for: health.status) + "."
        }
        return "Choose a body source: a fingertip on the rear camera and flash, or a heart rate strap."
    }
}

/// What Flow does right now, in a sentence: the page's one view that reads what Flow follows
/// (Law 6). It holds no control.
private struct FlowStatusLine: View {
    @Environment(FlowController.self) private var flow

    var body: some View {
        NoteText(Self.text(lock: flow.lock, canFlow: flow.canFlow, holdsForSharing: flow.holdsForSharing,
                           pulse: flow.shownPulse, target: flow.shownTarget))
    }

    static func text(lock: TempoLock, canFlow: Bool, holdsForSharing: Bool, pulse: Int?, target: Int?) -> String {
        guard canFlow else { return "A jam's host or a MIDI clock sets the tempo now, so Flow is off." }
        switch lock {
        case .fixed:
            return "The tempo stays where you set it."
        case .flow:
            guard !holdsForSharing else {
                return "Flow holds the tempo: a MIDI clock, a jam you host, OSC or the lights (Art-Net, sACN) carry it off this device, and Share Body Data is off. Turn it on under Connections and Flow follows your pulse again."
            }
            guard let pulse, let target else {
                return "Flow waits for a steady pulse. Then it moves the tempo one step per bar while the song plays."
            }
            return "Flow follows your pulse of " + NumberText.string(Double(pulse), decimals: 0, unit: "BPM")
                + " toward " + NumberText.string(Double(target), decimals: 0, unit: "BPM")
                + ", one step per bar while the song plays."
        }
    }
}

private extension View {
    /// A section of the page: a panel on `surface`, the earlier instrument's radius, full width.
    func card() -> some View {
        padding(Theme.Space.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.medium).fill(Theme.Color.surface))
    }
}
