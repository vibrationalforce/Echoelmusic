---
name: offline-export-freeze
description: Deterministic offline renders via explicit freeze or recorded control tracks. Live camera/BLE must not affect a second export. Use before any offline render or export path that consumes body or visual sources.
---

# Offline Export Freeze

## Rules
- Two offline renders of the same document, start state and frozen/recorded source state produce identical reference evolution.
- Live inputs that change between the two renders must not affect the result.
- Musician sees what will be used before export (freeze preview or recorded tracks).
- Biometric raw data is not casually included in project packages.
- Explicit choice: recorded control tracks, frozen start state, or live sources disabled.
