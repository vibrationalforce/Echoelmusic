# The Echoel song format (format 4)

A song is a folder ending in `.echoel` — a package of the type `com.echoelmusic.song`, which the
Files app shows as one file and opens in Echoel:

```
My Song.echoel/
  project.json        the song, UTF-8 JSON
  Media/              the audio and video files the song uses, copied in on import
```

A song shared from the app ("Share Song") is the same package, written fresh: `project.json` and
the files in `Media/` that the song names, nothing else. A file the song names but the package
lacks is left out, and the song opens without it, as it would where it came from.

`project.json` is written pretty-printed with sorted keys, so the same song always produces the
same bytes and a diff shows only real changes. Nothing in it is encrypted, compressed or signed.
Every audio and video file is a plain file you can take out of `Media/`.

## Versioning

- `formatVersion` (integer) is required. This document describes **4**. A reader of format 4
  opens every format-3, format-2 and format-1 file too; the differences are at the end
  ("Format 3", "Format 2", "Format 1").
- A file with a **newer** number is refused rather than opened with parts missing; a number below
  1 is refused as damaged.
- An older file is read into today's shape, so saving it writes today's number.
- Inside one format, fields are only ever **added**. A reader treats a missing optional field as
  its default; the fields marked *optional* below were added after the first format-1 builds and
  older files lack them.
- A key it does not know is ignored, except inside an instrument's `values`, where it is kept
  for the build that knows it.
- **A name it does not know** follows one rule. Where the field only chooses how the song plays —
  an instrument's `device`, the `tuning`, the `scale`, a track's `monitor`, a tempo change's
  `curve` — the song opens, the name is kept and saved back unchanged, and it plays as the
  field's fallback: silent, twelve equal steps, chromatic, `auto`, `step`. A track's `kind` decides what the track holds and has no
  fallback, so a new kind comes with a new format number and an unknown one refuses the song.
  The same holds for a parameter address's owner (`project`, `master`, `track`): a new owner is
  a new format number, and an address with an owner this build does not know refuses the song.
- On open, the song is checked against the same rules the editor enforces (ranges, unique ids,
  references that resolve, what each kind of track holds, names). A file that breaks one is
  refused, not repaired silently.

## Units

| quantity | unit |
|---|---|
| time on the timeline | ticks, **960 per quarter note**, integers, from 0 |
| tempo | beats per minute, 20 … 999 |
| level | decibels, −144 (silence) … +6 |
| pan | −1 (left) … +1 (right) |
| pitch | MIDI note number 0 … 127 |
| velocity | MIDI 1 … 127 |
| pitch bend | 14-bit, 0 … 16383, centre 8192 |
| controller | number 0 … 119, value 0 … 127 |
| audio offsets and lengths | sample frames of the audio file |
| video offsets and lengths | units of the video file's `sampleRate` per second (Echoel writes 48 000) |
| ids | UUID strings — unique in the song, except a note's (unique in its clip) and a placement's (unique on its track) |
| names | the song's, a track's, a clip's, a scene's, a media file's: never empty or only spaces; the editor keeps them within 128 characters, a reader takes up to 256 |

## `project.json`

| key | type | |
|---|---|---|
| `formatVersion` | integer | required |
| `name` | string | required |
| `tempo` | number | required; the tempo from tick 0 |
| `tempoChanges` | `[{tick, bpm, curve}]` | optional; ticks rising, after 0; `curve` optional (below) |
| `timeSignature` | `{numerator, denominator}` | required; denominator a power of two ≤ 32 |
| `timeSignatureChanges` | `[{tick, numerator, denominator}]` | optional; ticks rising, after 0, each on a bar line (below) |
| `markers` | `[{tick, name}]` | optional; ticks rising from 0, each once, at most 1 000 (below) |
| `context` | musical context | optional; absent = C, chromatic, 12 equal at 440 Hz, straight |
| `master` | mixer strip | required |
| `masterInserts` | `[insert]` | optional; effects after the master fader |
| `tracks` | `[track]` | required |
| `scenes` | `[{id, name}]` | required; rows of the session grid |
| `media` | `[media file]` | optional; the audio and video files in `Media/` |
| `midiMappings` | `[mapping]` | optional; learned controllers |
| `automation` | `[lane]` | optional; one lane per parameter |
| `modRoutes` | `[route]` | **required** in format 3; sources that move parameters |

