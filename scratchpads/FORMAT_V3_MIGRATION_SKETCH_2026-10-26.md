# Format Version 3 Migration Sketch — W2 ModRoute
2026-10-26 — autonomous continuation.

## Why
W2 stores ModRoute inside the song. This requires Format Version 3.

## Sketch
- Bump format version in the song document codec.
- On open of v2 or earlier: migrate by adding an empty ModRoute array (or default routes).
- Golden files: update or add one v3 example that contains a body-sourced route.
- docs/FORMAT.md: document the new field and migration rule.
- Songs created in 1.0 will not open in builds 10004–10011 (planned, not accidental).

## Constraints
- Migration must be lossless for existing data.
- No change to audio-thread path.
- One small slice when W2 starts: version bump + empty array migration + one test.

This sketch is ready for the W2 implementation phase.

*No rules changed. Loop continues.*