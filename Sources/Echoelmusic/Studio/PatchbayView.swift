#if canImport(SwiftUI)
import SwiftUI

// PatchbayView.swift
// Echoel — the universal routing patchbay made visible. Each SOURCE lists the
// DESTINATIONS it can reach (same type directly, or via a converter like
// pitch→colour); tap to connect/disconnect. "Smart patch" applies every sensible
// connection at once. Honest: each endpoint shows its transport status (live vs
// soon), and the note explains which edges move bytes today. Binds to SignalRouter
// (persisted). See docs/dev/DMMW_ARCHITECTURE.md + Core/SignalRouting.swift.

@MainActor
struct PatchbayView: View {

    @Environment(SignalRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    #if canImport(Network)
    @Environment(OSCSender.self) private var osc
    /// #1255 — the OSC control INPUT; its switch below is the ONE door to the socket.
    @Environment(OSCReceiver.self) private var oscIn
    /// Declared via `StudioDefaultKeys` (one key string, one default); the socket reads the
    /// SAME key in `OSCReceiver.applyPreference()`, the `networkMIDI` shape.
    @AppStorage(StudioDefaultKeys.oscInEnabled.key)
    private var oscInEnabled = StudioDefaultKeys.oscInEnabled.value

    /// #1292 — the clinical HRV statistics on the OSC bio stream. OFF on a fresh install;
    /// `StudioDefaultKeys` owns the key and the default (H15-KEYSTORE, two readers).
    @AppStorage(StudioDefaultKeys.oscClinicalDetail.key)
    private var oscClinicalDetail = StudioDefaultKeys.oscClinicalDetail.value
    @Environment(ADMOSCSender.self) private var admOSC
    @Environment(ArtNetSender.self) private var artNet
    @Environment(SACNSender.self) private var sacn
    #endif

    #if os(iOS) && canImport(CoreMIDI)
    /// #187 — the inbound RTP-MIDI switch. Declared via `StudioDefaultKeys` so the
    /// key string and the default-OFF literal live in one place (H15-KEYSTORE); the
    /// engine reads the SAME key in `MIDIInput.applyNetworkSessionPreference()`.
    @AppStorage(StudioDefaultKeys.networkMIDI.key)
    private var networkMIDI = StudioDefaultKeys.networkMIDI.value

    /// #713 — the two MIDI-OUT quality switches. Same shape as `networkMIDI` above: the key
    /// string and the default-OFF literal live once in `StudioDefaultKeys`, and the engine
    /// reads the SAME keys in `MIDIOutput.applyOutputPreferences()`.
    @AppStorage(StudioDefaultKeys.midiOutMPE.key)
    private var midiOutMPE = StudioDefaultKeys.midiOutMPE.value

    @AppStorage(StudioDefaultKeys.midiOutExpression.key)
    private var midiOutExpression = StudioDefaultKeys.midiOutExpression.value
    @AppStorage(StudioDefaultKeys.midiOutUMP2.key)
    private var midiOutUMP2 = StudioDefaultKeys.midiOutUMP2.value

    /// The live MIDI-out engine, injected at the app root (`EchoelmusicApp`, `.environment`).
    /// Read only to APPLY the two switches above; the flags themselves are never assigned
    /// from here, so this surface never becomes a second lifecycle owner (the BLE-3 lesson).
    ///
    /// Declared INSIDE this guard, next to its only users, rather than beside `router`: an
    /// `@Environment(Type.self)` with no injected value traps when it is READ, so keeping the
    /// declaration and the reads under one condition means there is no platform on which this
    /// view can compile with a lookup it cannot satisfy.
    @Environment(MIDIOutput.self) private var midiOut
    /// #1250 — the modulation MATRIX's first surface. Injected app-wide (`EchoelmusicApp`),
    /// read ONLY for `matrix` (written on edits) — never `lastOutputs` (~1 Hz), which would
    /// enrol this whole sheet as an observer of the modulation tick (10.76.41/50 class).
    @Environment(ModulationEngine.self) private var modulationEngine
    #endif

    /// `true` when hosted as a workspace surface rather than a sheet.
    var embedded = false

    var body: some View {
        if embedded {
            content
        } else {
            NavigationStack {
                content
                    .navigationTitle("Routing")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                    }
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                headerBar
                #if canImport(Network)
                networkOutSection
                lichtSection
                // #1255 — the one inbound socket, beside the outputs it answers.
                oscInSection
                #endif
                #if os(iOS) && canImport(CoreAudioKit)
                // The NavigationLink push needs the enclosing NavigationStack, which only
                // exists on the sheet (non-embedded) path — so gate it to !embedded (no
                // dead control in the dormant workspace path).
                if !embedded { bluetoothMIDISection }
                #endif
                #if os(iOS) && canImport(CoreMIDI)
                // Mounted unconditionally: it is a Toggle, not a NavigationLink push, so
                // unlike `bluetoothMIDISection` it needs no enclosing NavigationStack and
                // is correct on the embedded path too. Defensive rather than a live fix —
                // `PatchbayView(embedded:)` has no caller today — but a control that only
                // works on one of two hosts is exactly how a door goes missing again.
                networkMIDISection
                midiOutSection
                #endif
                // #1250 — Body → parameter. The founder's "Verknüpfung mit der Routing Matrix":
                // the ONE place a modulation route is authored. Mounted unconditionally (a
                // Toggle/Picker card, no NavigationLink), before the transport source cards.
                modulationSection
                ForEach(router.graph.sources) { src in
                    sourceCard(src)
                }
                Text("Tap a destination to route a source to it. Compatible types connect directly or via a converter (e.g. pitch→colour, bio→MIDI CC). Light and spatial follow the music live today; other edges are authored here as their adapters come online.")
                    .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
        }
        .background(EchoelTheme.bg)
    }

    #if os(iOS) && canImport(CoreAudioKit)
    // MARK: - Bluetooth MIDI (B6: pair a wireless controller — plays the synth directly)
    /// A titled card (same grammar as `lichtSection`) with a single push to Apple's
    /// built-in BLE-MIDI central. A NavigationLink PUSH — not a `.sheet`/`.fullScreenCover`
    /// — so `EchoelStudioView`'s modal metadata chain does not grow. A paired controller
    /// becomes a CoreMIDI source that `MIDIInput` auto-connects → real synth notes.
    private var bluetoothMIDISection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bluetooth MIDI").font(EchoelTheme.font(11, .bold)).foregroundStyle(EchoelTheme.dim)
            NavigationLink {
                BluetoothMIDIPairingView()
                    .navigationTitle("Bluetooth MIDI")
                    .navigationBarTitleDisplayMode(.inline)
                    .ignoresSafeArea()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "pianokeys").font(.system(size: 13)).foregroundStyle(EchoelTheme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pair a controller")
                            .font(EchoelTheme.font(14, .semibold)).foregroundStyle(EchoelTheme.text)
                        Text("Pair a wireless MIDI keyboard or controller — it plays the synth directly.")
                            .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(EchoelTheme.dim)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: EchoelTheme.radius).fill(EchoelTheme.fill))
                .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius).strokeBorder(EchoelTheme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Pair a Bluetooth MIDI controller")
            .accessibilityHint("Opens Apple's Bluetooth MIDI pairing. A paired controller plays the synth directly.")
        }
    }
    #endif

    #if os(iOS) && canImport(CoreMIDI)
    // MARK: - Network MIDI (#187: the inbound listener gets a switch, default OFF)
    /// The one control for Apple's RTP-MIDI session. It sits in Routing rather than
    /// anywhere in the instrument because it is a ROUTE, not a sound — and because
    /// this surface is reachable (master panel → "Routing"), which is the whole point:
    /// until this shipped, the session was armed at launch on every install with no
    /// control anywhere. A capability with no switch is not a feature, and an inbound
    /// network listener with no switch is not a default anyone chose.
    ///
    /// `Toggle`, not `EchoelValueField`: the app-wide field law covers adjustable
    /// NUMERIC parameters. This is a binary route on/off, same grammar as the other
    /// route switches on this surface.
    private var networkMIDISection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Network MIDI").font(EchoelTheme.font(11, .bold)).foregroundStyle(EchoelTheme.dim)
            VStack(alignment: .leading, spacing: 6) {
                // COPY IS DELIBERATELY TWO-DIRECTIONAL (corrected 2026-07-28). The label
                // read "Receive wireless MIDI" and the off-state promised only that no
                // INCOMING session is accepted. That understates the switch: disabling
                // `MIDINetworkSession` withdraws the network endpoint as a CoreMIDI
                // DESTINATION too, and `MIDIOutput.send` fans out to every destination —
                // so wireless MIDI OUT to a Mac stops as well. A control that names half
                // of what it does is the repo's own "lying control" class; the rationale
                // in MIDIInput being framed as inbound-only is what led the copy astray.
                Toggle(isOn: $networkMIDI) {
                    Text("Wireless MIDI session")
                        .font(EchoelTheme.font(14, .semibold)).foregroundStyle(EchoelTheme.text)
                }
                .tint(EchoelTheme.accent)
                .accessibilityHint(networkMIDI
                    ? "On. Any device on your local network can open a MIDI session with this iPhone, and this iPhone can send MIDI out over the network."
                    : "Off. No wireless MIDI session in either direction.")
                Text(networkMIDI
                     ? "This iPhone accepts a MIDI session from any device on your local network — a Mac's Network MIDI, rtpMIDI, or a compatible app — and appears to them as a wireless MIDI destination. Turn it off when you are on a network you do not control."
                     : "Off. This iPhone does not announce itself for wireless MIDI: no incoming session is accepted, and it no longer appears as a wireless MIDI destination, so MIDI out over the network stops too. Turn it on to play the instrument from a Mac, or to play a Mac from here, over the network.")
                    .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: EchoelTheme.radius).fill(EchoelTheme.fill))
            .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius).strokeBorder(EchoelTheme.border, lineWidth: 1))
            // Apply on change, from the SAME entry point launch uses, so the switch
            // and the live session can never disagree. @AppStorage has already written
            // the key by the time this fires.
            .onChange(of: networkMIDI) { _, _ in MIDIInput.applyNetworkSessionPreference() }
        }
    }

    // MARK: - MIDI out quality (#713: the two switches the Tools-grid removal took)

    /// The MPE layout and per-note expression switches for the OUTBOUND stream.
    ///
    /// WHY IT IS HERE. `MIDIOutput.mpeEnabled` and `.expressionEnabled` gate live code — the
    /// zone RPN when the port opens, and the Glide/Slide/Press bytes that ride with each
    /// note-on — and both lost their only control when the Tools grid was removed. Until this
    /// section a player routing to a hardware rig got plain channel-1 notes with no way to ask
    /// for anything else. (⛔ #713 dated that removal as a fact; the clone is shallow and cannot
    /// show it — the measured part is that no control existed anywhere. #714 finding F.) `networkMIDISection` above states the rule
    /// this follows: a capability with no switch is not a feature. Routing is the right home
    /// because these describe the OUTBOUND stream, not a sound.
    ///
    /// `Toggle`, not `EchoelValueField`: the app-wide field law covers adjustable NUMERIC
    /// parameters, and these are binary, exactly like the switch above.
    ///
    /// ⚠️ THE SECOND SWITCH IS DISABLED WHILE THE FIRST IS OFF, and that is the honesty half
    /// of this slice rather than polish. `MIDIOutput`'s send path reads
    /// `if mpeEnabled, expressionEnabled` — per-note bend and pressure need a member channel
    /// per note — so an expression switch that could be turned on alone would move, persist
    /// and change nothing. Disabled and visible beats hidden: the dependency is the thing a
    /// player needs to understand, and hiding the row would make it a mystery instead.
    private var midiOutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MIDI out").font(EchoelTheme.font(11, .bold)).foregroundStyle(EchoelTheme.dim)
            VStack(alignment: .leading, spacing: 6) {
                Toggle(isOn: $midiOutMPE) {
                    Text("MPE note layout")
                        .font(EchoelTheme.font(14, .semibold)).foregroundStyle(EchoelTheme.text)
                }
                .tint(EchoelTheme.accent)
                .accessibilityHint(midiOutMPE
                    ? "On. Notes are spread across the MPE member channels, so a rig can bend and press each note on its own."
                    : "Off. Every note is sent on channel 1.")

                Toggle(isOn: $midiOutExpression) {
                    Text("Per-note expression")
                        .font(EchoelTheme.font(14, .semibold)).foregroundStyle(EchoelTheme.text)
                }
                .tint(EchoelTheme.accent)
                .disabled(!midiOutMPE)
                .accessibilityHint(midiOutMPE
                    ? (midiOutExpression
                       ? "On. Each note carries the body's live Glide, Slide and Press."
                       : "Off. Notes are sent without per-note expression.")
                    : "Unavailable while MPE note layout is off, because per-note expression needs one channel per note.")

                Text(midiOutMPE
                     ? (midiOutExpression
                        ? "Notes go out across the MPE member channels, each carrying the body's live Glide, Slide and Press. Point it at an MPE synth or a DAW track."
                        : "Notes go out across the MPE member channels. Turn on per-note expression to send the body's Glide, Slide and Press with each note.")
                     : "Every note goes out on channel 1 — what any MIDI device understands. Turn on the MPE note layout to give each note its own channel; per-note expression needs that and stays unavailable until then.")
                    .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                    .fixedSize(horizontal: false, vertical: true)

                // ⛔ #713 SHIPPED THE THREE SENTENCES ABOVE WITHOUT THIS ONE, and they say
                // "notes go out" unconditionally. Nothing goes out unless the `midi.out` sink
                // is routed below — `MIDIOutput.noteOn` guards on `enabled`, which only
                // `applyRouting()` sets. With the route off, both switches move, persist,
                // change the engine flags and change NO byte: the same lying-control class the
                // `.disabled(!midiOutMPE)` above exists to prevent, one level out (#714).
                //
                // A sentence rather than `.disabled(!midiOut.enabled)`: the disabled form would
                // read an engine property in `body`, and this surface deliberately touches
                // `midiOut` only inside `.onChange` so it registers no observation at all.
                Text("Both need the MIDI out route switched on below — without it nothing is sent, whatever these say.")
                    .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                    .fixedSize(horizontal: false, vertical: true)

                // #1253 — the MIDI 2.0 source. A named binary → Toggle. Independent of MPE:
                // it mirrors whatever the 1.0 source carries, member channels included.
                Toggle(isOn: $midiOutUMP2) {
                    Text("MIDI 2.0 source")
                        .font(EchoelTheme.font(14, .semibold)).foregroundStyle(EchoelTheme.text)
                }
                .tint(EchoelTheme.accent)
                .accessibilityHint(midiOutUMP2
                    ? "On. A second source, Echoelmusic (MIDI 2.0), carries the same notes with 16-bit velocity and 32-bit bend and controllers."
                    : "Off. Only the MIDI 1.0 source is offered to hosts.")
                Text(midiOutUMP2
                     ? "Hosts now also see “Echoelmusic (MIDI 2.0)” — the same notes, widened to MIDI 2.0. Record from ONE of the two sources, or you get every note twice."
                     : "Turn on to offer hosts a second, MIDI 2.0 source (16-bit velocity, 32-bit bend and controllers) beside the MIDI 1.0 one. Hardware keeps receiving MIDI 1.0.")
                    .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: EchoelTheme.radius).fill(EchoelTheme.fill))
            .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius).strokeBorder(EchoelTheme.border, lineWidth: 1))
            // Apply from the SAME entry point launch uses, so the switch and the live engine
            // can never disagree — the `networkMIDISection` pattern. @AppStorage has already
            // written the key by the time this fires.
            .onChange(of: midiOutMPE) { _, _ in midiOut.applyOutputPreferences() }
            .onChange(of: midiOutExpression) { _, _ in midiOut.applyOutputPreferences() }
            .onChange(of: midiOutUMP2) { _, _ in midiOut.applyOutputPreferences() }
        }
    }

    #endif


    // MARK: - Body → parameter (#1250: the modulation matrix's surface)

    /// Founder 2026-09-11: *"Eine Verknüpfung mit der Routing Matrix ist auch klar."*
    /// Before this the matrix ran at launch, persisted, streamed `/echoelmusic/mod/<key>`
    /// — and had ZERO production constructions of `ModRoute(` (#541): a route could only
    /// come from an older build's document. This card authors them.
    ///
    /// Shape borrowed from `FXModRouteRow` (the FX panel's bio→FX rows): Toggle · source
    /// Picker (filtered on `hasProducer` — a channel whose answer is permanently "no" is a
    /// control that lies — unioned with the route's own so a persisted dropped channel still
    /// renders) · destination Picker over `ModDestinationKey.all` (unioned the same way) ·
    /// `EchoelValueField` for the NUMERIC depth and smoothing · curve Picker · Invert.
    ///
    /// ⭐ #1391 — THE LIST GREW FROM ONE TO TWELVE and the copy moved with it (#456). The
    /// destinations are the tempo plus `PolySynthVoice.automatableBases`, registered in
    /// `EchoelmusicApp` from what `ParameterApplyRouter` actually bound. The empty state is
    /// what a first-run player reads (nothing in production constructs a `ModRoute` for them),
    /// so „this build offers one: the tempo" was the sentence that had to move first.
    /// Every edit persists via `save()`; the engine reads `matrix.routes` on its next
    /// applied frame, so a new route is live within ~1 s with no restart.
    ///
    /// ⛔ #1324 — THREE REFERENCES HERE OUTLIVED THE THINGS THEY NAMED, and the worst of them
    /// was on SCREEN. #1249 registered four VOICE-STAGE destinations beside the tempo; #1302
    /// deleted the monitor insert they wrote to, so `ModDestinationKey.all` has read `[tempo]`
    /// ever since — measured, not assumed:
    ///   grep -n "static let all" Sources/Echoelmusic/Core/ModulationEngine.swift
    /// Yet the empty state still offered „or a stage on your voice", the footer still told the
    /// player that „voice stages need their switch on in Audio input" (a surface deleted by the
    /// same commit, tombstoned at `EchoelStudioView.swift`), and the verify note below asked the
    /// founder for a device session that CANNOT be run: it routes to „Voice · harmony mix" with
    /// „Harmony im Input-Sheet AN", and the harmonizer went with #1305, the sheet with #1302.
    /// The empty state is what a first-run player reads (nothing in production constructs a
    /// `ModRoute`, so it IS the default state), and the footer renders UNCONDITIONALLY.
    ///
    /// A tempo route is SUPPRESSED while the BPM lock is on and glides otherwise — the guard is
    /// the first line of `EchoelmusicApp`'s `register(ModDestinationKey.tempo)` handler, and this
    /// is the T1 source `.modulationRoute`. (⚠️ The OSC `bpm` cue is the MIRROR of this: applied
    /// ONLY under the lock. Two inbound tempo paths, opposite gates — do not „unify" them.)
    /// NEEDS-FOUNDER-VERIFY: Master → Routing → „Body → parameter" → Add route → Tempo,
    /// Quelle Coherence, Depth 1, BPM-Lock AUS: das Tempo muss der Kohärenz folgen (Log:
    /// `/echoelmusic/mod/seq.tempo` bei OSC an). Lock AN: das Tempo darf sich NICHT bewegen.
    /// App neu starten — die Route ist noch da.
    /// Zweite Probe, seit #1391 zwoelf Ziele statt einem: Add route → „Warmth drive",
    /// Quelle Coherence, Depth 1 — der Klang muss mit der Kohaerenz rauher und wieder
    /// sauberer werden, ohne dass das Tempo sich bewegt (zwei Routen sind unabhaengig).
    @ViewBuilder
    private var modulationSection: some View {
        @Bindable var engine = modulationEngine
        VStack(alignment: .leading, spacing: 8) {
            Text("Body → parameter").font(EchoelTheme.font(11, .bold)).foregroundStyle(EchoelTheme.dim)
            VStack(alignment: .leading, spacing: 10) {
                if engine.matrix.routes.isEmpty {
                    Text("No routes yet. A route lets one measured channel of your body move one parameter of the instrument \u{2014} the tempo, or any sound parameter automation can reach.")
                        .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach($engine.matrix.routes) { $route in
                    ModulationRouteRow(route: $route) {
                        engine.matrix.routes.removeAll { $0.id == route.id }
                        engine.save()
                    }
                }
                Menu {
                    ForEach(ModDestinationKey.all, id: \.self) { key in
                        Button(ModDestinationKey.displayName(key)) {
                            engine.matrix.routes.append(ModRoute(source: .coherence,
                                                                 destination: ModDestination(key)))
                            engine.save()
                        }
                    }
                } label: {
                    Label("Add route", systemImage: "plus")
                        .font(EchoelTheme.font(12, .semibold)).foregroundStyle(EchoelTheme.text)
                        .padding(.horizontal, 12).frame(minHeight: 34)
                        .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius)
                            .strokeBorder(EchoelTheme.border, lineWidth: 1))
                }
                .accessibilityHint("Adds a route from your coherence to the chosen parameter; change the source in the row.")
                Text("Routes apply about once a second from the measured body and are kept across launches. A route OWNS its parameter while it is enabled \u{2014} the body sets the value, so a route on the level sets the level. Bio min and Bio max are the part of the channel's range the route spans: coherence usually sits between about 0.30 and 0.60, so setting those two makes the parameter travel its whole way instead of a third of it. A tempo route glides, and does nothing while the BPM lock is on. Every applied value also leaves as /echoelmusic/mod/<key> when OSC out is routed.")
                    .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: EchoelTheme.radius).fill(EchoelTheme.fill))
            .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius).strokeBorder(EchoelTheme.border, lineWidth: 1))
            // Field/Picker edits write through the bindings; persist on ANY change so the
            // route survives a relaunch — the engine's `save()` doc names the routing UI as
            // its caller.
            .onChange(of: engine.matrix.routes) { _, _ in engine.save() }
        }
    }

    #if canImport(Network)
    // MARK: - OSC control input (#1255)

    /// The opt-in for the app's ONE inbound socket. A Toggle (named binary), the port and the
    /// sender allowlist as the same fields the outputs use, a status leaf, and the whitelist
    /// spelled out — an operator must be able to read from this card what a cue can and cannot
    /// do. The status line is a LEAF (`OSCInputStatusLine`): `lastReceivedTimestamp` moves per
    /// cue, and this body hosts the port `TextField`s (the 10.76.50 law).
    private var oscInSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("OSC input · control").font(EchoelTheme.font(11, .bold)).foregroundStyle(EchoelTheme.dim)
            Toggle(isOn: $oscInEnabled) {
                Text("Accept OSC control")
                    .font(EchoelTheme.font(14, .semibold)).foregroundStyle(EchoelTheme.text)
            }
            .tint(EchoelTheme.accent)
            .accessibilityHint(oscInEnabled
                ? "On. One UDP port is open for the control cues listed below, from the senders you allow."
                : "Off. No socket is open; Echoel sends only.")
            OSCInputStatusLine(receiver: oscIn)
            TextField("Allowed sender IPs, comma-separated (empty = any)", text: oscInAllowedHosts)
                .textFieldStyle(.plain)
                .font(EchoelTheme.font(13).monospacedDigit())
                .padding(.horizontal, 10).frame(minHeight: 34)
                .background(RoundedRectangle(cornerRadius: EchoelTheme.radius).fill(EchoelTheme.bg))
                .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius).strokeBorder(EchoelTheme.border, lineWidth: 1))
                #if os(iOS)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                #endif
            EchoelValueField(label: "Port", value: oscInPort, range: 1...65_535, unit: "", decimals: 0)
            Text(oscInEnabled
                 ? "Listening for /echoelmusic/ctrl/bpm (only while the BPM is locked) · key 0–11 · scale · genre · visualStyle 0–9 · blackout 0/1. No bio value and no play/stop is accepted from the network. Turn it off on a network you do not control."
                 : "Turn on to let TouchDesigner, Resolume, QLab or a console send cues: /echoelmusic/ctrl/bpm (locked only) · key · scale · genre · visualStyle · blackout. Nothing else is accepted, and no socket is open while this is off.")
                .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: EchoelTheme.radius).fill(EchoelTheme.surface))
        .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius).strokeBorder(EchoelTheme.border, lineWidth: 1))
        .onChange(of: oscInEnabled) { _, _ in oscIn.applyPreference() }
    }

    private var oscInAllowedHosts: Binding<String> {
        Binding(get: { oscIn.allowedHosts }, set: { oscIn.allowedHosts = $0 })
    }
    private var oscInPort: Binding<Float> {
        Binding(get: { Float(oscIn.port) }, set: { oscIn.port = Self.clampPort($0) })
    }

    // MARK: - Netzwerk-Ausgabe (rank #1: OSC / ADM-OSC / sACN / Art-Net target config)

    /// Host + port (+ universe) per network output, so the founder can point OSC/ADM at
    /// Resolume/TouchDesigner/MadMapper and sACN/Art-Net at the right light node instead
    /// of only localhost/broadcast. Values persist (UserDefaults in each sender) and a
    /// live edit reconnects immediately. Flat rows (no card-in-card, Uncodixfy).
    ///
    /// ⛔ THIS LINE SAID the dot is "whether that output is currently sending (low-frequency
    /// isActive — freeze-safe)". Both halves were wrong in opposite directions and they
    /// cancelled each other out in review: `isActive` is indeed low-frequency, but it is set one
    /// line after `connect()` and therefore never meant "sending" at all. Since #996 the dot
    /// reads `lastSentTimestamp`, which DOES mean a datagram left the device — and is stamped at
    /// up to ~30 Hz, so it is freeze-safe only because `NetworkOutputHeader` is a leaf. The
    /// safety moved from the value to the placement, which is why the sentence had to move too.
    private var networkOutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Network output").font(EchoelTheme.font(11, .bold)).foregroundStyle(EchoelTheme.dim)
            outputRow("OSC", sender: osc, host: oscHost, port: oscPort)
            outputRow("ADM-OSC", sender: admOSC, host: admHost, port: admPort)
            outputRow("sACN · Light", sender: sacn, host: sacnHost, port: sacnPort,
                      universe: sacnUniverse, universeRange: 1...63_999)
            outputRow("Art-Net · Light", sender: artNet, host: artNetHost, port: artNetPort,
                      universe: artNetUniverse, universeRange: 0...32_767)
            // #1219 — the OS's refusal, if any. `lastError` moves only on a state change or a
            // refused send, never per tick: a cold read for this host body.
            if let artNetError = artNet.lastError {
                Text(artNetError)
                    .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Divider().overlay(EchoelTheme.border)
            // ⛔ #1333 — BOTH LINES BELOW LISTED `gesture` AS PART OF THE DEFAULT STREAM, and
            // #1301 deleted every producer of it (the face/body channels, founder 2026-09-12,
            // "Face und Audio Input komplett entfernen"). Measured: `git grep -n "/gesture"
            // -- Sources` finds nothing. One of the two was the VoiceOver hint, so the claim
            // was also the only version a non-sighted operator got. They now name
            // `/echoelmusic/bio/synthetic` instead — an address that really does accompany
            // every value-carrying tick (#639) — and the pNN50 unit, per #1329.
            Toggle(isOn: $oscClinicalDetail) {
                Text("Send clinical HRV detail")
                    .font(EchoelTheme.font(14, .semibold)).foregroundStyle(EchoelTheme.text)
            }
            .tint(EchoelTheme.accent)
            .accessibilityHint(oscClinicalDetail
                ? "On. rMSSD and SDNN in milliseconds and pNN50 as a percentage ride the OSC stream alongside the musical controls."
                : "Off. The OSC stream carries the musical controls only — heart rate, normalized HRV, coherence and breath, each tagged with whether the body is real or the demo.")
            Text(oscClinicalDetail
                 ? "On: /echoelmusic/bio/heart/rmssd and /sdnn (milliseconds) and /pnn50 (0–100 %) are sent as well. Use this for analysis in TouchDesigner, Max or a research patch — turn it off on a network you do not control."
                 : "Off: the stream carries what the instrument plays — /heart/bpm, /heart/hrv (0–1), /coherence, /breath/*, /synthetic. The three time-domain HRV statistics in medical units stay on this device until you ask for them.")
                .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                .fixedSize(horizontal: false, vertical: true)
            Text("Target IP + port per output — changes take effect immediately while the output is running. OSC/ADM default to 'localhost' (this device); for Resolume · TouchDesigner · MadMapper enter the target computer's IP. Art-Net and sACN send unicast to the node IP you enter (default 192.168.1.100) — the app holds no broadcast entitlement, so 255.255.255.255 reaches nothing on iOS.")
                .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: EchoelTheme.radius).fill(EchoelTheme.fill))
        .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius).strokeBorder(EchoelTheme.border, lineWidth: 1))
        .onChange(of: oscClinicalDetail) { _, _ in osc.applyEgressPreferences() }
    }

    private func outputRow(_ name: String, sender: any NetworkSendActivity,
                           host: Binding<String>, port: Binding<Float>,
                           universe: Binding<Float>? = nil,
                           universeRange: ClosedRange<Float> = 1...63_999) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // ⭐ THE DOT MOVED INTO ITS OWN LEAF (#996, audit item 16), and it now means
            // something. It used to render `isActive`, which every sender sets ONE LINE after
            // `connect()` — so it read "sending" with the engine stopped and no publisher
            // running, and the OSC row read "sending" for a whole session while
            // `BioEgressPolicy` refused every HealthKit-sourced frame. It fired exactly where
            // recovery is impossible: on stage, before doors.
            //
            // `NetworkOutputHeader` reads `lastSentTimestamp` instead — a value all four
            // senders already stamp and NOBODY read. It has to be a leaf: that property moves
            // at up to ~30 Hz on an `@Observable`, and reading it in this body would subscribe
            // the host/port `TextField`s and the resolution `Picker` to a 30 Hz signal (the
            // 10.76.50 menu freeze), on the surface an operator uses mid-show.
            //
            // ⛔ THE COLOUR-BLINDNESS FIX FROM 2026-07-29 TRAVELLED WITH IT rather than being
            // re-derived: filled / hollow was shape-not-colour on purpose, and the third state
            // needed a third SHAPE (a ring), not a third colour. The note explaining why lives
            // in the leaf now, beside the code it describes.
            NetworkOutputHeader(name: name, sender: sender)
            TextField("IP / host", text: host)
                .textFieldStyle(.plain)
                .font(EchoelTheme.font(13).monospacedDigit())
                .padding(.horizontal, 10).frame(minHeight: 34)
                .background(RoundedRectangle(cornerRadius: EchoelTheme.radius).fill(EchoelTheme.bg))
                .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius).strokeBorder(EchoelTheme.border, lineWidth: 1))
                #if os(iOS)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                #endif
            pairedRow(spacing: 8) {
                EchoelValueField(label: "Port", value: port, range: 1...65_535, unit: "", decimals: 0)
            } second: {
                if let universe {
                    EchoelValueField(label: "Universe", value: universe, range: universeRange, unit: "", decimals: 0)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(name) — network target")
    }

    /// ⭐ #1026 — TWO CONTROLS ON ONE LINE, BUT ONLY WHILE THEY FIT.
    ///
    /// THE DEFECT, measured rather than reasoned (founder screenshot of build 452, portrait):
    /// this sheet was cut on BOTH sides — "onnections" for "Connections", the port and universe
    /// boxes running off the right edge. `EchoelValueField`'s own doc says why, and has since
    /// #353e: the labelled row is `HStack { Text(label); Spacer(minLength: 8); valueBox }` and
    /// the box is **PINNED** to `valueWidth` (150 pt at the default text size, `@ScaledMetric`
    /// so it grows with Dynamic Type). "A `.frame(width:)` is a pin and does not compress."
    ///
    /// Two labelled fields side by side therefore demand `label + 8 + 150` EACH plus the
    /// spacing — roughly 410 pt before the sheet's own 12 pt padding, against ~369 pt of usable
    /// width on a 393 pt phone. A vertical `ScrollView` does not clip an over-wide child, it
    /// CENTRES it, so the overflow is split between the two edges and the whole sheet — header
    /// included — reads as shifted. That is exactly the screenshot.
    ///
    /// ⛔ AND IT IS NOT AN ORIENTATION PROBLEM, which is what I claimed one build earlier. The
    /// founder rotated the phone and reported back: *"Queer war doch alles gut. Nur hochkant
    /// war nicht passend."* Landscape was fine; PORTRAIT was broken. I had inferred the cause
    /// from a screen recording instead of measuring the rows, and the recording's rotated frames
    /// made a wrong story look complete. #1025's width ceiling was never this defect's repair
    /// (⛔ "is kept — it is inert in portrait and still right for iPad · Mac · Vision" stood
    /// here from #1026; #1027 REMOVED that ceiling on founder order the same day — every view
    /// fills the screen — and this line was not moved with it; #1106).
    ///
    /// THE FIX IS THE ONE SwiftUI ALREADY HAS. `ViewThatFits` takes the horizontal row when the
    /// proposed width can hold it and the stacked column when it cannot, per device and per text
    /// size, with no threshold to guess and no geometry read. On a wide canvas nothing changes.
    @ViewBuilder
    private func pairedRow<A: View, B: View>(spacing: CGFloat,
                                             @ViewBuilder _ first: () -> A,
                                             @ViewBuilder second: () -> B) -> some View {
        let a = first()
        let b = second()
        ViewThatFits(in: .horizontal) {
            HStack(spacing: spacing) { a; b }
            VStack(alignment: .leading, spacing: spacing) { a; b }
        }
    }

    // Manual bindings (the senders are @Environment @Observable references, not @Bindable).
    private var oscHost: Binding<String> { Binding(get: { osc.host }, set: { osc.host = $0 }) }
    private var oscPort: Binding<Float> { Binding(get: { Float(osc.port) }, set: { osc.port = Self.clampPort($0) }) }
    private var admHost: Binding<String> { Binding(get: { admOSC.host }, set: { admOSC.host = $0 }) }
    private var admPort: Binding<Float> { Binding(get: { Float(admOSC.port) }, set: { admOSC.port = Self.clampPort($0) }) }
    private var sacnHost: Binding<String> { Binding(get: { sacn.host }, set: { sacn.host = $0 }) }
    private var sacnPort: Binding<Float> { Binding(get: { Float(sacn.port) }, set: { sacn.port = Self.clampPort($0) }) }
    private var sacnUniverse: Binding<Float> {
        Binding(get: { Float(sacn.universe) }, set: { sacn.universe = min(max(Int($0.rounded()), 1), 63_999) })
    }
    private var artNetHost: Binding<String> { Binding(get: { artNet.host }, set: { artNet.host = $0 }) }
    private var artNetPort: Binding<Float> { Binding(get: { Float(artNet.port) }, set: { artNet.port = Self.clampPort($0) }) }
    private var artNetUniverse: Binding<Float> {
        Binding(get: { Float(artNet.universe) }, set: { artNet.universe = min(max(Int($0.rounded()), 0), 32_767) })
    }
    private static func clampPort(_ v: Float) -> UInt16 { UInt16(min(max(Int(v.rounded()), 1), 65_535)) }

    // MARK: - Licht (L1: Grand Master + Blackout + DMX resolution, drives Art-Net AND sACN)

    private var lichtSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Light").font(EchoelTheme.font(11, .bold)).foregroundStyle(EchoelTheme.dim)
            pairedRow(spacing: 10) {
                EchoelValueField(label: "Master", value: grandMasterBinding,
                                 range: 0...1, unit: "", decimals: 2)
            } second: {
                Button {
                    let newState = !artNet.blackout
                    artNet.blackout = newState
                    sacn.blackout = newState
                } label: {
                    Text(artNet.blackout ? "Blackout ON" : "Blackout")
                        .font(EchoelTheme.font(13, .semibold))
                        .foregroundStyle(artNet.blackout ? EchoelTheme.onPrimary : EchoelTheme.text)
                        .padding(.horizontal, 14).frame(minHeight: 40)
                        .background(RoundedRectangle(cornerRadius: EchoelTheme.radius)
                            .fill(artNet.blackout ? EchoelTheme.danger : Color.clear))
                        .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius)
                            .strokeBorder(artNet.blackout ? EchoelTheme.danger : EchoelTheme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(artNet.blackout ? "Blackout active — turn the light back on" : "Blackout — black out the light immediately")
            }
            HStack(spacing: 10) {
                Text("DMX").font(EchoelTheme.font(11, .semibold)).foregroundStyle(EchoelTheme.dim)
                Picker("DMX resolution", selection: dmxResolutionBinding) {
                    Text("16-bit").tag(ArtNetSender.DMXResolution.sixteenBit)
                    Text("8-bit").tag(ArtNetSender.DMXResolution.eightBit)
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("DMX resolution — 16-bit for smooth fades, 8-bit for legacy fixtures")
            }
            pairedRow(spacing: 10) {
                EchoelValueField(label: "Fixtures", value: fixtureCountBinding,
                                 range: 1...Double(DMXFixtureFan.maxFixtures), unit: "", decimals: 0)
            } second: {
                EchoelValueField(label: "Spacing", value: fixtureSpacingBinding,
                                 range: 0...64, unit: "", decimals: 0)
            }
            Text("Master scales the brightness of all outgoing light data (Art-Net + sACN). Blackout goes dark instantly; the return fades back in flicker-free. 16-bit sends paired coarse/fine channels for smooth fades; pick 8-bit only for fixtures that cannot read them.")
                .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                .fixedSize(horizontal: false, vertical: true)
            Text("Fixtures repeats the same colour across that many lamps from address 1 — addressing the rig, not moving light through it: every lamp shows the SAME colour, because this output produces one. Spacing is the gap between their start addresses; 0 means back to back. This matters most on sACN, which by specification fills all 512 slots — so with one fixture addressed, every other lamp on that universe is driven dark.")
                .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: EchoelTheme.radius).fill(EchoelTheme.fill))
        .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius).strokeBorder(EchoelTheme.border, lineWidth: 1))
    }

    /// #1006 — the rig's size, written to BOTH arms from one control, the same law as the
    /// master fader and the resolution picker above it.
    ///
    /// ⭐ PERSISTED since #1442 — this IS the separate slice the previous note called for, with
    /// its own key and its own decode default (`net.artnet.fixtureCount` / `net.sacn.*`, and
    /// `ArtNetSender.decodedFixtureCount`). The rig's shape belongs to the installation the way
    /// `host`/`port`/`universe` already do: an operator who tells the app the rig has twelve
    /// lamps should not have to say it again after every relaunch.
    ///
    /// ⚠️ The old note's safety argument — *"a stored count of 32 would fan a stranger's rig on
    /// first open"* — was answered by measurement, not waved away: the stream only runs when a
    /// PERSISTED patchbay route is enabled, aimed at the PERSISTED host and universe. A first
    /// open that emits anything is already aimed at the stored rig. With nothing stored the
    /// decode default is 1, so a genuinely fresh install is unchanged.
    ///
    /// ⚠️ `grandMaster` and `blackout` did NOT join it, on purpose: a stored 5 % master reads as
    /// broken hardware and a stored blackout opens the app into a dark room. Session state, not
    /// installation state. Guard: `TheLightShowStatePersistsTests` (claim 5 is that half).
    ///
    /// `Double` in, `Int` out: `EchoelValueField` is the one numeric control app-wide (the UI
    /// law), and these ARE numbers with no names — a count and a slot offset — so a Picker
    /// would be the wrong half of that same law.
    private var fixtureCountBinding: Binding<Double> {
        Binding(
            get: { Double(artNet.fixtureCount) },
            set: { v in
                let n = Swift.min(Swift.max(Int(v.rounded()), 1), DMXFixtureFan.maxFixtures)
                artNet.fixtureCount = n
                sacn.fixtureCount = n
            }
        )
    }

    private var fixtureSpacingBinding: Binding<Double> {
        Binding(
            get: { Double(artNet.fixtureSpacing) },
            set: { v in
                let n = Swift.max(Int(v.rounded()), 0)
                artNet.fixtureSpacing = n
                sacn.fixtureSpacing = n
            }
        )
    }

    /// One choice, both protocols — the same law as the master fader above. Until this row
    /// existed, `resolution` had ZERO writers in the whole repository while its own doc called
    /// 8-bit "the legacy mode for simple fixtures": a selectable mode with no selector, and the
    /// `.eightBit` encoder branch was reachable only from a unit test. The row is what makes
    /// that sentence true.
    ///
    /// ⭐ PERSISTED since #1442, under `net.artnet.resolution` / `net.sacn.resolution`, with
    /// `.sixteenBit` as the decode default — so a fresh install still starts at the higher
    /// precision and a fixed installation keeps the mode its fixtures can actually read. An
    /// unrecognised stored string falls back rather than trapping.
    ///
    /// ⛔ THIS DOC BLOCK USED TO SIT ABOVE `fixtureCountBinding` (#1442). Swift merges adjacent
    /// `///` lines into ONE comment, so the paragraph describing the resolution picker was
    /// attached to the fixture-count binding and documented the wrong member. Moved here in the
    /// same commit that made its persistence sentence true.
    private var dmxResolutionBinding: Binding<ArtNetSender.DMXResolution> {
        Binding(
            get: { artNet.resolution },
            set: { r in
                artNet.resolution = r
                sacn.resolution = r
            }
        )
    }

    /// One fader, both protocols — the patchbay is the "kleines Lichtpult".
    private var grandMasterBinding: Binding<Float> {
        Binding(
            get: { artNet.grandMaster },
            set: { v in
                artNet.grandMaster = v
                sacn.grandMaster = v
            }
        )
    }
    #endif

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 10) {
            Text("\(router.graph.routes.count) connections")
                .font(EchoelTheme.font(13, .semibold)).foregroundStyle(EchoelTheme.text)
            Spacer(minLength: 0)
            Button { router.applyAllSuggestions() } label: {
                Label("Smart patch", systemImage: "wand.and.stars")
                    .font(EchoelTheme.font(12, .semibold)).foregroundStyle(EchoelTheme.onPrimary)
                    .padding(.horizontal, 12).frame(minHeight: 34)
                    .background(RoundedRectangle(cornerRadius: EchoelTheme.radius).fill(EchoelTheme.text))
            }
            .buttonStyle(.plain)
            // Disabled-with-no-reason, the same one-channel defect as the status dot above.
            .accessibilityLabel(router.suggestions().isEmpty
                                ? "Smart patch — no suggestions available"
                                : "Smart patch")
            .disabled(router.suggestions().isEmpty)
            Button { router.clearAll() } label: {
                Text("Clear").font(EchoelTheme.font(12, .semibold)).foregroundStyle(EchoelTheme.text)
                    .padding(.horizontal, 12).frame(minHeight: 34)
                    .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius).strokeBorder(EchoelTheme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(router.graph.routes.isEmpty
                                ? "Clear — no routes to clear"
                                : "Clear all routes")
            .disabled(router.graph.routes.isEmpty)
        }
    }

    // MARK: - Source card

    private func sourceCard(_ src: SignalPort) -> some View {
        let sinks = router.graph.sinks.filter { $0.id != src.id }
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: kindIcon(src.kind)).font(.system(size: 13)).foregroundStyle(EchoelTheme.accent)
                Text(src.name).font(EchoelTheme.font(14, .semibold)).foregroundStyle(EchoelTheme.text)
                statusTag(src)
                Spacer(minLength: 0)
            }
            ForEach(sinks) { dst in
                destinationRow(src, dst)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: EchoelTheme.radius).fill(EchoelTheme.fill))
        .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius).strokeBorder(EchoelTheme.border, lineWidth: 1))
    }

    private func destinationRow(_ src: SignalPort, _ dst: SignalPort) -> some View {
        let check = router.graph.check(sourceID: src.id, sinkID: dst.id)
        let compatible: Bool = { if case .ok = check { return true } else { return false } }()
        let connected = router.isConnected(src.id, dst.id)
        let conv = converterName(check)
        return Button {
            if compatible { router.toggle(src.id, dst.id) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: connected ? "checkmark.circle.fill" : (compatible ? "circle" : "minus.circle"))
                    .font(.system(size: 14))
                    .foregroundStyle(connected ? EchoelTheme.accent : (compatible ? EchoelTheme.dim : EchoelTheme.border))
                Image(systemName: kindIcon(dst.kind)).font(.system(size: 11)).foregroundStyle(EchoelTheme.dim)
                Text(dst.name).font(EchoelTheme.font(13)).foregroundStyle(compatible ? EchoelTheme.text : EchoelTheme.dim)
                if let conv { Text(conv).font(EchoelTheme.font(10)).foregroundStyle(EchoelTheme.dim) }
                Spacer(minLength: 0)
                statusTag(dst)
            }
            .frame(minHeight: 32)
        }
        .buttonStyle(.plain)
        .disabled(!compatible)
        .accessibilityLabel("\(src.name) to \(dst.name)")
        .accessibilityValue(connected ? "connected" : (compatible ? "not connected" : "incompatible"))
    }

    // MARK: - Helpers

    private func converterName(_ check: SignalGraph.ConnectionCheck) -> String? {
        if case let .ok(cid) = check, let cid {
            return router.graph.catalog.converters.first { $0.id == cid }?.name
        }
        return nil
    }

    /// "soon" tag for roadmap transports — keeps the patchbay honest (no dead points).
    @ViewBuilder
    private func statusTag(_ port: SignalPort) -> some View {
        if port.transport.status == .roadmap {
            Text("soon")
                .font(EchoelTheme.font(9, .semibold)).foregroundStyle(EchoelTheme.dim)
                .padding(.horizontal, 5).frame(minHeight: 16)
                .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall).strokeBorder(EchoelTheme.border, lineWidth: 1))
        }
    }

    private func kindIcon(_ kind: SignalKind) -> String {
        switch kind {
        case .controlBio:     return "waveform.path.ecg"
        case .controlMusical: return "music.note"
        case .controlMacro:   return "dial.medium"
        case .note:           return "pianokeys"
        case .controlChange:  return "slider.horizontal.3"
        case .audio:          return "speaker.wave.2"
        case .light:          return "lightbulb"
        case .spatial:        return "move.3d"
        case .clock:          return "metronome"
        case .video:          return "film"
        case .visual:         return "sparkles"
        }
    }
}
#endif