**Tempo change:** `{tick, bpm, curve}`. `curve` says how the tempo reaches the change: `step`
(absent = `step`) — the tempo jumps on `tick`; `linear` — it glides from the tempo before the
change, its beats per minute rising or falling evenly per tick, and arrives at `bpm` on `tick`
(an accelerando or ritardando; a linear change right after the song start glides from `tempo`).
Either way the tempo then holds until the next change. Echoel writes `curve` only for `linear`,
so a song without ramps is stored exactly as before; a build that predates ramps opens a song
with them and plays every change as a step. A standard MIDI file has no ramps: an export writes
a ramp as a tempo step on every sixteenth note.

**Time signature change:** `{tick, numerator, denominator}`. `timeSignature` is the first bar's;
from `tick` the song counts bars of the change's signature until the next change. `tick` must fall
on a bar line of the signature before it — a file with a change off a bar line, or with a
signature no song can have, is refused. Echoel writes the key only when a song has a change, so a
song without one is stored exactly as before; a build that predates changes opens a song with
them and counts the first bar's signature throughout (its notes and tempo are unaffected).

**Mixer strip:** `{volumeDB, pan, isMuted, isSoloed}`.

**Musical context:** `{root, scale, tuning, concertPitch, swing}` — `root` a pitch class 0 (C) …
11 (B); `scale` one of `chromatic` `major` `minor` `dorian` `phrygian` `lydian` `mixolydian`
`locrian` `harmonicMinor` `melodicMinor` `majorPentatonic` `minorPentatonic` `blues` `wholeTone`;
`tuning` a tone-system id (`edo12` and others); an unknown scale or tone system is kept by name
and plays as chromatic or 12 equal;
`concertPitch` 400–480 Hz; `swing` 0 (straight) … 1 (triplet feel). It frames what is played and
writes no notes.

**Track:** `id`, `name`, `kind` (`instrument` · `audio` · `returnTrack` · `video`), `colorIndex` (a palette
slot, not a colour), `mixer`, `clips`, `placements` (`{id, clip, start}` on the timeline),
`slots` (`{scene, clip}` in the session grid: a scene of the song and a clip of this track, one
per scene) — all required; optional: `instrument`, `regions`
(audio on the timeline), `inserts`, `sends` (`{target, levelDB}` into a return track), `output`
(first channel of an interface stereo pair, absent = master), `input`, `monitor`
(`auto` · `in` · `off`; another name is kept and behaves as `auto`), `arpeggio` (an instrument
track's arpeggiator, absent = none: `on` (bool, absent = true), `rate` (`quarter` `eighth`
`sixteenth` `thirtySecond` `quarterTriplet` `eighthTriplet` `sixteenthTriplet` `thirtySecondTriplet`,
absent = `sixteenth`), `order` (`up` `down` `upDown` `downUp` `asPlayed` `random`, absent = `up`),
`octaves` 1 … 4, `gate` 0.05 … 1 (the share of a step a note sounds, 1 legato), `latch` (bool),
`seed` 0 … 4294967295 (the random order's sequence); a rate or order a reader does not know is kept
by name and plays as `sixteenth` or `up`. It re-times the notes the track plays and never writes
one), `takeGroups` (take folders, below). What a track holds follows
its kind: an instrument track has MIDI clips and no regions; an audio track has audio clips (in
session slots only) and regions of audio files; a return track has effects only — no clips,
placements, slots or regions; a video track has regions of video files only — no clips,
placements, slots, inserts, sends or output. A video track is never heard: Echoel does not play a
video's own sound, and the song's mix is the sound of a video export. Where two parts of video
tracks overlap, the top track shows, and within a track the part that starts later.

