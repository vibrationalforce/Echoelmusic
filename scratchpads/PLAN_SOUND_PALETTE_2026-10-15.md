# Plan — Echoelmusic's own sound palette (2026-10-15)

Founder: „Eigene Echoelmusic Drums, rhythmische Moog und acid bass pattern, deep tech glitches,
psychedelic effects and patterns, dub chords, lead sounds, classic Elektro vibes." Decision row in
`decisions.csv` (same day): in-app drums return; the 2026-07-07 drum cut and the 2026-07-09
„reine Flächen" for dub are phase history under the 2026-09-24 product law. Hardware (TR-8S via
HW-10) stays an optional second voice.

## Measured building blocks (read-only map, file:line on `main` e75d99b7f)

| Want | Exists | Live? | Gap |
|---|---|---|---|
| Drums | `DSP/EchoelModalBank` (871 lines, `.drum` material, `excite`, `render`) | orphaned; allocates in `morphMaterials`/`getSpectralEnvelope`, 64 sines/sample → bake offline, never live | no kick pitch sweep, no noise layer |
| | `SamplerVoice` (4 rack units, `previewVoice`) | live | loads only from URL (`installBuffer` internal) |
| | `PatternEngine` step clock, `onStep` | clock live, `onStep` has no setter | main-queue timer → jitter |
| | `BioComposer` grids four-on-floor / backbeat / offbeat / half-time, 8 tracks | computed, then `silentBeat()` (`EchoelStudioView` ~:11058) | — |
| Acid / Moog bass | `SubBassVoice` (mono, ~5 ms glide), `BassGrammar` 5 figures | live | no acid figure; `.acidTechno` has no bass grammar; SVF not ladder; `filterEnvAmount` never set; `PolySynthVoice.slide` only from touch |
| Glitch | `EchoelBitcrush` (chain), `EchoelDecimator`, `SampleSlicer`, `GrainCloud` | bitcrush only via bio modulator; decimator + slicer orphaned; grain = offline bake | no stutter / beat-repeat / tape-stop |
| Psychedelic | chorus, flanger, phaser, ping-pong delay | live (phaser: sci-fi genre) | no psychedelic FX character; no tempo-synced filter LFO |
| Dub chords | `.dubTechno` FX live (dotted ping-pong, fb 0.58) | live | articulation `.sustained`; `dubMelody` stabs retired |
| Leads | 20 factory patches, additive engine, unison ≤ 3 | live | no band-limited saw/square, no supersaw; most genres no lead |
| Electro | `.electroFunk` offered | live | no `.electro`, no 808 / clap / cowbell voice |

## Order (most sound per slice first)

- **SP-1 Psychedelic FX character** — phaser + flanger + dotted ping-pong as a new `FXCharacter`
  preset. No new DSP. Guard: preset values + offered in the FX picker.
- **SP-2 Dub stabs** — `.dubTechno` chord articulation from `.sustained` to a stab/skank with the
  existing delay doing the tail. Ear check by the founder.
- **SP-3 Drum path (the big one, Council + audio-thread review)** — `SamplerVoice.loadBuffer`,
  `EchoelDrumKit` bakes kick (sine + pitch/amp envelope), snare/clap (noise + modal body), hats
  (filtered noise) once at start into `[Float]`; the composer's grid replaces `silentBeat()`
  behind a Drums switch (default ON for beat-driven genres, OFF for Flächen genres). Timing: the
  step clock's jitter must not reach the drums — schedule hits on the render side (sample offset
  inside the buffer), not from the main-queue timer. Design question for Astra (Auftrag B).
- **SP-4 Acid figure** — `.acidSixteenths` with seeded accent + slide bits; accent → velocity +
  filter envelope, slide → `slide()`; `.acidTechno` maps to it.
- **SP-5 Electro kit** — 808 kick, clap (3 bursts), cowbell (two partials ~540/800 Hz or a baked
  modal-bank voice) + an electro grid; on SP-3's path.
- **SP-6 Leads** — 2–3 factory patches (acid lead, electro lead, wide saw-ish), maybe `maxUnison`.
- **SP-7 Glitch** — tempo-synced beat-repeat/stutter stage in `EchoelFXChain` (preallocated ring),
  then revive `EchoelDecimator` / `SampleSlicer`.

Every slice: standalone (sounds on the phone alone), guard in the blocking bundle, ear check on device.
