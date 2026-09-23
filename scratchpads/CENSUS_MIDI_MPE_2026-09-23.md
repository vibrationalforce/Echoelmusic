# Census #3 — MIDI / MPE professional gap (2026-09-23, read-only)

Founder brief: classify each function as IMPLEMENTED / PARTIAL / DOORLESS / SCHEMA ONLY /
MISSING, and say which Echoel MUST OWN vs MUST INTEROPERATE vs LATER.

**Scope measured:** `Sources/`. CoreMIDI is imported in exactly TWO files —
`Audio/MIDIInput.swift` and `Audio/MIDIOutput.swift`. Everything else is pure value code
(`MIDIEventParse`, `MPEExpression`, `UMPEncoder`, `MIDIFileExporter/Importer`,
`EchoelMIDIDecode`) or a surface (`PatchbayView`, `BluetoothMIDIPairingView`).

⚠️ **TWO MEASUREMENT TRAPS COST A FALSE FINDING EACH IN THIS CENSUS. Both are the
substring class `.claude/rules/context.md` §2 warns about, and both failed in the
REASSURING direction — they made a capability look present or absent when it was the
other way round.**

1. **`mpe` is a substring of `tempo`.** An un-bounded `grep -l 'mpe\|MPE'` returned ~200
   files — half the repo — and reads as "MIDI is everywhere". The bounded form
   (`\bMPE\|\bmpe[A-Z]`) returns 21.
2. **`RPN` is a substring of `SHARPNESS`, and `SPP` of `DDSPParameterCatalog`.** The raw
   needles returned 31 and 7 hits; word-bounded, RPN's real hits are all in prose and SPP's
   are all zero. I nearly recorded "nothing sends the MPE zone RPN" as a finding — it was
   FALSE: `MIDIOutput.sendMPEConfiguration()` sends `CC101=0 / CC100=6 / CC6=<count>` at
   line 418. **The bytes were one `sed` away and the needle never looked at them.**
   ⭐ LAW: when a needle's hit list names files that have nothing to do with the question
   (`MetalBioView` for an RPN query), the needle is broken — read the hits, not the count.

---

## IMPLEMENTED (code + reachable door)