**Instrument:** `device` (`synth` · `drums` · `sampler` · `plugin`; a name a reader does not know
is kept as written and that track stays silent — the song still opens), `preset`, `values` (parameter
key → number, e.g. `synth.cutoff`: the synth's `synth.*`, the drums' `drums.level` (0 … 1, absent plays 1) and, from 2026-11-04, the kit's sound —
`drums.kickGlide` (0 … 4, how far the kick's pitch falls; 1 the kit's own drop), `drums.hatModel` (0 noise,
1 metal), `drums.tomModel` (0 sine, 1 modal) and per piece `drums.<piece>.tune` (semitones, −24 … 24),
`drums.<piece>.decay` (a factor on the piece's length, 0.1 … 4) and `drums.<piece>.level` (0 … 1) for the
pieces `kick` · `snare` · `clap` · `lowTom` · `highTom` · `closedHat` · `openHat` · `crash`; absent plays the kit
as it always sounded — the sampler's
`sampler.root` (0 … 127, the key that plays the sample at its own speed), `sampler.attack`,
`sampler.release` (seconds), `sampler.level` (0 … 1) and `sampler.mode` (0 gate, 1 one-shot); a key
absent plays its default, and every device's values are kept whichever device plays), optional
`sample` (a media id), `plugin` (a plugin component) and `pluginState` (the plugin's own saved
state, base64, at most 8 MiB), and — added inside format 4, 2026-11-04 — `slices` (the break
slicer: the sampler's file cut into pads, 1 … 16 objects `{start, tune?, reverse?}` — `start` a frame
of the file, rising and inside it; `tune` semitones −24 … 24, absent 0; `reverse` absent false. Slice
*n* (from 0) plays on note 36 + *n* from its start to the next one's, the last to the file's end, at the
file's own speed — the root key moves nothing. Absent plays the file across the keys; never written
empty; a list that does not rise, starts past the file or names no file refuses the song) and `wavetable`
(`{media, frames}`: the audio file the synth's Wavetable engine is cut from and the number of
single cycles, 2 … 64, spread across it; absent plays the built-in shapes; a file the song lacks
or a count outside the range refuses the song). How a file becomes cycles (a pitch estimate,
zero crossings, band limits) is the player's and is not stored; the count is, so a position
finds the same cycle in every build. `synth.engine` stores the index of the synth's engine:
0 Classic, 1 Supersaw, 2 FM, 3 Sub, 4 Morph, 5 Mallet, 6 DDSP, 7 Choir, 8 Pluck, 9 Wavetable,
10 Texture — a new engine goes at the end; a build that predates an engine reads its index as out of
range and refuses the song, as for any value outside a parameter's range. The Texture engine (added
inside format 4, 2026-11-04) reads four values of its own, each absent plays its default: `synth.textureRule` the index of an elementary
cellular-automaton rule, by Wolfram's number 0 `90`, 1 `30`, 2 `110`, 3 `150`, 4 `184`, 5 `45`, 6 `73`,
7 `105` (absent 0; a new rule goes at the end); `synth.textureDensity` 0 … 1, how many of the sixteen
harmonics may sound (absent 0.6); `synth.textureRate` 0 … 40 generations per second, 0 holds the row
(absent 8); `synth.textureSeed` 0 … 9999, the row every note starts from — 0 a single cell in the middle
of sixty-four (absent 0). How the row shapes the partials is the player's; rule, seed and rate are
stored, so a song grows the same rows in every build.

**Plugin component:** `{type, subtype, manufacturer, name, manufacturerName}` — an Audio Unit by
the three codes the system finds it by, each the four ASCII characters as one big-endian integer
(`aufx` = 1635083896), plus the names shown while it is not installed. `type` says what it is:
`aumu` an instrument, `aufx` or `aumf` an effect. A song keeps a plugin that is missing here; that
track stays silent and names it.

**Insert:** `{id, plugin, state, isBypassed}` — an effect (a plugin component of an effect type)
on a track or the master, in signal order; `state` optional, as `pluginState`. At most 8 in one place.
For Echoel's own standard effects the state is a property list that may carry, since 2026-11-04,
`echoel.values`: an array of `[identifier, number]` pairs in parameter order (the identifiers of
`EffectKernel.parameters`, never renamed). The master suggestion writes only these; a state with
both these and the unit's own snapshot plays these. A state without them opens as before.

**Media file:** `{id, name, path, frameCount, sampleRate}` plus, for a video only, `kind`:
`"video"` (absent is an audio file; a kind a reader does not know refuses the song) — `path`
inside the package, always under `Media/`, never absolute or with `..`; `frameCount` above 0;
`sampleRate` 1 000 … 768 000. An audio file's `frameCount` counts its frames at `sampleRate`; a
video's counts its length in units of `sampleRate` per second, so a region cuts both alike.

**Audio region:** `{id, media, start, offset, length}` on an audio track's timeline — or, of a
video file, on a video track's — `start` in ticks, `offset` and `length` in the file's units,
inside it. Cutting a region never changes its file. The file plays at its own speed, so
a tempo change moves where a region starts, never how it sounds — unless it follows the tempo
(warp, below).

Optional, added inside format 4 (AUD-2, 2026-11-04); absent, the region plays as every earlier
build played it, and an earlier build that meets them ignores them:

- `fadeIn`, `fadeOut` — frames of the file (integers ≥ 0) the region rises over from its start
  and falls over to its end; absent or 0 is none. Together they fit inside `length`; a file whose
  fades are longer than their region is refused.
- `fadeInCurve`, `fadeOutCurve` — how each fade moves: `linear` (absent), `equalPower`,
  `exponential`, `sCurve`. A curve name a reader does not know is kept, saved back unchanged and
  plays `linear`.
- `gainDB` — the region's own level in decibels, −60 … +24, before the track's fader; absent is
  0 dB. Echoel writes it only when it is not 0.
- `nativeBPM` (20 … 999) and `followsTempo` (true or false, absent false) — warp: with both set,
  the region follows the song's tempo, its pitch unchanged, stretched from `nativeBPM`. Echoel sets
  warp on audio regions only. `nativeBPM` is kept while warp is off, so switching it back on finds it.

- `bake` — the region plays a file Echoel rendered from another file of the song (W3, added
  2026-11-04): `{source, sourceOffset, pitchCorrection?, texture?}`. `source` is the media id of
  the original audio file, `sourceOffset` the frame of it the rendered file's first frame came
  from; the two files run frame for frame at one sample rate, so the region at `offset` plays what
  the original plays at `sourceOffset + offset`, and reverting points the region back there.
  `pitchCorrection` is `{strength, retune}` — 0 … 1 of the correction toward the nearest note of
  the song's key and scale in its tone system, and the seconds it takes to arrive, 0 … 0.5;
  `texture` is a granular texture, `{size, density, scatter, pitch, seed}` — grain length in
  seconds 0.01 … 0.5, density 0 … 1, how far around its moment a grain reads in seconds 0 … 0.5,
  transposition in semitones −24 … 24, and the random sequence 0 … 4294967295. At least one of the
  two; with both, the correction comes first. The settings are kept so the bake can be opened and
  rendered again; the sound is in the rendered file, never recomputed on open. A bake naming a
  file the song lacks, a value outside its range, or an original that cannot hold the region's
  stretch refuses the song. An earlier format-4 build ignores the key and plays the rendered file.

**Take folder:** `{id, takes, comp}` in a track's `takeGroups` — added inside format 4 (Recovery 4,
2026-11-04); Echoel writes the key only when the track has a folder, so a track without one is
stored exactly as before, and an earlier format-4 build opens the song and plays every take as an
ordinary region or clip. Only an audio track (its takes are regions) and an instrument track (its
takes are placements) have folders. `takes` lists 2 … 64 ids of the track's regions or placements,
oldest first — the lanes from top to bottom; a take is in one folder only. `comp` is
`[{start, end, take}]`: stretches of the timeline in ticks, rising, never overlapping,
`start` < `end`, each naming one of the folder's `takes`, at most 4 096. Over a stretch only its
take sounds; where no stretch lies the folder is silent. The takes are never changed by a comp: a
region keeps its file, offset and length, a placement its clip. At a cut between two stretches the
outgoing take falls and the incoming one rises with equal power over 5 ms either side of the cut
(unless both are pieces of one file that a split left side by side); where a stretch meets silence
inside a take it rises or falls over the same span; a take's own edges keep its own fades. On an
instrument track a note sounds when it starts inside a stretch of its take, ended at the
stretch's end, and so do its bends and controllers. How the crossfade is drawn is the player's
and is not stored. A folder naming a take the track lacks, a take in two folders, or stretches
that overlap or name another folder's take refuse the song.