// MARK: - #1250 route row

/// One authored modulation route. The `FXModRouteRow` shape: named choices are Pickers,
/// numeric amounts are `EchoelValueField`s (the app-wide law), swipe to delete.
/// Reads only its own binding — no engine, no bus — so it observes nothing hot.
private struct ModulationRouteRow: View {
    @Binding var route: ModRoute
    let onDelete: () -> Void

    /// Producing channels plus this route's own (a persisted route to a channel that lost
    /// its producer must still render, not show a blank menu).
    private var sourceChoices: [ModSource] {
        var list = ModSource.allCases.filter(\.hasProducer)
        if !list.contains(route.source) { list.append(route.source) }
        return list
    }

    private var destinationChoices: [ModDestination] {
        var list = ModDestinationKey.all.map(ModDestination.init)
        if !list.contains(route.destination) { list.append(route.destination) }
        return list
    }

    /// Read-modify-write through the binding rather than calling a `mutating` method on
    /// `route` in place: `@Binding`'s setter is `nonmutating`, so this form needs nothing
    /// from an immutable `self` and cannot depend on how Swift chooses to synthesise a
    /// read-modify-write accessor.
    private var inputLowBinding: Binding<Float> {
        Binding(get: { route.inputLow },
                set: { var r = route; r.setInputLow($0); route = r })
    }