| Function | Evidence |
|---|---|
| MIDI 1.0 note on/off, CC, channel pressure, pitch bend — **IN** | `MIDIEventParse.event(word0:word1:)` case `0x2`, sub-cases 0x90/0x80/0xB0/0xD0/0xE0 |
| MIDI 1.0 note on/off, pitch bend, CC, channel pressure — **OUT** | `MIDIOutput.noteOn/noteOff/sendExpression` |
| **MIDI 2.0 / UMP channel voice — IN** | `MIDIEventParse` case `0x4`: 16-bit velocity, 32-bit CC, 32-bit pressure, signed 32-bit bend. `MIDIInput` opens the port with protocol `._2_0` |
| **MIDI 2.0 / UMP — OUT** | Second virtual source via `MIDISourceCreateWithProtocol(…, ._2_0, …)`, mirrored through `UMPEncoder.note2On/note2Off/controlChange2/channelPressure2/pitchBend2`. Default OFF (`StudioDefaultKeys.midiOutUMP2`), door in `PatchbayView` |
| **MPE OUT (real)** | Zone RPN on port open AND on re-arm; per-note Glide (14-bit bend) + Slide (CC74) + Press (0xD0) on the allocated member channel, emitted **before** the 0x90 (#1221). Two doors in `midiOutSection`, the second gated on the first |
| MIDI Clock OUT (24 PPQN) + Start/Stop | `startClock`/`stopClock`/`setClockTempo`, `UMPEncoder.RealTime{clock,start,stop}` |
| MIDI file export / import | `MIDIFileExporter` (doored via the export slot, #188), `MIDIFileImporter` (**doorless** — dead chain) |
| RTP-MIDI / network session | `MIDINetworkSession`, preference-driven, door in `PatchbayView` |
| Bluetooth MIDI pairing | `BluetoothMIDIPairingView`, reachable from `PatchbayView` |

## PARTIAL

- **MPE IN.** All three dimensions now SOUND (bend always, Press → `expressionGain` #939,
  Slide → `renderCutoffScale` #942) — and it is still **not MPE**, because there are no
  ZONES: RPN 6,6 has no consumer inbound, and `BioReactiveSynthVoice.apply(controller:)`
  never reads `event.channel`. The single `controllerEvents` consumer is monophonic, so
  zones without a second consumer would be inert (`PLAN_MPE_ZONES_2026-09-01.md`).
  Already correct in CLAUDE.md and pinned by `TheMPEInputHasNoZonesTests`.
- **Clock OUT drift.** Its own repeating `DispatchSourceTimer` vs. the 4 PPQ step grid;
  nothing re-syncs them, and there is no SPP to re-sync WITH. Documented at the property.

## MISSING (measured zero, word-bounded)

| Function | Consequence |
|---|---|
| **Song Position Pointer (0xF2)** | A slaved rig can only ever start at bar 1, and the documented clock drift has no correction channel. This is the single highest-value missing byte for "professional". |
| **Continue (0xFB)** | `RealTime` has only clock/start/stop, so Stop→Start always restarts the receiving rig from zero |
| MTC / quarter-frame | No frame-accurate sync to video/film rigs |
| Program Change / Bank Select on the live port | Only in the file exporter/importer; `MIDIOutput` cannot select a patch on an external instrument |
| Poly Aftertouch (0xA0) on the live port | Only in the file importer |
| NRPN | — |
| Note-off velocity | `noteOff` sends a bare note-off |
| MIDI Thru | — |
| JR (jitter-reduction) timestamps | MIDI 2.0 timing precision unused |
| **`MIDIDestinationCreate`** | Echoel publishes a virtual **source** (it can be heard) but no virtual **destination** — another app cannot address Echoel by name; input only arrives by `connectAllSources()` onto existing sources |

## SCHEMA ONLY / INERT (checked to the consumer — do NOT record as defects)

- `SignalTransport.midi2` is `.roadmap`, while MIDI 2.0 in/out actually ships. **Inert:**
  measured at the consumer, **no `SignalPort` carries `transport: .midi2`**, so
  `defaultInventory()` filters nothing on its account and `statusTag` never renders "soon"
  for it. Nothing mislabels anything to a user. ⭐ The same trace refutes the tempting
  #1438 reading ("the machine beats the label") — the label has no surface.
  What IS real and small: the routing model cannot express "this sink speaks MIDI 2.0";
  `midi.out` stays `transport: .coreMIDI` whether or not `ump2Enabled` is on. LATER.
- The `.midi2` case comment says "(+ MIDI-CI capability inquiry)". MIDI-CI has zero code.
  A parenthetical capability claim in a comment — cheap to strike, no surface reads it.

## MUST OWN vs MUST INTEROPERATE vs LATER

- **MUST OWN:** note + expression semantics into its own voices; the master clock (Ω48 —
  one clock, and Echoel exports rather than follows today).
- **MUST INTEROPERATE:** zone announcement (done), UMP (done), clock export (done, drifts),
  MIDI file export (done). **SPP + Continue belong here and are the gap.**
- **LATER:** MIDI-CI / property exchange, JR timestamps, MTC, virtual destination,
  a `.midi2` transport on the routing model.

## RECOMMENDED NEXT SLICE FROM THIS CENSUS — **NONE. And the retraction is the finding.**

⛔ **MY FIRST ANSWER WAS "Song Position Pointer + Continue", AND THE REPO HAD ALREADY
REFUTED IT, IN THE DOC COMMENT ON THE VERY ENUM I WOULD HAVE EDITED.**
`UMPEncoder.RealTime` explains in full why it has three cases and not five: `Transport.play()`
resets `position` to zero unconditionally and the clock is emitted ONLY from that play edge,
so every start in this app IS a start from the top and Start (0xFA) is correct every time.
Measured independently here: `git grep -n '\.seek(toBar' -- Sources` returns **zero**
production callers, so nothing can put the transport anywhere but bar 0.

**Consequence: SPP would transmit a constant 0 forever, and Continue would be a case with no
producer** — the "lying vocabulary" that doc names. The bytes are not the gap; a
resume-from-position transport is, and its absence is deliberate (the arrangement surface is
CUT). The doc even states the re-check condition — *"A reason that only holds while nobody
adds a caller has to be re-checked whenever a caller is added"* — and the condition has not
fired.

⭐ **THE REAL FINDING OF THIS CENSUS, and it is bigger than any single byte: almost every
MISSING row above is blocked on a missing PRODUCER, not a missing encoder.** Program
Change / Bank Select has no surface that would choose a patch; note-off velocity has nothing
measuring release; poly aftertouch has no source; MTC has no timecode owner. This is the
#527 shape — the one that already dominates this repo — appearing a fourth time in a fourth
domain. **A MIDI feature list is therefore the wrong planning instrument here; the useful
question is always "what would SEND this?"**

The ONE row that is genuinely encoder-side and producer-free is `MIDIDestinationCreate`:
publishing a virtual DESTINATION so another app can address Echoel by name, where today
input only arrives via `connectAllSources()` onto sources other apps publish. That is
infrastructure, not vocabulary, so it has no producer problem — but it is a new CoreMIDI
object with its own lifecycle in a file that already owns two, and `MIDIInput`/`MIDIOutput`
are the app's only CoreMIDI owners. **Council-sized, not slice-sized. Recorded, not started.**

⭐ **LAW FOR THE NEXT CENSUS, paid for twice today (the RPN needle, then this): before
recommending a slice, read the doc comment on the type you would edit.** Both times the
answer was already written at the exact line, and both times a needle-level measurement
pointed the other way. A census measures what EXISTS; it does not measure what was already
DECIDED, and this repo writes its decisions next to the code rather than in a plan file.
