---
name: g-c-sound-recovery
description: DDSP, granular, pitch correction and MPE Out recovery contracts for EchoelStudio W5/W8. Use when porting historical DSP cores into current instrument or effect kernels.
---

# G-C Sound Recovery

## Key Rules
- Port only proven cores; discard stale owners. No new extension, keep echl subtype.
- Granular: fixed grain/voice pool, reproducible seed, documented voice steal and normalization. No unbounded growth in render.
- Pitch: defined musical frame, non-voiced handling, latency and formant behaviour. "Corrected" needs reference deviation + listening test.
- MPE Out: zones, pitch-bend range, voice identity, note-on/off order, channel reuse, all-notes-off. Does not prove MPE In.
- Live and offline share musical semantics. Lookahead, tail, bypass and latency compensation explicit.
- Reference script covers at least one DSP contract and the MPE state machine against independent fixtures.

Full contract, fixtures and reference.py available in the skill references or handover scratchpad.