**Clip:** `id`, `name`, `length` (ticks; the loop length), `notes` — required; optional `audio`
(`{media, offset, length}` in frames: an audio loop, on an audio track, with no notes or controls,
in session slots only) and `controls`.

**Note:** `{id, pitch, velocity, start, length}`, start relative to the clip.

**Control change:** `{id, kind, start, value}` where `kind` is `{"pitchBend": {}}` or
`{"controller": {"number": n}}`. A placement that bends the wheel or holds the sustain pedal
returns it to rest where it ends.

**Parameter address:** one string, the owner followed by the parameter key — `project/<key>`,
`master/<key>` or `track/<track id>/<key>`, e.g. `track/7A000000-0000-4000-8000-000000000004/mixer.volume`.
Everything after the owner is the key, slashes included. Keys: `tempo`, `key.root`, `key.scale`,
`tuning.system`, `tuning.concertPitch`, `groove.swing` (the song's); `mixer.volume`, `mixer.pan`
(master and tracks); `mixer.send/<return track id>`; an instrument's own (`synth.cutoff` and the
others in an instrument's `values`: `synth.*`, `drums.*`, `sampler.*` — a mapping or a lane may
name any of them, and a lane plays while its device plays the track); `plugin.instrument/<n>` and `plugin.insert/<insert id>/<n>`,
where `n` is the Audio Unit's own parameter address. A key a reader does not know is kept.

