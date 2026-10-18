# The Echoel song format (format 1)

A song is a folder ending in `.echoel` (a package; the Files app shows it as one file):

```
My Song.echoel/
  project.json        the song, UTF-8 JSON
  Media/              the audio files the song uses, copied in on import
```

`project.json` is written pretty-printed with sorted keys, so the same song always produces the
same bytes and a diff shows only real changes. Nothing in it is encrypted, compressed or signed.
Every audio file is a plain file you can take out of `Media/`.

## Versioning

- `formatVersion` (integer) is required. This document describes **1**.
- A file with a **newer** number is refused rather than opened with parts missing.
- Inside one format, fields are only ever **added**. A reader of format 1 treats a missing
  optional field as its default; the fields marked *optional* below were added after the first
  format-1 builds and older files lack them.
- A key it does not know is ignored, except inside an instrument's `values`, where it is kept
  for the build that knows it.
- On open, the song is checked against the same rules the editor enforces (ranges, unique ids,
  references that resolve). A file that breaks one is refused, not repaired silently.

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
| ids | UUID strings |

## `project.json`

| key | type | |
|---|---|---|
| `formatVersion` | integer | required |
| `name` | string | required |
| `tempo` | number | required; the tempo from tick 0 |
| `tempoChanges` | `[{tick, bpm}]` | optional; ticks rising, after 0 |
| `timeSignature` | `{numerator, denominator}` | required; denominator a power of two ≤ 32 |
| `master` | mixer strip | required |
| `masterInserts` | `[insert]` | optional; effects after the master fader |
| `tracks` | `[track]` | required |
| `scenes` | `[{id, name}]` | required; rows of the session grid |
| `media` | `[media file]` | optional; the files in `Media/` |
| `midiMappings` | `[mapping]` | optional; learned controllers |
| `automation` | `[lane]` | optional; one lane per parameter |

**Mixer strip:** `{volumeDB, pan, isMuted, isSoloed}`.

**Track:** `id`, `name`, `kind` (`instrument` · `audio` · `returnTrack`), `colorIndex` (a palette
slot, not a colour), `mixer`, `clips`, `placements` (`{id, clip, start}` on the timeline),
`slots` (`{scene, clip}` in the session grid) — all required; optional: `instrument`, `regions`
(audio on the timeline), `inserts`, `sends` (`{target, levelDB}` into a return track), `output`
(first channel of an interface stereo pair, absent = master), `input`, `monitor`
(`auto` · `in` · `off`).

**Instrument:** `device` (`synth` · `drums` · `sampler` · `plugin`), `preset`, `values` (parameter
key → number, e.g. `synth.cutoff`), optional `sample` (a media id), `plugin` (an Audio Unit's
type, subtype and manufacturer codes plus names) and `pluginState` (the plugin's own saved state,
base64).

**Clip:** `id`, `name`, `length` (ticks; the loop length), `notes` — required; optional `audio`
(`{media, offset, length}` for an audio loop) and `controls`.

**Note:** `{id, pitch, velocity, start, length}`, start relative to the clip.

**Control change:** `{id, kind, start, value}` where `kind` is `{"pitchBend": {}}` or
`{"controller": {"number": n}}`. A placement that bends the wheel or holds the sustain pedal
returns it to rest where it ends.

## What is not in the file

No account, no device identifier, no usage data, no licence information. What you bought lives
with the App Store, not in your songs; a song made with the free app opens anywhere.

The reference reader is `EchoelStudio/Core/Sources/EchoelCore/ProjectCodec.swift`; the files in
`EchoelStudio/Core/Tests/EchoelCoreTests/FormatGoldenTests.swift` are examples that every build
must keep opening.
