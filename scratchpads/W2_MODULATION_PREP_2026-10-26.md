# W2 Modulation Preparation — 26 October 2026

**Next version under full power. Transparent: docs only, no rules changed.**

## End-to-End Link Being Assembled
BodyFrame (W1) → ModRoute in Song → Parameter modulation in render pass.

## What Exists
- Body math in EchoelDSP (HRV, RPPG conditioning, period estimator, RR hygiene).
- Old ModulationEngine / ModulationMatrix in Sources/Echoelmusic (measured sizes in PLAN).
- Parameter registry and eligibility split already law.

## What W2 Needs
1. `ModRoute` stored in the song document (source → parameter, depth, curve).
2. Sources: BodyFrame channels, LFO, Macro, MIDI-CC.
3. Applied in the render pass with a fixed route upper bound (realtime safe).
4. Format version 3 + migration (Golden files, docs/FORMAT.md).
5. All off or neutral until user enables.

## Constraints
- ≤3 files per slice.
- No alloc/lock in render thread.
- Format change is planned, not accidental (songs from 10004–10011 will not open in 1.0).
- Device verify after CI green.

## Suggested First W2 Slice (when ready)
- Define ModRoute type in Core or Engine.
- Persist it in the song (one field).
- One test that a body channel drives a parameter offline.

This prepares the chain without implementing until W1 display is stable.

*Part of continuous handover and vision assembly.*