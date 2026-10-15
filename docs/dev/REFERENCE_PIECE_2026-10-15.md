# Reference piece — what works today and what is in the way (2026-10-15)

Founder point 1: one reference piece built entirely in the app — 150 BPM, half-time drums, an
ambient pad, a bass line, a short video snippet, then exported. Each step below was measured
against `Sources/Echoelmusic` (comment-only hits removed). **Nothing here is device-verified.**

| # | Step | Door | Today | Blocker |
|---|---|---|---|---|
| 1 | 150 BPM, locked | Tempo field + lock (`Studio/BodyTempoField.swift`), mounted in the instrument | **yes** | Lock first, then type 150; the tempo glides over ~2 s. |
| 2 | Half-time drums | Add → "Import Audio", then the part's "File tempo" field with ÷2 / ×2, Warp, Stretch (Clean · Tape · Beats) | **partial** | No drum source in the app: the composer plays `BioComposer.silentBeat()` (`Studio/EchoelStudioView.swift`), so `halfTimeBeat` is never heard. `RollNoteOps.halfTime` and `SampleSlicer` have no callers. A drum loop must come from a file; "half-time" is only the ×2 trick (marks a 150 loop as 300 so it plays at half speed). |
| 3 | Ambient pad | Add MIDI Track → Device page → Sound "Warm Pad" + "Compose here" | **yes** | There is no pad or chord ROLE: the track plays one generic composed line, with a pad sound. |
| 4 | Bass | Same doors with EchoelBass or "Deep Sub" | **partial** | No bass role in the per-track composer; one EchoelBass voice at a time. |
| 5 | Video snippet | Add → Add Video Track / Import Video / Record Video | **partial** | The video track plays muted; a clip's sound goes to an audio track only through "Use Its Sound". Picture-to-song sync is a NEEDS-FOUNDER-VERIFY. |
| 6 | Export | Project page: Song MIDI share, Piece "WAV" (`LoopExporter.exportPiece`, real time) | **partial** | WAV only, no AAC, no stems. No export carries the video (`SingleExport` writes audio only). |

## The order that closes the most

1. **Drums from the app itself** — the bigger half of the reference piece. Cheapest honest door:
   a drum ROLE for "Compose here" that writes notes for the Sampler instrument, using the
   existing `halfTimeBeat` pattern. Needs a founder ear decision on the kit source (bundled
   one-shots vs. user samples).
2. **Pad and bass roles** for "Compose here" (chord tones for the pad, root line for the bass) —
   the composer already knows key and scale.
3. **Video out** — a combined audio + picture export. New export path; Council first (it is
   the largest of the three and touches `AVAssetWriter` for video, which the app does not use
   today).
4. **Stems** — already queued as S-A3c-2b.

Points 2–6 of the founder's list (video as instrument, cross-media macros Dichte · Weite ·
Bewegung · Zerfall, Freeze, overload policy, EchoelAI A/B) build on this piece; none of them
is started.
