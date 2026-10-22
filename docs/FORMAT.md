# The Echoel song format (format 2)

A song is a folder ending in `.echoel` — a package of the type `com.echoelmusic.song`, which the
Files app shows as one file and opens in Echoel:

```
My Song.echoel/
  project.json        the song, UTF-8 JSON
  Media/              the audio files the song uses, copied in on import
```

A song shared from the app ("Share Song") is the same package, written fresh: `project.json` and
the files in `Media/` that the song names, nothing else. A file the song names but the package
lacks is left out, and the song opens without it, as it would where it came from.

`project.json` is written pretty-printed with sorted keys, so the same song always produces the
same bytes and a diff shows only real changes. Nothing in it is encrypted, compressed or signed.
Every audio file is a plain file you can take out of `Media/`.

## Versioning

- `formatVersion` (integer) is required. This document describes **2**. A reader of format 2
  opens every format-1 file too; the one difference is at the end ("Format 1").
- A file with a **newer** number is refused rather than opened with parts missing; a number below
  1 is refused as damaged.
- An older file is read into today's shape, so saving it writes today's number.
- Inside one format, fields are only ever **added**. A reader treats a missing optional field as
  its default; the fields marked *optional* below were added after the first format-1 builds and
  older files lack them.
- A key it does not know is ignored, except inside an instrument's `values`, where it is kept
  for the build that knows it.
- **A name it does not know** follows one rule. Where the field only chooses how the song plays —
  an instrument's `device`, the `tuning`, the `scale`, a track's `monitor` — the song opens, the
  name is kept and saved back unchanged, and it plays as the field's fallback: silent, twelve
  equal steps, chromatic, `auto`. A track's `kind` decides what the track holds and has no
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
| ids | UUID strings — unique in the song, except a note's (unique in its clip) and a placement's (unique on its track) |
| names | the song's, a track's, a clip's, a scene's, a media file's: never empty or only spaces; the editor keeps them within 128 characters, a reader takes up to 256 |

## `project.json`

| key | type | |
|---|---|---|
| `formatVersion` | integer | required |
| `name` | string | required |
| `tempo` | number | required; the tempo from tick 0 |
| `tempoChanges` | `[{tick, bpm}]` | optional; ticks rising, after 0 |
| `timeSignature` | `{numerator, denominator}` | required; denominator a power of two ≤ 32 |
| `context` | musical context | optional; absent = C, chromatic, 12 equal at 440 Hz, straight |
| `master` | mixer strip | required |
| `masterInserts` | `[insert]` | optional; effects after the master fader |
| `tracks` | `[track]` | required |
| `scenes` | `[{id, name}]` | required; rows of the session grid |
| `media` | `[media file]` | optional; the files in `Media/` |
| `midiMappings` | `[mapping]` | optional; learned controllers |
| `automation` | `[lane]` | optional; one lane per parameter |

**Mixer strip:** `{volumeDB, pan, isMuted, isSoloed}`.

**Musical context:** `{root, scale, tuning, concertPitch, swing}` — `root` a pitch class 0 (C) …
11 (B); `scale` one of `chromatic` `major` `minor` `dorian` `phrygian` `lydian` `mixolydian`
`locrian` `harmonicMinor` `melodicMinor` `majorPentatonic` `minorPentatonic` `blues` `wholeTone`;
`tuning` a tone-system id (`edo12` and others); an unknown scale or tone system is kept by name
and plays as chromatic or 12 equal;
`concertPitch` 400–480 Hz; `swing` 0 (straight) … 1 (triplet feel). It frames what is played and
writes no notes.

**Track:** `id`, `name`, `kind` (`instrument` · `audio` · `returnTrack`), `colorIndex` (a palette
slot, not a colour), `mixer`, `clips`, `placements` (`{id, clip, start}` on the timeline),
`slots` (`{scene, clip}` in the session grid: a scene of the song and a clip of this track, one
per scene) — all required; optional: `instrument`, `regions`
(audio on the timeline), `inserts`, `sends` (`{target, levelDB}` into a return track), `output`
(first channel of an interface stereo pair, absent = master), `input`, `monitor`
(`auto` · `in` · `off`; another name is kept and behaves as `auto`). What a track holds follows
its kind: an instrument track has MIDI clips and no regions; an audio track has audio clips (in
session slots only) and regions; a return track has effects only — no clips, placements, slots
or regions.

**Instrument:** `device` (`synth` · `drums` · `sampler` · `plugin`; a name a reader does not know
is kept as written and that track stays silent — the song still opens), `preset`, `values` (parameter
key → number, e.g. `synth.cutoff`: the synth's `synth.*`, the drums' `drums.level` (0 … 1, absent plays 1), the sampler's
`sampler.root` (0 … 127, the key that plays the sample at its own speed), `sampler.attack`,
`sampler.release` (seconds), `sampler.level` (0 … 1) and `sampler.mode` (0 gate, 1 one-shot); a key
absent plays its default, and every device's values are kept whichever device plays), optional
`sample` (a media id), `plugin` (a plugin component) and `pluginState` (the plugin's own saved
state, base64, at most 8 MiB).

**Plugin component:** `{type, subtype, manufacturer, name, manufacturerName}` — an Audio Unit by
the three codes the system finds it by, each the four ASCII characters as one big-endian integer
(`aufx` = 1635083896), plus the names shown while it is not installed. `type` says what it is:
`aumu` an instrument, `aufx` or `aumf` an effect. A song keeps a plugin that is missing here; that
track stays silent and names it.

**Insert:** `{id, plugin, state, isBypassed}` — an effect (a plugin component of an effect type)
on a track or the master, in signal order; `state` optional, as `pluginState`. At most 8 in one place.

**Media file:** `{id, name, path, frameCount, sampleRate}` — `path` inside the package, always
under `Media/`, never absolute or with `..`; `frameCount` above 0; `sampleRate` 1 000 … 768 000.

**Audio region:** `{id, media, start, offset, length}` on an audio track's timeline — `start` in
ticks, `offset` and `length` in frames of the file, inside it. The file plays at its own speed, so
a tempo change moves where a region starts, never how it sounds.

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

## Format 1

Format 1 is format 2 with one difference: a parameter address was an object, the owner in the
form `{"project": {}}`, `{"master": {}}` or `{"track": {"_0": "<track id>"}}` plus the key —
`{"owner": {"master": {}}, "key": "mixer.volume"}`. A reader of format 2 opens it, and a song
saved again is written as format 2.

## What is not in the file

No account, no device identifier, no usage data, no licence information. What you bought lives
with the App Store, not in your songs; a song made with the free app opens anywhere.

The reference reader is `EchoelStudio/Core/Sources/EchoelCore/ProjectCodec.swift`; the files in
`EchoelStudio/Core/Tests/EchoelCoreTests/FormatGoldenTests.swift` are examples that every build
must keep opening.
