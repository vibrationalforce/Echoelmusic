# PLAN — native DeviceChain (Phase 3, after the media library)

Founder order (2026-09-25): MIDI editor → MediaAsset + lazy Browser → **native DeviceChain** →
Echoel as flagship Device → Clips/Scenes/Session → Automation editing → Recording/Input. Every
slice ships architectural progress + a reachable user workflow + behavioural verification.

## Census (read-only, 2026-09-26 01:30Z)

- **No device chain exists.** No `Device` protocol, no `DeviceChain`/`DeviceInstance`/`Track` type.
  `TimelineLane` carries mixer fields plus precursor fields (`builtinInstrument`, `patch`,
  `samplePath`, …). The lane once had `instrument: AUPluginRef?` + `effects: [AUPluginRef]` (U3/H9a);
  hosting and the fields were removed (`126172a92`, `304f7502a`), and OLD SONGS STILL CARRY THOSE
  KEYS (`TimelineDecodeTests` pins them). **The new chain must never reuse `instrument`/`effects`.**
- **Every rack slot `PolySynthVoice` already renders its own `EchoelFXChain`** (`fxEnabled = true`),
  and nothing configures it per lane — the slots play the chain DEFAULTS (saturation, chorus,
  limiter). So a per-lane insert on a secondary MIDI track needs NO new audio node and NO new
  render code: a control-plane write to that slot's chain, the house standard (`FXViewModel`).
- Rack slots are **rank-keyed and pooled**: a slot plays whichever lane holds its rank. Every
  per-lane voice value (patch, transpose, detune, octave, pan, gain) is therefore pushed at each
  of the FOUR load sites in `TimelineRegionPlayer` and live through `refreshMixer`/`mergeMixer`.
