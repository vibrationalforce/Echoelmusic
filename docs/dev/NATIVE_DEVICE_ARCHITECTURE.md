# WA3 — Native Device Architecture

**Status: CONTRACT DESIGN. Nothing here is implemented.** Architecture document, 2026-09-24,
branch head at design time `eaaedc71f`, `main` = `7b2690357`. No production code, test, store,
persistence format, UI or workflow was changed.

**Authority:**
1. `docs/dev/FOUNDER_PRODUCT_LAW.md`
2. `docs/dev/ECHOELMUSIC_MASTER_PLAN.md` (invariants; §7 WA3 "Bound by WA2")
3. `docs/dev/SESSION_OWNERSHIP_CENSUS.md` §O (the WA2 decision — binding, not reopened here)
4. `docs/dev/WORKSTATION_UI_OWNERSHIP_CENSUS.md` (WA1)
5. current production code (measured below)
6. `docs/dev/HISTORY_ARCHIVE.md`

**How it was measured.** Three read-only inspection passes (instrument state · engine,
parameters and modulation · AUv3, envelope and history), then direct re-checks of every claim
this document leans on. Line numbers are dates, not facts; each load-bearing claim names a
command or a symbol so it can be re-derived. Abbreviations: `ESV` =
`Studio/EchoelStudioView.swift`, `App` = `EchoelmusicApp.swift`, paths under
`Sources/Echoelmusic/` unless stated.

⚠️ **Terminology.** *Session* = the canonical `DMMWProject` (WA2). *Device* = the format-neutral
unit defined here. *Echoel Device* = today's bio-generative instrument, re-described as one
Device type. `SessionView`/`SessionEngine` are the parked breathing experiment and are not meant.

---

## A. Executive decision

1. **A Device is three things, never one object:**
   - a **descriptor** — static, per device TYPE (identity, capabilities, parameter set);
   - an **instance state** — a versioned, `Codable`, Foundation-only VALUE, owned by the Session
     inside a Track's device slot;
   - an **engine** — a realtime renderer COMPILED from that state, built from `DSP/` only.
   UI edits state; state compiles to engine input; the engine never reads the UI or storage.
2. **The Echoel Device is one Device type** (`com.echoelmusic.device.echoel`). Its instance
   state gathers what today lives in ~70 global keys, three stores and one view's `@State`
   (§B, §M). Two instances on two tracks share nothing but Session context and the bio bus.
3. **Addressing is by instance, not by lane or voice.** Every device parameter is reached as
   `device.<instanceID>.<base>`, where `<base>` is the existing registry keyPath
   (`ddsp.env.attack`). There is still ONE parameter system (`ParameterDescriptor`,
   `EchoelParameterRegistry`, `ParameterApplyRouter`); the instance prefix is a namespace, like
   today's `track.<laneID>.<base>`, not a second registry.
4. **The Session gives context; the Device never owns Session truth.** Tempo, transport,
   meter, key, scale, A4 and tone system arrive as a read-only snapshot. A device may *report*
   (detected key, its own notes for visual/light) but never *write* the Session.
5. **Bio is a subscription, not a possession.** Acquisition stays app-level. A Device declares
   which normalized ControlSources it consumes; its routes (source → own parameter) are
   instance state. Raw bio values are never instance or preset state.
6. **Automation and modulation stay two stores.** Automation is Session content addressed to
   `device.<id>.<base>`; modulation routes are instance state inside the device. Both resolve
   through the same parameter descriptor and the same eligibility flags.
7. **One creative core, several adapters.** Native DMMW adapter, the existing AUv3 adapter,
   later VST3/CLAP adapters, and a later *hosted-plugin* adapter that makes a third-party
   plugin look like a Device to the Session. The Session depends on none of them.
