import EchoelCore
import SwiftUI

/// The light show, pushed from Connections (CUES): the rig — generic fixtures patched on a
/// universe and a first channel, a patch onto taken channels refused with the reason — the cue
/// list with GO and Blackout, and where on the timeline each cue starts. Everything goes through
/// the store (Law 1); the panel reads cold song state, and the one value that moves while the
/// song plays, the live cue, is read by `LiveCueLine`, a leaf (Law 6).
struct LightShowView: View {
    @Environment(ProjectStore.self) private var store
    @Environment(ConnectionsController.self) private var connections
    @Environment(AudioEngine.self) private var engine
    @State private var refusal: String?
    @State private var exported: String?
    @State private var newUniverse = 1

    private var lighting: Lighting { store.project.lighting }

    var body: some View {
        List {
            outputSection
            fixturesSection
            cuesSection
            timelineSection
            exportSection
        }
        .echoelList()
        .numberPadHost()
        .navigationTitle("Light Show")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Output

    private var outputSection: some View {
        EchoelSection(footer: outputNote) {
            HStack(spacing: Theme.Space.m) {
                Button("GO") { connections.go(in: store.project) }
                    .buttonStyle(EchoelRowButtonStyle())
                    .disabled(lighting.cues.isEmpty)
                    .accessibilityLabel("Go")
                    .accessibilityHint("Starts the next cue, fading from what shows now.")
                Spacer(minLength: Theme.Space.s)
                LiveCueLine()
            }
            Toggle(isOn: Binding(get: { connections.blackout }, set: { connections.setBlackout($0) })) {
                Label("Blackout", systemImage: "lightbulb.slash")
                    .foregroundStyle(Theme.Color.text)
            }
            .accessibilityHint("Every light fades to dark; moving heads keep their position.")
        }
    }

    private var outputNote: String {
        var parts = ["The rig plays through the Art-Net and sACN connections on the page before; switch one on to send. Universe 1 is the universe set there, universe 2 the one after it."]
        parts.append("Every light changes at most three times a second, whatever a cue or GO asks; a fixture's own strobe channel stays off.")
        if lighting.fixtures.isEmpty { parts.append("Without fixtures, the connections light the one fixture they describe.") }
        return parts.joined(separator: " ")
    }

    // MARK: - Fixtures

    private var fixturesSection: some View {
        EchoelSection("Fixtures") {
            ForEach(lighting.fixtures) { fixture in
                NavigationLink {
                    FixturePatchView(fixtureID: fixture.id)
                } label: {
                    ValueRow(fixture.name, value: Self.patchText(fixture))
                }
                .accessibilityLabel("\(fixture.name), \(fixture.profile?.title ?? "Unknown profile")")
                .accessibilityValue(Self.patchText(fixture))
            }
            SettingField(title: "Universe for New Fixtures", value: newUniverse, range: PatchedFixture.universeRange,
                         standard: 1) { newUniverse = $0 }
            Menu {
                ForEach(FixtureProfile.allCases, id: \.self) { profile in
                    Button("\(profile.title) (\(profile.footprint) ch)") { add(profile) }
                }
            } label: {
                Label("Add Fixture", systemImage: "plus")
                    .foregroundStyle(Theme.Color.text)
                    .frame(minHeight: Theme.Size.touch)
            }
            if let refusal { NoteText(refusal, tone: .problem) }
        }
    }

    static func patchText(_ fixture: PatchedFixture) -> String {
        let profile = fixture.profile?.title ?? "Unknown"
        return "\(profile) · U\(fixture.universe) · \(fixture.channels.lowerBound)–\(fixture.channels.upperBound)"
    }

    private func add(_ profile: FixtureProfile) {
        guard let address = lighting.freeAddress(for: profile, in: newUniverse) else {
            refusal = "Universe \(newUniverse) has no \(profile.footprint) free channels in a row."
            return
        }
        let fixture = PatchedFixture(name: lighting.nextFixtureName(for: profile), profile: profile,
                                     universe: newUniverse, address: address)
        perform(.addFixture(fixture))
    }

    // MARK: - Cues

    private var cuesSection: some View {
        EchoelSection("Cues") {
            ForEach(lighting.cues) { cue in
                NavigationLink {
                    CueEditView(cueID: cue.id)
                } label: {
                    ValueRow(cue.name, value: Self.cueText(cue))
                }
                .accessibilityValue(Self.cueText(cue))
            }
            Button("Add Cue") { addCue() }
                .buttonStyle(EchoelRowButtonStyle())
                .accessibilityHint("A new cue with the values of the cue showing now.")
        }
    }

    static func cueText(_ cue: LightCue) -> String {
        let fade = cue.fade == 0 ? "Cut" : String(format: "%.1f s", cue.fade)
        return cue.followsSong ? "Song look · \(fade)" : fade
    }

    /// A snapshot: the new cue copies the values of the cue showing (else the last), so a look is
    /// built by changing what differs.
    private func addCue() {
        let source = connections.liveCue.flatMap { lighting.cue($0) } ?? lighting.cues.last
        let cue = LightCue(name: lighting.nextCueName(), fade: source?.fade ?? 0, look: source?.look,
                           values: source?.values ?? [])
        perform(.addCue(cue, index: nil))
    }

    // MARK: - Timeline

    private var timelineSection: some View {
        EchoelSection("On the Timeline",
                      footer: "A placed cue starts where it stands while the song plays and fades in from what was showing. Place a cue from its page, at the playhead.") {
            if lighting.placements.isEmpty { NoteText("No cue is placed yet.") }
            ForEach(lighting.placements, id: \.tick) { placement in
                placementRow(placement)
            }
        }
    }

    private func placementRow(_ placement: CuePlacement) -> some View {
        HStack(spacing: Theme.Space.m) {
            ValueRow(lighting.cue(placement.cue)?.name ?? "Cue", value: position(of: placement.tick))
            Button(role: .destructive) {
                perform(.removeCuePlacement(at: placement.tick))
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(EchoelRowButtonStyle())
            .accessibilityLabel("Remove from Timeline")
        }
    }

    private func position(of tick: Tick) -> String {
        let meter = store.project.meterMap
        let bar = meter.bar(at: tick) + 1
        let beatTicks = Swift.max(1, meter.ticksPerBeat(at: tick))
        let beat = (tick - meter.barStart(at: tick)) / beatTicks + 1
        return "Bar \(bar) · Beat \(beat)"
    }

    // MARK: - Export

    private var exportSection: some View {
        EchoelSection(footer: "The show as DMX, forty frames a second, every change as seconds, universe, channel and value. The same song always renders the same file; a song look follows the key and the beat, not the live mix.") {
            Button("Render DMX") {
                let project = store.project
                exported = LightShowRender.csv(LightShowRender.frames(of: project, duration: LightShowRender.duration(of: project)))
            }
            .buttonStyle(EchoelRowButtonStyle())
            .disabled(lighting.fixtures.isEmpty)
            if let exported {
                ShareLink("Share DMX (CSV)", item: exported)
            }
        }
    }

    private func perform(_ command: Command) {
        do {
            try store.perform(command)
            refusal = nil
        } catch CommandError.invalidValue(_, let reason) {
            refusal = reason
        } catch {
            refusal = "That change was refused."
        }
    }
}

/// The cue the show last started, as its own leaf: it changes while the song plays.
private struct LiveCueLine: View {
    @Environment(ConnectionsController.self) private var connections
    @Environment(ProjectStore.self) private var store

    var body: some View {
        let name = connections.liveCue.flatMap { store.project.lighting.cue($0)?.name }
        Text(name.map { "Showing \($0)" } ?? "No cue yet")
            .font(Theme.Font.caption)
            .foregroundStyle(Theme.Color.textSecondary)
            .lineLimit(1)
            .accessibilityLabel("Live Cue")
            .accessibilityValue(name ?? "None")
    }
}

/// One fixture: its universe and first channel, refused with the reason where they would share
/// channels with another fixture; its name; removal.
private struct FixturePatchView: View {
    let fixtureID: FixtureID
    @Environment(ProjectStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var refusal: String?
    @State private var name = ""

    var body: some View {
        List {
            if let fixture = store.project.lighting.fixture(fixtureID) {
                patchSection(fixture)
                EchoelSection {
                    Button("Remove Fixture", role: .destructive) {
                        try? store.perform(.removeFixture(fixtureID))
                        dismiss()
                    }
                    .buttonStyle(EchoelRowButtonStyle())
                }
            }
        }
        .echoelList()
        .numberPadHost()
        .navigationTitle(store.project.lighting.fixture(fixtureID)?.name ?? "Fixture")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { name = store.project.lighting.fixture(fixtureID)?.name ?? "" }
    }

    private func patchSection(_ fixture: PatchedFixture) -> some View {
        EchoelSection(footer: footer(fixture)) {
            TextField("Name", text: $name)
                .echoelInput()
                .submitLabel(.done)
                .onSubmit { patch(.renameFixture(fixtureID, name: name)) }
                .accessibilityLabel("Fixture Name")
            SettingField(title: "Universe", value: fixture.universe, range: PatchedFixture.universeRange, standard: 1,
                         drags: false) { patch(.patchFixture(fixtureID, universe: $0, address: fixture.address)) }
            SettingField(title: "First Channel", value: fixture.address,
                         range: 1...(PatchedFixture.channelRange.upperBound - fixture.footprint + 1), standard: 1,
                         drags: false) { patch(.patchFixture(fixtureID, universe: fixture.universe, address: $0)) }
            if let refusal { NoteText(refusal, tone: .problem) }
        }
    }

    private func footer(_ fixture: PatchedFixture) -> String {
        guard let profile = fixture.profile else {
            return "A profile from a later version (\(fixture.profileName)); it stays dark here and keeps channel \(fixture.address)."
        }
        let layout = profile.layout.map(Self.slotName).joined(separator: ", ")
        return "\(profile.title): \(profile.footprint) channels from \(fixture.address) — \(layout)."
    }

    static func slotName(_ slot: DMXSlot) -> String {
        switch slot {
        case .single(let attribute): attribute.title
        case .coarse(let attribute): "\(attribute.title) coarse"
        case .fine(let attribute): "\(attribute.title) fine"
        case .fixed: "Strobe rate (held off)"
        }
    }

    private func patch(_ command: Command) {
        do {
            try store.perform(command)
            refusal = nil
        } catch CommandError.invalidValue(_, let reason) {
            refusal = reason
        } catch {
            refusal = "That patch was refused."
        }
    }
}

/// One cue: its name, fade, look and every fixture's values, plus GO, placing it at the playhead
/// and deleting it. A value drag is one undo step.
private struct CueEditView: View {
    let cueID: CueID
    @Environment(ProjectStore.self) private var store
    @Environment(ConnectionsController.self) private var connections
    @Environment(AudioEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        List {
            if let cue = store.project.lighting.cue(cueID) {
                settingsSection(cue)
                ForEach(store.project.lighting.fixtures) { fixture in
                    fixtureSection(fixture, cue: cue)
                }
                actionsSection
            }
        }
        .echoelList()
        .numberPadHost()
        .navigationTitle(store.project.lighting.cue(cueID)?.name ?? "Cue")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { name = store.project.lighting.cue(cueID)?.name ?? "" }
    }

    private func settingsSection(_ cue: LightCue) -> some View {
        EchoelSection {
            TextField("Name", text: $name)
                .echoelInput()
                .submitLabel(.done)
                .onSubmit { edit { $0.name = name } }
                .accessibilityLabel("Cue Name")
            SettingField(title: "Fade", value: Int((cue.fade * 1_000).rounded()),
                         range: Int(LightCue.fadeRange.lowerBound * 1_000)...Int(LightCue.fadeRange.upperBound * 1_000),
                         unit: "ms", step: 100, standard: 0, spokenUnit: "milliseconds",
                         commit: { milliseconds in edit(key: "fade") { $0.fade = Double(milliseconds) / 1_000 } },
                         ended: { store.endGesture() })
            Picker("Look", selection: Binding(get: { cue.followsSong }, set: { song in edit { $0.look = song ? LightCue.songLook : nil } })) {
                Text("Snapshot").tag(false)
                Text("Song (key colour, level, beat)").tag(true)
            }
            .pickerStyle(.menu)
        }
    }

    private func fixtureSection(_ fixture: PatchedFixture, cue: LightCue) -> some View {
        EchoelSection(fixture.name) {
            ForEach(fixture.profile?.attributes ?? [], id: \.self) { attribute in
                attributeField(attribute, fixture: fixture, cue: cue)
            }
            if cue.followsSong { NoteText("The song lights this fixture; its position comes from here.") }
        }
    }

    @ViewBuilder
    private func attributeField(_ attribute: LightAttribute, fixture: PatchedFixture, cue: LightCue) -> some View {
        let stored = cue.value(attribute, of: fixture.id) ?? attribute.restValue
        let title = "\(fixture.name) \(attribute.title)"
        if attribute.isSixteenBit {
            SettingField(title: title, value: Int(DMXWord.word(stored)), range: 0...65_535, standard: 32_768,
                         commit: { word in setValue(attribute, of: fixture.id, to: DMXWord.value(UInt16(clamping: word))) },
                         ended: { store.endGesture() })
        } else {
            SettingField(title: title, value: Int((stored * 100).rounded()), range: 0...100, unit: "%", standard: 0,
                         spokenUnit: "percent",
                         commit: { percent in setValue(attribute, of: fixture.id, to: Double(percent) / 100) },
                         ended: { store.endGesture() })
        }
    }

    private var actionsSection: some View {
        EchoelSection {
            Button("GO This Cue") { connections.go(to: cueID, in: store.project) }
                .buttonStyle(EchoelRowButtonStyle())
            Button("Place at Playhead") {
                let tick = engine.playheadTick(in: store.project)
                try? store.perform(.placeCue(cueID, at: tick))
            }
            .buttonStyle(EchoelRowButtonStyle())
            Button("Delete Cue", role: .destructive) {
                try? store.perform(.removeCue(cueID))
                dismiss()
            }
            .buttonStyle(EchoelRowButtonStyle())
        }
    }

    private func setValue(_ attribute: LightAttribute, of fixture: FixtureID, to value: Double) {
        guard let cue = store.project.lighting.cue(cueID) else { return }
        try? store.perform(.setCue(cue.setting(attribute, of: fixture, to: value)),
                           coalescingKey: "cue.\(cueID).\(fixture).\(attribute.rawValue)")
    }

    private func edit(key: String? = nil, _ change: (inout LightCue) -> Void) {
        guard var cue = store.project.lighting.cue(cueID) else { return }
        change(&cue)
        try? store.perform(.setCue(cue), coalescingKey: key.map { "cue.\(cueID).\($0)" })
    }
}