**Marker:** `{tick, name}` — a named position on the timeline, at most one per tick, ticks rising
from 0 to the song's last tick, the name never empty. Added inside format 4 (2026-11-04); Echoel
writes the key only when the song has a marker, so a song without one is stored exactly as before,
and an earlier format-4 build opens a song with markers and shows none. A MIDI export writes each
as a Marker event (FF 06) in the first track; a WAV or stem export as a cue point (`cue ` chunk)
with its name as a label (`LIST`/`adtl`/`labl`), at its frame from the song's start.

**Mapping:** `{control: {channel, number}, target}` — `channel` 0 … 15 (shown as 1 … 16),
`number` 0 … 127, `target` a parameter address. One mapping per control. The controller's travel
spans the parameter's whole range.

**Automation lane:** `{target, points}`, one lane per parameter and none on a song-wide one;
`points` is `[{tick, value, curve}]` with ticks rising from 0, each once, at most 10 000. `value`
is in the parameter's own unit and range (decibels, pan, hertz …; a plugin parameter as 0 … 1 of
its travel). `curve` −1 … 1 bends the line to the next point, 0 straight; optional, absent = 0.
A parameter whose values are choices or whole steps (the synth's `synth.waveform`, the sampler's
`sampler.root` and `sampler.mode`) draws no line: each point holds its value, taken to the nearest
whole step, until the next point, and `curve` has no effect there.

**Modulation route:** `{id, source, target, depth, curve, polarity, enabled}`, every key
required. `source` one of `body.heartRate` `body.hrv` `body.coherence` `body.breath` `lfo.1`
`macro.1` `midi.cc.1`, and — added inside format 4 (2026-11-04), the phone's own motion —
`body.motion.tiltX` `body.motion.tiltY` `body.motion.rotation` `body.motion.energy` (sideways tilt
and forward tilt, 0.5 lying flat; turning, 0.5 at rest; movement without gravity, 0 lying still).
A format-4 build from before that date refuses a song with one of these four, as it refuses any
source it does not know; `target` a parameter address in its text form; `depth` −1 … 1; `curve`
`linear` or `square` (signed: `u·|u|`); `polarity` `unipolar` (the source's 0 … 1 as is) or
`bipolar` (centred, −1 … 1); `enabled` true or false. An unknown source, curve or polarity
refuses the song — a route is never guessed. Each source is normalized to 0 … 1; a parameter's
value is its stored or automated value plus each enabled route's `depth × curve(source)`, in the
order of the route ids, clamped to the parameter's range once, after the last route. A source
that is not measured at the moment adds nothing. A song stores the routes, never a measured
value: what a body did during a take is not in the file.

## Format 3

Format 3 is format 4 without video: no track of kind `video` and no media file with a `kind`. A
format-3 file that carries either is refused, since no format-3 build wrote one. A song saved
again is written as format 4, and builds before format 4 do not open it.

## Format 2

Format 2 is format 3 without `modRoutes`. A reader of format 3 opens it with no routes; a
format-2 file that carries `modRoutes` is refused, since no format-2 build wrote one. A song saved
again is written as format 3, and builds before format 3 (Echoel Studio 10012 and earlier) do not
open it.

## Format 1

Format 1 is format 2 with one difference: a parameter address was an object, the owner in the
form `{"project": {}}`, `{"master": {}}` or `{"track": {"_0": "<track id>"}}` plus the key —
`{"owner": {"master": {}}, "key": "mixer.volume"}`, and it has no `modRoutes`. A reader of
format 3 opens it, and a song saved again is written as format 3.

## What is not in the file

No account, no device identifier, no usage data, no licence information. What you bought lives
with the App Store, not in your songs; a song made with the free app opens anywhere.

The reference reader is `EchoelStudio/Core/Sources/EchoelCore/ProjectCodec.swift`; the files in
`EchoelStudio/Core/Tests/EchoelCoreTests/FormatGoldenTests.swift` are examples that every build
must keep opening.