    private var inputHighBinding: Binding<Float> {
        Binding(get: { route.inputHigh },
                set: { var r = route; r.setInputHigh($0); route = r })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Toggle("", isOn: $route.enabled).labelsHidden().tint(EchoelTheme.accent)
                    .accessibilityLabel("Route enabled")
                Picker("Source", selection: $route.source) {
                    ForEach(sourceChoices, id: \.self) { s in Text(s.displayName).tag(s) }
                }
                .pickerStyle(.menu).tint(EchoelTheme.text)
                Image(systemName: "arrow.right").font(.system(size: 10)).foregroundStyle(EchoelTheme.dim)
                Picker("Destination", selection: $route.destination) {
                    ForEach(destinationChoices, id: \.self) { d in
                        Text(ModDestinationKey.displayName(d.key)).tag(d)
                    }
                }
                .pickerStyle(.menu).tint(EchoelTheme.text)
                Spacer(minLength: 0)
            }
            EchoelValueField(label: "Depth", value: $route.depth, range: 0...1, decimals: 2)
            // The SENSITIVITY WINDOW (#1408) — the door `ModRoute.inputLow/inputHigh` never
            // had. The primitive shipped with AU2 and was applied, persisted and decoded, but
            // nothing outside the type could write it, so every route created here ran the
            // identity window and the route only moved as far as the raw channel did. That is
            // the founder's "Bio löst zu neutral" as a reachability fact: coherence typically
            // lives in ~[0,3…0,6], so a full-range destination saw about a third of its travel.
            //
            // ⚠️ BOTH EDGES GO THROUGH `setInputLow`/`setInputHigh`, never through a plain
            // binding on the stored properties. `windowed(_:)` answers a closed or inverted
            // window with IDENTITY, so a raw pair of fields would let a player drag one past
            // the other and leave two numbers on screen beside a route that silently stopped
            // shaping anything — the lying dial #164/#227 bans. The pairing rule lives ONCE,
            // on the type (#416); this row only spells the edges.
            EchoelValueField(label: "Bio min", value: inputLowBinding, range: 0...1, decimals: 2)
                .accessibilityHint("The body value that maps to none of this route's depth. Raise it to ignore the bottom of the channel's range.")
            EchoelValueField(label: "Bio max", value: inputHighBinding, range: 0...1, decimals: 2)
                .accessibilityHint("The body value that maps to all of this route's depth. Lower it to reach full depth without reaching the top of the channel's range.")
            HStack(spacing: 12) {
                Toggle("Invert", isOn: $route.invert).tint(EchoelTheme.accent)
                    .font(EchoelTheme.font(12))
                Picker("Curve", selection: $route.curve) {
                    ForEach(ResponseCurve.allCases, id: \.self) { c in
                        Text(c.rawValue.capitalized).tag(c)
                    }
                }
                .pickerStyle(.menu).tint(EchoelTheme.text)
                .accessibilityLabel("Response curve")
            }
            // Smoothing is a TIME the engine applies between applied frames (`smoothingTau`);
            // one decimal is the grid — a tenth of a second is the finest step a ~1 Hz apply
            // can express (#430).
            EchoelValueField(label: "Smooth", value: $route.smoothingTau,
                             range: 0...10, unit: "s", decimals: 1)
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
        }
    }
}