8. **The contract types need a home the AUv3 can compile and that is not `DSP/`.** That home
   is the EchoelCore module, which is founder-gated (#95). This is WA3's one hard prerequisite
   for implementation (§O).

---

## B. Current Echoel state map

**Headline (measured):** every piece of Echoel instrument state is global. Each value is an
`@AppStorage`/`UserDefaults` key, a `@State` on the one `EchoelStudioView`, or a store/voice
built once in `App` and injected through the environment. Nothing is scoped to an instance.
`@AppStorage` reaches **87 distinct keys** once `StudioDefaultKeys` constants are resolved
(`Core/StudioDefaultKeys.swift` declares 40 of them); re-derive by resolving the constants,
since `git grep '@AppStorage("'` alone finds only the 26 literal ones.

Classes: **INST** instance state · **SESS** Session-derived · **APP** app default/library ·
**CACHE** runtime cache · **ENG** engine resource · **UI** UI state · **LEG** legacy/migration ·
**UNRES** unresolved.

| # | State | Where today | Persisted? | Class | Note |
|---|---|---|---|---|---|
| 1 | `currentPatch: SynthPatch` | `@State` ESV (`SynthPatch(name: "Init")`) | **no** — rebuilt from `studio.presetIndex` (factory only) or the genre patch; a user patch is lost on relaunch unless a Project is saved | INST | the timbre of the pad voice |
| 2 | `studio.presetIndex` | `@AppStorage` | yes | CACHE | a pointer into the factory list, not a timbre |
| 3 | `studio.articulation` (pluck↔pad) | `@AppStorage` | yes | INST | rewrites the patch ADSR live |
| 4 | `PatchStore` (user patches, favourites, recents) | AppGroup `Patches/…` | yes | APP | library, not instance |
| 5 | lead / bass voice patches | chosen from the genre at generate | no | INST (derived from genre) | `pianoRoll.applyLeadPatch/applyBassPatch` |
| 6 | touch/Field patch `touch.patchID` + 9 `touch.*` keys | `@AppStorage` | yes | INST | play-surface voice |
| 7 | `field.autoPlay.*` (13 keys) | `@AppStorage` | yes | INST | self-play behaviour |
| 8 | genre `studio.genre` | `@AppStorage` | yes | INST | device-local per §O |
| 9 | key/scale `studio.rootIndex`/`studio.scale` | `@AppStorage` | yes | SESS | duplicated by `SessionContext.keyRoot/keyScale` (`echoel.*`), synced only by `adopt` |
| 10 | A4 `echoel.a4Hz` | `SessionContext` | yes | SESS | already the one home |
| 11 | tone system `toneSystemID` | `@AppStorage` literal | yes | SESS | not in `SessionContext` today |
| 12 | mood (8 dials) `studio.mood` | JSON via `MoodStorage` | yes | INST | device-local per §O |
| 13 | `MoodPresetStore` | AppGroup | yes | APP | library |
| 14 | bar variation `studio.moodVariation` | `@AppStorage` | yes | INST | |
| 15 | rhythm characters `studio.bassRhythm`/`padRhythm`, pad shape `padGate/padAccent/padEvolve` | `@AppStorage` | yes | INST | generative phrase settings |
| 16 | loop `studio.loopBars` | `@AppStorage` | yes | INST (phrase length) | §O: the Session loop is a SEPARATE concept |
| 17 | BPM lock `studio.lockBPM`/`lockedBPM` | `@AppStorage` | yes | SESS | Flow/Loop is a transport mode (§E) |
| 18 | auto mode `studio.autoMode` | `@AppStorage` | yes | INST | folds into mood and visual |
| 19 | performer signature `bio.performerSignature` | UserDefaults | yes | APP (per person) | a personal trait, not a device setting |
| 20 | generation state (`hasComposed`, `evolution`, `lastRawTake`, maze state…) | `@State` ESV | no | CACHE | |
| 21 | role mix `mixer.{bass,pad,lead,drums}` | `MixerStore` UserDefaults | yes | INST | the device's INTERNAL mix; not in `Project` |
| 22 | field level `touch.level` | `@AppStorage` | yes | INST | |
| 23 | metronome enabled/level/accent | in memory | **UNRES** | SESS (click is transport) | no `forKey` found |
| 24 | master volume `AudioEngine.masterVolume` | in memory | **no** | SESS (master) | not a device concern |
| 25 | loudness target / master character | `@AppStorage` | yes | SESS / export | |
| 26 | `EchoelFXChain` params | owned by `PolySynthVoice.fxChain` | **no** — hand-dialled FX are lost on relaunch | INST | |
| 27 | FX character `studio.fxCharacter` | `@AppStorage` | yes | INST | also `Project.fxCharacterRaw` |
| 28 | delay sync | `@State` | no | INST | |
| 29 | `FXPresetStore` | AppGroup | yes | APP | library |
| 30 | `TrackFXStore` bus inserts `trackfx.{bass,melodic,drums}` | UserDefaults JSON | yes | INST | "track" in name only: per ROLE bus, global |
| 31 | modulation matrix `modulationMatrix.v1` | `ModulationEngine` UserDefaults | yes | INST (synth targets) + SESS (tempo target) | §O: device matrix persists with the instance |
| 32 | FX bio routes `FXBioModulator.routes` | in memory | **no** | INST | a second modulation system |
| 33 | built-in bio→DDSP mappings | hard-coded in each voice | n/a | ENG (fixed coefficients) | not user state |
| 34 | body-voice arm `bioVoice.isArmed` | in memory (deliberately) | no | INST (runtime-armed) | activation, not preset |
| 35 | bio source `bio.sourceKind` | `@AppStorage` | yes | APP (sensor) | acquisition, never device |
| 36 | motion mapping | none | — | — | `ModSource.motion.hasProducer == false` |
| 37 | visual response `visual.*` (15), weather `weather.*` (9) | `@AppStorage`, declared in three views | yes | INST (response) + APP (display) | §F splits them |
| 38 | mood pads `mood.sound.*`/`mood.visual.*` | `@AppStorage` | yes, **no reachable writer** | LEG | surface removed 2026-07-07 |
| 39 | MIDI out `midi.out.{mpe,expression,ump2}` | `@AppStorage` (PatchbayView) | yes | APP (endpoint) | MPE OUT is real; incoming MPE has no zones (#548) |
| 40 | routing graph `signalGraph.routes.v1` | `SignalRouter` | yes | SESS (logical) + APP (endpoint) | §O split |
| 41 | voice objects: `polyVoice(12)`, `leadVoice(3)`, `bassVoice(2)`, `touchVoice(6)`, `subBass`, `bioVoice` | `@State` in `App`, one each | — | ENG | global singletons |
| 42 | `LaneVoiceRack` (4 poly slots + 1 sub + 1 sampler + 1 bio) | `@State` in `App` | — | ENG | the only per-lane pool; slots are allocations, not instances |
| 43 | tuning fan-out `applyTuning()` | a method on `EchoelStudioView` | — | SESS→ENG | a Session fact distributed by a View |
| 44 | `TimelineLane.patch/genreOverride/mood/variationSeed` | persisted in the timeline | yes | INST precursor | **zero production writers** |
| 45 | `Project` v1 (patch, mood, genre, key, loop, notes…) | ProjectStore | yes | LEG | import source (WA2) |
| 46 | `DMMWProject.sound` = ONE `patch` + ONE `fxCharacterRaw` | envelope, 0 callers | — | LEG→SESS | a single global sound slot |
| 47 | `DMMWProject.musical.styleRaw/modeRaw/moodFields` | envelope | — | **misplaced** | genre and mood sit in the Session's musical section although §O makes them device-local |

**The four structural facts that make today's instrument not instance-safe:**
- **One voice, two writers.** `timelinePlayer.rollPatchSink` applies a lane's patch to the
  global `polyVoice` (`App`), the same object `applyTakeSound(currentPatch)` writes. Last writer wins.
- **Global addresses reach one voice.** `polyVoice.bindAutomatable(into: parameterRouter)` is the
  only global binding; lead, bass and touch voices have no address. Per-track keyPaths reach rack
  poly slots only, and the modulation engine registers no per-track destination at all.
- **Four paths into the render thread**, side by side: SPSC queues (`PolySynthVoice.patchCommands`
  with POD `ResolvedPatch`), `didSet` atomic mirrors (`SubBassVoice.audioMixLevel`), direct
  plain-Float writes from the main actor into DSP objects (`poly.forEachVoice { $0.attack = v }`,
  `FXBioModulator` into `EchoelFXChain`), and node `volume`/`pan`.
- **The note engine is not portable.** `PianoRollModel` lives in `Studio/PianoRollView.swift`,
  which imports SwiftUI. The composer itself is: `Sequencer/BioComposer.swift` (with
  `MoodProfile`), `MusicStyle`, `ModulationMatrix`, `FXModulation` and `DSP/FXPreset.swift` all
  import Foundation only and carry no `@MainActor`.

---

## C. Native Device contract

Pseudo-Swift describes SHAPE only. None of it exists; names are proposals.

### C1. Descriptor — per device TYPE, static

| Field | Meaning | Echoel today |
|---|---|---|
| `typeID` | reverse-DNS, never reused (`com.echoelmusic.device.echoel`) | — |
| `version` | semantic; state migrations key off it | — |
| `name`, `vendor`, `category` | display; category ∈ instrument · effect · generator · analyzer · utility · MIDI | instrument + generator |
| `capabilities` | composable declarations (§C4) | — |
| `parameters` | `[ParameterDescriptor]` for this type (base keyPaths) | the DDSP catalog (15) is the seed |
| `stateSchemaVersion` | version of the instance-state value | — |

### C2. Instance — per placed device

| Field | Meaning |
|---|---|
| `instanceID: UUID` | stable for the life of the placement; the automation/modulation address root |
| `typeID`, `typeVersion` | which descriptor built it |
| `state` | the device's `Codable` state value (§J), opaque to the Session except for its version |
| `bypass` / `enabled` | Session-level flags on the slot, not inside `state` |
| `presetRef?` | provenance only ("started from preset X"); the state is the truth |

The Session stores `(instanceID, typeID, typeVersion, stateVersion, stateBlob)`. It never
decodes a foreign device's state. An unknown `typeID` is kept verbatim and rendered silent with
a visible "missing device" marker — never dropped (the #527 law: lossy on unknown is wrong).

### C3. Runtime surface — what every adapter implements around an engine

| Concern | Contract |
|---|---|
| **Audio inputs/outputs** | declared bus layout (channels per bus); instrument = 0 in / 1 stereo out |
| **Note input** | note on/off with velocity, pitch bend, per-note expression when MPE is declared; sample-offset timestamps in the block (block-granular is allowed but must be declared) |
| **Event input** | parameter changes (automation, modulation, host) as timestamped `(address, value)` |
| **Event output** | notes out (for MIDI out and for `MusicalFrame` visual/light), analysis values |
| **Latency** | samples, reported; may change only across `reset` |
| **Tail** | seconds (reverb); `.infinite` allowed for drones |
| **Preset state** | `state` get/set as a value; see §J |
| **Automation exposure** | every descriptor with `automationEligible` |
| **Modulation exposure** | every descriptor with `modulationEligible` |
| **Session context** | read-only snapshot per block or per tick (§E) |
| **Resource lifecycle** | `prepare(sampleRate, maxFrames)` → allocate everything; `reset()`; `release()`. No allocation after `prepare` |
| **Render lifecycle** | `render(frames, context, events) → audio` on the realtime thread (§F) |
| **UI/editor attachment** | optional; an editor binds to the *instance state model*, never owns it |
| **Capabilities** | §C4 |

### C4. Capabilities — composable declarations, not a protocol per feature

A capability is a small declared VALUE the host reads; behaviour lives in the one runtime
surface above. This avoids a giant protocol and avoids eleven tiny protocols that every adapter
must type-check.

| Capability | Carries | Echoel Device |
|---|---|---|
| `audioGenerator` | output layout | ✅ |
| `audioProcessor` | input + output layout | — (future inserts) |
| `noteInput(mpe: Bool)` | expression dimensions | ✅ (MPE: no — no zones, #548) |
| `noteOutput` | — | ✅ (notes for MIDI out / visual) |
| `bioControl(sources:)` | which normalized ControlSources it may consume | ✅ coherence, HRV, heart rate, breath phase |
| `motionControl` | — | ❌ no producer today |
| `generator` | has an internal composer that runs on transport | ✅ |
| `visualResponse` | publishes a response descriptor the visual stage may read | ✅ (§F3) |
| `spatialOutput` | publishes an object position | — (the Session derives spatial from the track) |
| `analyzer` | publishes analysis values | — (meters are Session/master) |
| `latency(samples)` / `tail(seconds)` | numbers | 0 / ~2 s (reverb) |
| `presets` | factory preset list | ✅ |

**WA3.1 amendment — a declaration is not a producer.** A capability states what a device COULD
consume or emit. It never implies that a producer exists or that the feature ships: `motionControl`
has no producer (`ModSource.motion.hasProducer == false`), and a granular parameter does not exist
(granular went with #1305; `HISTORY_ARCHIVE` B5). Store, website and content claim only what
ships (`FEATURE_STATUS.md`, `ContentPipeline/CLAIMS.md`), never what a descriptor declares.

---

## D. Minimum Track contract (input to implementation; no Track type is created here)

§G of the WA2 census gave nine points; WA3 confirms them with these decisions.

| Field | Decision |
|---|---|
| **Identity** | `trackID: UUID` + name. During migration the lane's UUID seeds the track id, so `track.<laneID>.*` addresses stay valid. |
| **Domain** | audio · instrument (MIDI/notes) · bio · later video, light, spatial object. One domain per track. |
| **Timeline relationship** | a track OWNS the content of exactly one timeline lane on the spine. The lane is the timeline *projection* of the track; overlap precedence stays `TimelineScheduling.activeRegion`. |
| **Device chain** | `instrument: DeviceInstance?` (0…1) + `inserts: [DeviceInstance]` (0…n). Sends later. |
| **Routing** | logical output target (master now; bus/sends later) — Session truth; endpoints are app config. |
| **Mixer** | level, pan, mute, solo — owned by the track, addressed `track.<id>.mixer.*`. |
| **Arm** | track-level flag; meaningful only for a domain with an input. |
| **Automation** | Session automation lanes addressed to `track.<id>.mixer.*` or `device.<instanceID>.<base>`. |
| **Media/clips** | references into the clip pool / asset store; never bytes. |
| **Spatial** | an object derived from the track (as `SpatialSceneStore` derives today), stored once, in the Session. |
| **Visual/light** | assignments (which track drives which look/fixture group) are Session creative state (§O); the track holds no lighting data itself. |

**Five words that must stop being synonyms:**

| Term | Is | Is NOT |
|---|---|---|
| **TRACK** | the Session's creative container: identity, device chain, mixer, routing, content | a voice, a bus node, a row |
| **TIMELINE LANE** | the row of regions on `TimelineDocument` that a track projects onto the spine | the owner of devices or mixer (today it carries both as precursor fields) |
| **MIXER BUS** | a render-side summing node | anything today: there is no per-track bus node; each voice's own source node `volume`/`pan` stands in |
| **PATTERN ROW** | a role INSIDE the Echoel Device's composer (bass · pad · lead · field; `MixerStore` roles) | a track — the four roles are one device's internal mix |
| **DEVICE VOICE** | a polyphony unit inside one device engine (`PolySynthVoice(maxVoices:)`); a `LaneVoiceRack` slot is a physical ALLOCATION of such units | an instance, a track or an address |

---

## E. Session ↔ Device contract

**The Session provides (read-only snapshot, per tick for control-rate code, per block for render):**

| Context | Source today | In the snapshot |
|---|---|---|
| sample rate, max block | engine format | ✅ |
| tempo | `PatternEngine`/`Transport` (TempoMap at WA2 target) | ✅ current BPM + map lookup |
| transport | `Transport.isPlaying`, position | ✅ playing flag, beat position, bar |
| beat phase | `MusicalFrame.beatPhase` | ✅ |
| meter | hard-coded 4/4 today; MeterMap at target | ✅ |
| key, scale | `studio.rootIndex/scale` (+ `SessionContext` mirror) | ✅ from the one Session owner |
| A4, tone-system cents | `SessionContext.a4Hz`, `toneSystemID` | ✅ resolved cents per degree |
| track identity | lane id/name | ✅ trackID, name |
| automation | — | ❌ not as lanes: automation reaches a device only as parameter events |
| assets | `MediaLibrary.resolveRef` | a resolver function, never paths or bytes |
| spatial context | `SpatialSceneStore` | ❌ not in v1 (no device declares `spatialOutput`) |
| permissions/collaboration | — | ❌ devices do not see collaboration; edits arrive as state changes |

**Rules:**
- **Key-follow is instance state:** `keyFollow = .session | .fixed(key, scale)`. Default
  `.session`. Tone system and A4 always follow the Session (a device cannot detune the world).
- **Genre, mood, rhythm characters, variation, phrase length** are device-local (§O).
- **Tempo: the device reads, never sets.** Today `BioComposer.tempo(for:)` under `.flowFree`
  drives the clock. Under WA2 that becomes a Session-level ControlSource consumer: Flow/Loop is a
  Session transport MODE (the lock), the body-tempo servo belongs to the Session, and the device's
  composer reads the resulting tempo like any other. The TempoMap changes only by an explicit
  commit (§O). T1–T3 are unchanged.
- **START vs ▶:** START/ACTIVATE arms a device (bio subscription, generator running, body voice);
  ▶ runs the Session transport. A generator device that is armed but not playing renders idle.
- **Reports, not writes.** A device may publish detected key, its notes (for `MusicalFrame`
  visual/light), meters. The Session decides what to adopt (the `TuningDetector` law: detected is
  reported, decided by the user).

---

## F. Device ↔ DSP contract

### F1. Three layers and the direction of dependencies

```
Device UI (SwiftUI)                        ← edits the model; owns nothing persistent
   │ binds to
Device Model (instance state + controller) ← Codable state value; control-rate logic
   │ compiles to                              (composer, modulation evaluation)
Device Engine (realtime)                   ← DSP/ only: Foundation + Accelerate
   ▲
Adapters (native · AUv3 · VST3 · CLAP)     ← depend on Model + Engine; nothing depends on them
Session                                    ← depends on the state VALUE + a type registry only
```

- **DSP never imports SwiftUI, Observation, Core or Sequencer.** Already law and enforced by the
  AUv3 build, which compiles `DSP/` in isolation.
- **The Model never imports SwiftUI.** Today the note engine does (`PianoRollModel` inside
  `PianoRollView.swift`); moving it out is an implementation prerequisite (§O).
- **Plugin-format code never enters DSP or Model.** `AUAudioUnit`, `AUParameterTree`,
  `AURenderEvent` stay in the AUv3 adapter. The same holds for any future VST3/CLAP shim.
- **The UI is not the persistent owner.** Every `@AppStorage`/`@State` in §B that is class INST
  moves under the instance state; a view reads and writes it through the model.

### F2. Control-rate controller vs render engine

The Echoel Device has a control-rate half — the generative composer (`BioComposer`), phrase
evolution, modulation evaluation — and a render half — voices + FX. Neither half may assume the
main actor: under an AUv3 host there is no app main actor to rely on for timing. Rule: the
controller runs off the render thread (main actor natively, a utility queue in a plugin), and
talks to the engine only through the realtime channel (§F4).

### F3. Visual response

A device's *visual response* (how its sound should look: style, intensity, hue bias) is instance
state and is published as a small descriptor with its notes. The *display* (window size, which
meter, floating/visible, external screen) is app/Session state. Today all 24 `visual.*`/
`weather.*` keys are one global set; the split is decided per key in §M.

### F4. The realtime channel — reuse, and converge on two of today's four paths

- **Structural state** (a whole patch, an FX preset, a voice-count change) → compile on the
  control thread to a POD snapshot → SPSC queue → swapped in at a block boundary. This is exactly
  `PolySynthVoice.patchCommands` carrying `ResolvedPatch`; it becomes the general pattern.
- **Continuous parameters** (automation, modulation, host) → one atomic-width value per
  parameter, read by the render (the `didSet`-mirror pattern), or timestamped events in the
  block's event list where sample accuracy is declared.
- **Retire over time:** direct plain-Float writes from the main actor into live DSP objects
  (`forEachVoice { $0.attack = v }`, `FXBioModulator` → `EchoelFXChain`) — they are the one path
  that is neither atomic-width by construction nor ordered. Not changed in WA3; named so the
  implementation phase does not copy it.
- **Forbidden in any render callback:** SwiftUI, `@AppStorage`/`UserDefaults`, actors or `Task`,
  locks, disk, network, AI, `Codable` decode, dynamic persistence objects, allocation.
- **No second engine.** The engine is today's voices and `EchoelFXChain`, instantiated per
  device instance instead of once per app.

---

## G. Parameter contract

**One system, extended — not duplicated.** P2 law stands: *registered ≠ bound ≠
automationEligible ≠ modulationEligible*, and eligibility is deny-by-default.

| Field | Today (`ParameterDescriptor`) | Device contract |
|---|---|---|
| stable ID | `keyPath` ("ddsp.env.attack") | the BASE id, unchanged |
| instance address | `track.<laneID>.<base>` (per-lane) | `device.<instanceID>.<base>`; `track.<laneID>.<base>` resolves through the track's instrument slot |
| name, unit, range, default, value labels | ✅ | ✅ |
| **scaling / taper** | ❌ linear only | **add**: linear · exponential · dB (automation's `filterCutoff` target is already exponential, outside the registry) |
| **host address** | ❌ | **adapter mapping, not identity** (WA3.1 amendment): each adapter keeps a stable table BASE id → numeric host ID, never derived from array order (AU needs `UInt64`, VST3 `ParamID` and CLAP `clap_id` are 32-bit) |
| automation eligibility | ✅ | ✅ |
| modulation eligibility | ✅ | ✅ |
| domain | ✅ (`audio`/`visual`/`lighting`/`spatial`) | ✅ |
| realtime application | the bound setter (`ParameterApplyRouter`) | the device's realtime channel (§F4) |
| persistence | — | continuous parameters persist inside instance state; the descriptor says nothing about storage |
| host/plugin exposure | the AUv3 has its own 8 hand-built parameters with different ids (`"reverbMix"` vs `ddsp.fx.reverbMix`) | adapters BUILD their host tree from the descriptor; no hand-written parallel list |

**Decision on the AUv3's bio parameters.** Today coherence, HRV, heart rate and breath phase are
host-visible, writable AUv3 parameters. In the contract they are **ControlSource inputs, not
device parameters**: they are not in the preset, not in `fullState`, not automatable as creative
state. A host that wants to drive them sends them as control input (§I).

**WA3.1 amendment — canonical identity is format-neutral.** The BASE id and
`device.<instanceID>.<base>` are the only identities the Session stores. AU / VST3 / CLAP numeric
host IDs belong to each adapter's mapping table and must never become Session identity, a
persisted key in Session content, or an automation address.

**WA3.2 (2026-09-24) — built, narrowly.** What exists now, and what it does not claim:
- `ParameterDomain` + `ParameterDescriptor` moved, unchanged, from `Core/EchoelParameterRegistry.swift`
  to `DSP/ParameterDescriptor.swift` — one type, not a second registry. Reason: the AUv3 compiles
  `DSP/` and not `Core/`. ⚠️ **Debt (#95):** the intended home is a shared core target
  (`Core/Device/` or `EchoelCore`); `DSP/` is the only shared compile boundary reachable without a
  founder-gated `project.yml` edit. It holds Foundation-only value types, so the DSP layer guard
  still holds.
- `DSP/EchoelBodyVibeDevice.swift` — the AUv3's device TYPE (`echoel.bodyvibe`), a DIFFERENT
  instrument from the app's `ddsp.*` synth (AU base frequency 40–440/220 vs `ddsp.osc.frequency`
  20–2000/110; merging the two would change a host-visible range). Four creative descriptors
  (`bodyvibe.osc.baseFrequency`, `bodyvibe.texture.amount`, `bodyvibe.fx.reverbMix`,
  `bodyvibe.out.masterGain`), eligibility DENIED (nothing in the app binds them), plus one binding
  table (`Binding` → engine field) applied on the control thread, never in render.
- `EchoelBodyVibeAUv3Mapping` — the adapter table. Addresses 0…7, identifiers, units and groups
  are LITERALS; `resolve()` joins them to the descriptors and throws on a duplicate canonical ID,
  a duplicate address or identifier, an unknown canonical ID, or a descriptor with no host entry.
  The AUv3 builds its tree from `resolve()` and fails to load rather than mis-wire. Every
  host-visible fact is the value it shipped with.
- **Scaling/taper: NOT added.** Nothing consumes a taper, and the AU `unit` already tells the host
  how to display each value; a taper field without a reader would be a declaration without a
  producer (the WA3.1 lesson).
- **Instance addressing: CONTRACT ONLY.** `device.<instanceID>.<base>` has no resolver because
  there is no instance runtime; `track.<laneID>.<base>` (`PerTrackParameterKeyPath`) is unchanged.

---

## H. Automation / modulation contract

| | Automation | Modulation |
|---|---|---|
| is | persistent creative intent over Session time | a live or generated control relationship |
| stored in | the Session's automation home (§O), addressed `device.<instanceID>.<base>` or `track.<id>.mixer.*` | the device instance state (routes) |
| driven by | Session transport position | ControlSources (bio, LFO, later motion) |
| gate | `automationEligible` + bound | `modulationEligible` + bound |
| persists with | the Session | the device instance (and its presets, §J) |
| survives copying the device to another track | no (it addresses the old instance) — a "copy with automation" is an explicit editor action | yes, it is part of the device |

**Composition law (unchanged, now per instance):** where automation and modulation both target
a parameter, automation owns the ANCHOR and modulation moves around it — the existing
`PolySynthVoice` rule "automation may own a parameter only where it is the only writer;
otherwise it owns the anchor".

**Two modulation systems become one per device.** `ModulationMatrix` (`ModRoute`, persisted
globally) and `FXBioModulator` (`FXModRoute`, 13 FX targets, **not persisted**) both describe
source → parameter. The device holds one route list; FX targets become parameters with
descriptors (`fx.filter.cutoff`…). The tempo route is NOT device modulation: it targets the
Session transport and stays Session-level (§E).

---

## I. Bio / motion contract

```
acquisition (app)            → normalized ControlSource (app)      → device routes (instance) → device parameter
camera rPPG · BLE · HealthKit   coherence · hrv · heartRate(norm)     source, depth, curve,       via the realtime
· demo  (EngineBus.latestBio)   · breathPhase · (motion: none)        window, invert, smoothing   channel
```

- **Acquisition stays app-level.** Sensors, permissions, the Pulse pill, `BioEgressPolicy`,
  freshness windows — never inside a device.
- **Devices consume normalized values only.** The contract passes 0…1 (or declared ranges), the
  `isMeasured` provenance per channel and the synthetic flag; not RR series, not clinical detail.
- **Two instances, one source, different use.** Both subscribe to the same ControlSource; each
  applies its own routes. The bus is read-only for them.
- **Persistable:** the ROUTE (source name, depth, curve, window, smoothing). **Never persisted in
  device state or presets:** raw values, history, performer signature, any heart-rate number.
- **Egress still applies.** A device that outputs something derived from bio (MIDI expression,
  OSC) inherits `BioEgressPolicy` at the adapter, as the MPE output path does today (Ω7).
- **Motion:** the contract reserves `motionControl`; nothing produces motion today and nothing
  may claim it.
- **Defect repaired in WA3.1 (2026-09-24).** The AUv3 `fullState` getter wrote all eight
  parameters, `heartRate`, `hrv`, `coherence` and `breathPhase` included, into the host's
  preset/project file. It now goes through `AUv3StateContract` (`Core/BioFeedbackManager.swift`,
  compiled by the app and the extension): **PERSIST** `baseFrequency`, `textureAmount`,
  `reverbMix`, `masterGain` · **TRANSIENT** the four bio inputs, never written, and the base
  class's parameter blob (`kAUPresetDataKey`), which also held them, is stripped on save ·
  **LEGACY READ-ONLY** an older document's bio keys are accepted, never applied (the live values
  are held across the restore), and omitted by the next save. Host automation LANES on the bio
  parameters are host-owned documents and outside this contract. Guard:
  `Tests/CISmoke/TheAUv3SavesNoBodyReadingTests.swift`. Not host-verified.
- No medical or healing claim is made or implied by any part of this contract.

---

## J. Preset / persistence contract

| Kind | Holds | Owner | Must NOT hold |
|---|---|---|---|
| **Device instance state** | every INST item of §B for one placement, versioned | the Session, in the track's device slot | transport, routing endpoints, other tracks, raw bio, UI chrome |
| **Device preset** | a (possibly partial) instance state + name/tags | the device TYPE's preset library (app-level) | anything the instance state must not hold, plus: key-follow target, phrase-to-session bindings |
| **App default** | what a NEW instance starts from; libraries (patches, moods, FX presets); display prefs | the app | Session content |
| **Session snapshot** | the whole `DMMWProject` incl. all instance states | the Session | endpoint/hardware config, credentials |

**Mapping today's preset concepts:**
- `SynthPatch` (PatchStore) → a **sub-preset** of the Echoel Device (the sound section). **It is a
  sound/patch COMPONENT, not the whole device instance state** (WA3.1 amendment): mood, FX,
  rhythm/phrase, routes and visual response are separate sections. Stays a
  library, loadable into any instance. `SynthPatch.apply(to: EchoelDDSP)` already compiles in both
  targets and is the natural shared carrier.
- `MoodPreset` → sub-preset (the mood section).
- `FXPreset` → sub-preset (the FX section); also a future insert-device preset.
- **Echoel Device preset** (new, not built) = sound + mood + FX + rhythm/phrase + field + device
  routes + visual response. No such whole-device preset exists today.
- `Project` v1 → legacy import source (WA2), read once into one Echoel instance on one track.
- `TrackFXStore` role inserts → part of the Echoel instance's internal mix, not a track insert.

**Versioning:** state carries `stateVersion`; decoders are lossy-tolerant per field and never
discard the whole state on one unknown value.

**WA3.2 foundation — `EchoelDeviceState` (`DSP/EchoelBodyVibeDevice.swift`).** `schemaVersion`,
`deviceType`, `patch: SynthPatch?` (one COMPONENT), `parameterValues` keyed by canonical ID.
`sanitized(against:)` keeps only finite, clamped values whose key is a creative descriptor, so a
heart-rate, HRV, coherence or breath-phase key cannot survive it. Lossy per-field decode. ⚠️ **No
production caller yet**: the AUv3 keeps its WA3.1 saved-state format, and nothing in the app writes
this value; mood, FX, routes and the rest of §B's INST list are still absent from it.
⛔ **Before its FIRST production reader or writer (WA3.3 debt note), the boundary MUST enforce:**
`sanitized(against:)` on every decode and every write; `deviceType` validated against the device
it is loaded into (reject, never coerce); a supported-`schemaVersion` check with an explicit
policy for newer and older versions; and a written migration policy. ⛔ "Today's lossy decode
defaults a missing `schemaVersion` to the current one, which is safe only while nothing reads it"
stood here. ⭐ **The boundary is BUILT (2026-09-24, P3) — value layer only, still no caller:**
`restored(from:into:)` (decode → the state must be for the device it is loaded into, reject never
coerce → `validated()`) and `encodedForStorage()` (`validated()` → encode). `validated()` =
`migrated(_:)` (THE migration entry point; a future version is refused as `futureSchema`, never
downgraded; below v1 or an unreadable key is `invalidSchema`; a missing key reads as v1) →
`creativeDescriptors(forDeviceType:)` (unknown type → `unknownDeviceType`) → sanitize values and
fold the patch into `SynthPatch.Bounds`. Guard: `TheDeviceStateBoundaryFailsClosedTests`.

---

## K. Native / AUv3 / future plugin adapters

```
Echoel creative core   (instance state · composer · engine; Foundation / Accelerate)
   ├── Native DMMW adapter   ← today's app wiring, re-expressed per instance
   ├── AUv3 adapter          ← Sources/EchoelmusicAUv3 (exists)
   ├── VST3 adapter          ← future; not implemented; no dependency added
   └── CLAP adapter          ← future; not implemented; no dependency added

Session ──(DeviceInstance values)── Device host
                                      ├── native devices
                                      └── hosted-plugin adapter  ← future third-party hosting
```

**The common core owns:** state value and its versioning · parameter descriptors · the compile
step (state → engine snapshot) · the engine (voices, FX) · the composer · route evaluation.

**Each adapter owns:** its format's parameter tree built FROM the descriptors · host timing and
musical context → Session-context snapshot · event translation (`AURenderEvent`, UMP, CLAP
events) · state (de)serialization into the format's blob · the editor host view · bus layout
negotiation · sample-rate adoption (the AUv3 already adopts the host rate, #1407).

**The existing AUv3 today** (measured): its own 8-parameter tree, no `SynthPatch`, no composer,
a mono last-note-priority voice (`EchoelDDSP`) plus `EchoelCellular` texture, block-granular MIDI
1.0 events, and **no App-Group entitlement** (removed because every host failed with -3000), so
its vitals bridge silently falls back to host-set values. It is a separate, smaller instrument,
not the app's Echoel instrument. **WA3 does not rewrite it.** Its tree is now built from shared
descriptors plus the adapter mapping (WA3.2, §G); carrying `SynthPatch` is still a later slice.
Dropping bio from `fullState` is DONE (WA3.1, §I).

**WA3.3 — "Reverb" (address 6) is audible and anchored.** WA3.2 measured it as bound but
inaudible: the binding wrote `EchoelDDSP.reverbMix` only; that field's one reader, the convolution
stage, is off (`useConvolutionReverb = false`); and the render-side `applyBioReactive` rewrote it
about 10 times a second from `bioBaseReverbMix`, which the AUv3 never set. Repair:
- **Anchor:** the binding writes `bioBaseReverbMix` (plus `reverbMix`), the same pair
  `SynthPatch.apply` writes in the app. `allocateRenderResources` seeds it from the host value.
- **Law:** `EchoelDDSP.bioModulatedReverbMix(base:hrv:)` = anchor + (HRV − 0.5) · 0.12, clamped
  0…1. A neutral body leaves the host value exactly. The ceiling was 0…0.9, which made host
  values above 0.9 unreachable; the only in-app reader is the disabled convolution, so the
  widening changes nothing the app can hear.
- **Consumer:** `EchoelBodyVibeDevice.renderSpace` feeds the synth through `EchoelReverb` (the
  Freeverb stage the app's FX chain already runs on its audio thread), wet by the effective
  mix. The texture stays dry, as with the old convolution stage. At mix 0 the output is the
  pre-WA3.3 dry signal.
- **Rate (2026-09-24):** `EchoelReverb.setSampleRate` rebuilds the tanks for the host rate in
  `allocateRenderResources`, next to the two engine setters (it allocates, so only there). Until
  then the tanks stayed sized for 48 kHz: a 9 % larger room at 44.1 kHz, half the room at 96 kHz.
- **Tail (2026-09-24):** `tailTime` = synth release + the reverb's slowest-mode T60
  (`EchoelBodyVibeDevice.tailSeconds`, ≈ 2.0 + 2.48 s). It was a literal 2.0 s, the release alone.
- **Initial state (2026-09-24):** `EchoelBodyVibeDevice.seed` writes ALL four creative values
  (pitch, texture, reverb anchor, output gain) from the tree in `init` and again in
  `allocateRenderResources`. Until then only the reverb was seeded; the texture played a literal
  0.15 while its knob showed 0.3, because the tree's defaults are written before the observer
  that calls `apply` exists. A fresh instance's texture is therefore louder than before — the
  displayed value is now the audible one. Host listening owed.
- **Host values (2026-09-24, P8e):** every creative value arriving from a host passes
  `EchoelBodyVibeDevice.admitted` (non-finite → refused, the engine keeps what sounds; otherwise
  clamped to the descriptor), in `seed` and in both observer branches. Before, a NaN Master Gain
  reached the host's bus. Guard `TheHostValueIsAdmittedOnceTests`.
- **Texture realtime safety (2026-09-24, P8a/c/d):** `EchoelCellular.seed` no longer shares its
  cell buffer (the first render evolution used to copy-on-write); `CARule` is one byte (the
  control thread replaced a heap-table struct under a live render read on every Coherence write);
  a non-finite coherence selects a rule instead of trapping in `Int(…)`. All three are
  sound-neutral.
- **Render-contract repairs (2026-09-24, P8f–P8l, one commit each, NOT host-verified):**
  one admission rule, `ParameterDescriptor.admitted(_:)`, for both host writes and restored
  state · AU-owned output buffers when a host passes null `mData` (the `AURenderBlock`
  contract) · the voice starts from the admitted pitch, not the raw parameter · a bio write moves
  only its own mirror, clamped to `legacyLiveControlRange`, and a non-finite write is refused ·
  a block larger than the scratch returns `kAudioUnitErr_TooManyFramesToProcess` · `deinit`
  cancels the vitals timer · `shouldChange(to:for:)` accepts only non-interleaved Float32.
  Each has a guard in `Tests/CISmoke` (mostly source scans; the extension cannot be
  instantiated in the bundle).
- Every creative host parameter must have a runtime binding
  (`EchoelBodyVibeAUv3Mapping.resolveBindings`), or setup throws `unboundCreativeParameter`.
- The APP's convolution reverb is unchanged: still off, still unclaimed.

**One AUv3 fact WA3.2 measured and did NOT change:**
- **The factory presets still seed coherence (HOLD-FOR-FOUNDER).** Ambient Calm 0.7, Deep Sleep
  0.8, Active Focus 0.5. Coherence shapes the synth's cutoff, brightness and harmonicity and
  selects the texture's cellular rule (`Int(c·7)`: 0.5→rule 105, 0.7→184, 0.8→73). No creative
  parameter is equivalent, so removing the seed would change two presets' sound materially. The
  seed is isolated as `Preset.legacyCoherenceSeed`, outside creative values; it is the preset
  path's only bio write, and removing it is a founder call.

**Two AUv3 facts measured 2026-09-24 and deliberately NOT changed (host / founder):**
- **Host automation as render events is ignored.** C3 above requires "parameter changes as
  timestamped `(address, value)`". The render block handles only `.MIDI`; a host that automates
  through `scheduleParameterBlock` delivers `.parameter`/`.parameterRamp` events and they are
  dropped. Hosts that write `AUParameter.value` reach the observer and work. Which path AUM,
  Logic and GarageBand use is unmeasured. Proposed repair (not built): a table indexed by address,
  precomputed in `init` (binding + range; no Dictionary or String on the render thread); ramps
  applied as steps; bio addresses into `bioMirror`; force `CARule.harmonicRules` initialisation
  in `init` so the render thread never takes its `swift_once`. HOST VERIFY FIRST: automate a
  knob in each host and listen.
- **The texture's cellular automaton updates IN PLACE**, so its rules are not the Wolfram rules
  they are named after (the left neighbour is already the new value). Simulated from the
  one-cell seed: rule 184 empties the automaton, and only rules 105 and 73 (bit 0 set) can switch
  cells on from all-zero, so the texture stays silent until coherence selects one of those two.
  With no live bio, **Ambient Calm's seeded coherence 0.7 selects rule 184**. Rules 150, 110 and
  30 light a partial cell only after about 33 evolutions (~4 s at 8/s). A true double buffer
  changes every rule's sound, so it is a founder / listening decision, not a fix.

**Three more AUv3 findings measured 2026-09-24 and NOT changed (product or host decision):**
- **`reset()` is not overridden.** A host that calls it on transport stop expects tails and
  voices cleared; the reverb tail and the held note survive. Clearing them needs a decision
  about what "reset" means for a bio-driven drone (silence, or re-seed and keep sounding).
- **Base Frequency retunes a held MIDI note.** `apply` writes `synth.frequency`, the glide target
  of whatever sounds, including a key the host is holding. Whether the knob is a transpose or
  only the drone's pitch is a product call.
- **`bioInterval` is captured when the host fetches the render block**, not per render. A
  sample-rate change without a re-fetch keeps the old interval. Hosts normally re-allocate and
  re-fetch; HOST VERIFY before building anything.

**Third-party hosting seam (not implemented).** A hosted plugin appears to the Session as a
`DeviceInstance` whose `typeID` names the adapter and whose `state` is the plugin's own opaque
blob plus its component description. The Session never imports `AudioToolbox` or AUv3 types;
only the hosted-plugin adapter does. `HISTORY_ARCHIVE` L2 classes the old host path
(`AVAudioUnitComponentManager`) as PORT ALGORITHM.

---

## L. Multi-instance proof (model check)

```
Session
├── Track A → Echoel Device A   keyFollow=.session  mood=dark   own FX  route HRV → filter
├── Track B → Echoel Device B   keyFollow=.session  mood=bright own FX  route motion → grain
└── Track C → third-party AUv3 (hosted-plugin adapter)
```

| Check | Holds under the contract? | Why | Today |
|---|---|---|---|
| A cannot overwrite B | ✅ | separate `instanceID`, separate state values, separate engine objects | ❌ one `currentPatch`, one `polyVoice`, one `mixer.*` |
| both share Session context | ✅ | same read-only snapshot (key, A4, tempo, transport) | partially (global keys) |
| same bio source used differently | ✅ | one bus, two route lists | ❌ one matrix, one FX modulator |
| automation addresses the right instance | ✅ | `device.<A>.ddsp.filter.cutoff` ≠ `device.<B>.…` | ❌ global keyPaths reach `polyVoice` only |
| presets are instance-local | ✅ | loading a preset writes one instance's state | ❌ loading a patch writes the global patch |
| plugin adapters are not Session owners | ✅ | the Session stores Track C's blob; the adapter renders it | n/a |
| **B's route "motion → grain"** | ⚠️ **declarable, not satisfiable** | `motionControl` has no producer; "grain" is not an Echoel parameter (granular went with #1305; `HISTORY_ARCHIVE` B5 = PORT ALGORITHM) | ❌ |

**Verdict: the contract is multi-instance-safe.** Today's code is not, for the four structural
reasons in §B. The model check also shows what the test scenario asks for that does not exist:
a motion producer and a granular parameter. The contract makes such a route *storable* and
visibly unsatisfied — never silently accepted as working.

**Resource note, measured:** one Echoel instance today means six global voice objects (12 + 3 +
2 + 6 poly voices, a sub, a bio voice) plus FX chains. Instancing multiplies that; the
implementation phase must measure CPU and memory per instance against the hard limits (CPU < 30 %,
memory < 200 MB) before allowing more than one.

---

## M. Current-state migration map (recommendation only — nothing migrates in WA3)

| State (§B #) | Future destination |
|---|---|
| `currentPatch` (1), articulation (3), lead/bass patch choice (5) | **DEVICE INSTANCE** |
| `studio.presetIndex` (2) | **REMOVE LATER** (replaced by `presetRef` provenance) |
| `PatchStore`, `MoodPresetStore`, `FXPresetStore` (4, 13, 29) | **APP DEFAULT** (libraries) |
| `touch.*`, `field.autoPlay.*` (6, 7) | **DEVICE INSTANCE** (the field surface belongs to the device) |
| genre, mood, variation, rhythm characters, pad shape, auto mode (8, 12, 14, 15, 18) | **DEVICE INSTANCE** |
| `studio.loopBars` (16) | **DEVICE INSTANCE** (phrase length); the Session loop is separate |
| key/scale `studio.*` + `SessionContext` mirror (9) | **SESSION** (one owner) + per-instance `keyFollow` |
| A4, tone system (10, 11) | **SESSION** |
| BPM lock / Flow-Loop (17) | **SESSION** (transport mode) |
| performer signature (19) | **APP DEFAULT** (per person) |
| generation state (20) | **RUNTIME CACHE** |
| role mix `mixer.*`, `touch.level`, `trackfx.*` (21, 22, 30) | **DEVICE INSTANCE** (internal mix) |
| metronome (23), master volume (24), loudness/master character (25) | **SESSION** |
| FX chain params, FX character, delay sync (26–28) | **DEVICE INSTANCE** |
| modulation matrix synth routes (31) | **DEVICE INSTANCE**; tempo route → **SESSION** |
| FX bio routes (32) | **DEVICE INSTANCE** (merged into the one route list) |
| body-voice arm (34) | **RUNTIME CACHE** (activation, re-armed by START) |
| bio source (35) | **APP DEFAULT** (sensor choice) |
| visual response keys (37, subset) | **DEVICE INSTANCE**; display keys → **APP DEFAULT** |
| mood pads (38) | **REMOVE LATER** (no reachable writer) |
| MIDI out switches (39) | **APP DEFAULT** (endpoint); per-device MIDI-out routing → **SESSION** later |
| routing graph (40) | **SESSION** (logical) + **APP DEFAULT** (endpoints) |
| voice objects, rack (41, 42) | **RUNTIME CACHE / engine resources** per instance |
| `TimelineLane.patch/genreOverride/mood/variationSeed` (44) | **LEGACY IMPORT** into the lane's instrument instance |
| `Project` v1 (45) | **LEGACY IMPORT** |
| `DMMWProject.sound` (46) | **LEGACY IMPORT** → the first track's Echoel instance |
| `DMMWProject.musical.styleRaw/modeRaw/moodFields` (47) | **LEGACY IMPORT** → device instance (genre, mood); `modeRaw` → Session transport mode |
| `SoundReset.entries` | the existing inventory of "sound identity" keys — reuse as the checklist for the instance schema |

Constraint on every row: **no persisted key or decoder is deleted while a build that wrote it may
still be installed** (#527). Migration is import-once, never rewrite-in-place.

---

## N. Historical reuse

From `HISTORY_ARCHIVE.md` (class quoted from its legend), as it bears on the Device model:

| Item | Class | Device role |
|---|---|---|
| A1 `EchoelDDSP` / `PolySynthVoice` | CURRENT | the Echoel engine |
| A2 `SubBassVoice`, A3 `BioReactiveSynthVoice` | CURRENT | Echoel engine voices |
| A4 `EchoelModalBank` | REUSE | a future percussion device engine |
| A5 `EchoelCellular` | REUSE (app target) | texture layer; already live in the AUv3 |
| A6 `SamplerVoice` | REUSE | a sampler device |
| A7 historical synth engines (Karplus-Strong, FM, supersaw) | PORT ALGORITHM | sibling engines inside or beside the Echoel device |
| A8 historical bass (ladder, 303 slide/accent) | PORT ALGORITHM | bass device / Echoel bass role |
| A9 drums | REBUILD | a percussion device (ModalBank + ported kick/hat math) |
| B1 `EchoelFXChain` | CURRENT | the Echoel device's FX section; later insert devices |
| B2 FDN reverb, B3 convolution/space | REUSE / PORT ALGORITHM | insert devices |
| B4 harmonizer, B5 granular, B6 phase vocoder | PORT ALGORITHM | future processor devices (granular's source must be a buffer or clip, not a mic) |
| D3 piano roll | REBUILD | a Session editor, not a device |
| L1 AUv3 plugin | CURRENT | the AUv3 adapter |
| L2 historical plugin hosting | PORT ALGORITHM | the hosted-plugin adapter |
| L3 VST3/CLAP | REBUILD | future adapters |
| `PatchEditorView`, `ChannelRackView`, `BrowserView`, `ArrangeTimelineView` | **DO NOT RESTORE** as shells | their capabilities return through the Device/Session contracts, never as the old views (UI law) |

---

## O. Implementation boundaries

**WA3 decides:** the three-layer Device model; the descriptor/instance/runtime contract;
capabilities as declarations; `device.<instanceID>.<base>` addressing on the one parameter
system; the two parameter-field additions (scaling, host address); bio as ControlSource with
routes as instance state and raw values excluded; one route list per device; automation vs
modulation stores; the preset taxonomy; the Session-context snapshot and "device reads, never
writes"; the Track fields and the five non-synonyms; the adapter split; the hosting seam; the
per-key migration destinations.

**WA3 does NOT authorize or implement:** any Swift type, protocol, file move or test; a Track
type; multi-instance migration; persistence changes; the EchoelCore target; changes to the AUv3
(including the `fullState` bio defect); VST3/CLAP; plugin hosting; a workstation shell, Arrange
UI or Session launcher; removal or restructuring of `EchoelStudioView`; video; broadcast; new
root navigation.

**Prerequisites before the first implementation slice:**
1. **A home for the contract types** that the AUv3 compiles and that is not `DSP/`: the
   EchoelCore target — **founder-gated (#95, `project.yml`)**.
2. **The note engine out of the SwiftUI file**: `PianoRollModel` from `Studio/PianoRollView.swift`
   into a SwiftUI-free file (a pure move, no behaviour change).
3. **One realtime channel pattern** chosen for new code (§F4), so the first instanced device does
   not add a fifth path.

**Suggested first slices (each separately approved; order matters):**
1. Descriptor additions only: `scaling` and `hostAddress` on `ParameterDescriptor`, filled for the
   DDSP catalog, with a guard that host addresses are unique and stable.
2. The `EchoelDeviceState` value assembled read-only from today's globals (no writer, no
   migration) plus a round-trip guard — the #1416 "importer first, writer second" pattern.
3. The `device.<instanceID>.<base>` resolver beside `PerTrackParameterKeyPath`, resolving to the
   one existing instance.
4. Only then: a second instance, behind a flag, measured for CPU/memory.

---

## P. WA4 prerequisites

WA4 (Arrange + Session front) may start when:
1. **This contract is accepted** (founder decision on this document, logged in `decisions.csv`).
2. **The EchoelCore hold (#95) is decided**, or an interim home for the contract types is named.
3. **The Track contract (§D) is accepted** as the model the Arrange front edits — the front edits
   tracks, and a track's instrument slot is a Device instance, never a lane field.
4. **The Echoel instance state has at least its read-only assembly** (slice 2 above), so the
   front can show "this track's Echoel" without inventing a second truth.
5. The UI laws hold unchanged: consolidate the modal chain before adding a surface; hot state in
   leaves; `EchoelValueField`; Uncodixfy; iPhone-first reflow.

WA4 does NOT need multi-instance rendering, plugin hosting or VST3/CLAP. It needs the addresses
and the ownership model to exist so that the first front does not bake in the global singleton.

---

**Stale sources found and not edited (report only):**
- `.claude/rules/swift-audio.md` says `DSP/` has 40 files; measured 38 today
  (`git ls-files 'Sources/Echoelmusic/DSP/*.swift' | wc -l`).
- `CLAUDE.md`: the SHIP GATE line keeps the old reasoning "unreachable once the workstation half
  was dismantled"; the Positioning line calls the product "the first bio-reactive performance
  instrument" (shipped-product positioning, harmless).
- `DMMWProject.musical` carries genre (`styleRaw`) and mood (`moodFields`), which §O makes
  device-local — a schema placement to correct when the envelope gets its first writer.

*Maintenance:* evidence dated 2026-09-24. Re-measure with the named symbols and commands before
acting; do not update counts in place without re-running them.