- WA3 (`NATIVE_DEVICE_ARCHITECTURE.md`, approved): §D "Device chain | `instrument: DeviceInstance?`
  (0…1) + `inserts: [DeviceInstance]` (0…n)"; §C2 an instance is `(instanceID, typeID, typeVersion,
  stateVersion, stateBlob)` and "an unknown `typeID` is kept verbatim and rendered silent … never
  dropped (#527)"; §P "a track's instrument slot is a Device instance, never a lane field".
  §O did not itself authorize Swift types — the founder's Phase 3 order ("native DeviceChain") is
  that authorization. The contract's final home, the `EchoelCore` target, is founder-gated (#95);
  the interim home is `Sources/Echoelmusic/Core/`, the `MediaAsset` precedent.
- Audio lanes have no per-lane node; an insert there needs a graph attach at prime (a larger,
  route-resilience slice). The Echoel (roll) track's FX is the Echoel device's own section.

## Council — DC1

- **Architect:** the §D shape, minimally: `DeviceChain { inserts: [DeviceInsert] }` as an OPTIONAL
  field on `TimelineLane` under the NEW key `deviceChain` (nil = today, bit-identical; an absent key
  writes nothing, so no saved song changes bytes). `DeviceInsert` = `(id, typeID, typeVersion,
  isEnabled, stateBlob: Data)`, so an unknown type round-trips verbatim. The instrument slot stays
  DERIVED (`builtinInstrument`/roll rule) — a second instrument truth is the thing §P forbids.
- **DSP Purist:** nothing new on the audio thread. One known insert type, `echoel.fx.character`,
  whose state is an `FXCharacter` raw value, applied by `FXCharacter.applyOwnPreset(to:bpm:)` to
  the slot voice's existing chain. "None" resets the chain to the snapshot it had at attach.
- **Skeptic:** (1) an array that can hold three inserts while one chain can sound only one is a
  claim — DC1 SOUNDS the first enabled known insert, the UI writes at most one, and the type says
  so. (2) Pooled slots: push on every load, never rely on a clear. (3) A picker edit during play
  must not relocate voices at 8 Hz → the field flows through `mergeMixer`, and
  `structurallyEqual` ignores it. (4) `.auto` needs a genre the lane does not own → not offered.
- **User-Advocate:** the row appears only where it sounds (`.laneSynth(.poly)`), never on the
  Echoel track (its FX is "Open"), audio, bio or voiceless tracks. Names are the existing
  character names. "Default" = the rack voice's shipped sound, not "dry" ("Clean (dry)" is dry).
- **Vision-Keeper:** no new effect claims; nothing for store copy until device-verified.
- **Shipper:** DC1 = value + persistence + one writer + load/live push + one inspector row + a
  guard. Performance law: a picker is one bounded commit.
- **→ Gate: proceed.** Log: `decisions.csv` + `memory/decisions.md` (DeviceChain shape, interim
  home Core/, key `deviceChain`, DC1 = one sounding insert on rack MIDI lanes).

## Slices

### DC1 — one effect per extra MIDI track — BUILT (2026-09-26, guard `TheTrackEffectIsADeviceOnTheLaneTests`)
- `Core/DeviceChain.swift`: `DeviceChain`, `DeviceInsert`, `soundingCharacter`, `settingCharacter`.
- `TimelineLane.deviceChain: DeviceChain?` (key `deviceChain`, `try?` decode), `mergeMixer` +
  `structurallyEqual` treat it as live.
- `TimelineStore.setLaneEffect(_:character:)` — the one writer.
- `MultiRollFanout.effect(forSlot:)` (answers with `soundingCharacter`); `TimelineRegionPlayer.slotEffectSink` at the four load
  sites + `refreshMixer`; `EchoelmusicApp` wires it to `LaneVoiceRack.setEffect(slot:character:bpm:)`
  (default snapshot per slot at attach).
- `GenreFX`: `FXCharacter.applyOwnPreset(to:bpm:)` — the clean bypass shared, not copied (#416).
- `TrackInspectorView`: an "Effect" menu on `.laneSynth(.poly)` tracks.
- Guard `TheTrackEffectIsADeviceOnTheLaneTests`. Device check: NEEDS-FOUNDER-VERIFY.

### DC2 — (after DC1 lands) effect parameters / a second insert type
Decided from DC1's device report; not before.

### Later — audio-lane inserts (graph attach at prime; `avaudio-route-resilience` pass first).

### As built — what differs from the list above
- The rack DEDUPES per slot on (character, whole BPM): a mixer drag re-runs `refreshMixer` at
  drag rate and must not re-stamp a whole preset each time. A tempo glide does not re-stamp either;
  a tempo-synced echo follows the song at the next change of character or whole BPM.
- `setEffect` writes `voice(slot:)` whatever the slot's binding, exactly like detune/octave: a
  sub/sampler/bio-bound slot's poly voice is silent anyway, and the next poly lane in that slot
  gets its own push before its first note.

### Review of e061ca2d3 (no HIGH) — repaired in the next commit
- M1: a character insert of a LATER `typeVersion` is not read (`DeviceInsert.character` gates on
  `characterTypeVersion`), and choosing an effect over it re-stamps version AND state together.
- L1: the header now states the limit — "kept" is for an unknown TYPE in this envelope; a changed
  envelope is a migration.
- L2 (doc moved off the #338 tuning latch) · L3 (GenreFX names the fifth stamp site: a rack
  chain plays the character's own division, and #240 still holds) · L4 (app comment: the tempo
  is read at every push, incl. `refreshMixer`) · L5 (`installVoicesForTests` takes the snapshot).
- L6, OPEN and pre-existing: `KindVoiceAllocator` puts a SECOND sampler/sub/bio lane on
  `.poly(slot)` when the single unit is taken, while `TrackMix.role` still reports its declared
  kind — so the Effect row is hidden on a lane that really plays through a poly chain (nil is
  pushed, the default plays — no inheritance). Fix belongs with "role = the ALLOCATOR's binding",
  a separate slice (the inspector would need the rack's live binding, not the document).
