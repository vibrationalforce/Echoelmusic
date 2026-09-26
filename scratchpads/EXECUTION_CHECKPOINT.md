# EXECUTION CHECKPOINT — the one compact state file (founder orchestrator addendum 2026-09-26)

Rules: `memory/preferences.md` § "Orchestrator hardening". This file is NOT a roadmap — product order
lives in `docs/dev/ECHOELMUSIC_MASTER_PLAN.md` and the canonical PLAN_* files. Overwrite, don't append.

CURRENT_HEAD: 4735f81e2 (branch claude/echoelmusic-review-optimize-u5jjpd)
CURRENT_MAIN: 4735f81e2
ACTIVE_TASK: MA4.4c — a record minted on landing gets its digest (contract in PLAN_MEDIA_ASSET §MA4.4c)
TASK_STATE: ACTIVE (build). MA4.4 = DONE — AUTONOMOUS GATES CLOSED / FOUNDER DEVICE ACCEPTANCE PENDING (BfT 6429 green, journey test observed passing, main = 4735f81e2)
OWNED_FILES: Sequencer/AudioImport.swift · Sequencer/MediaPlacement.swift · Studio/WorkstationView.swift ·
  Tests/CISmoke/{TheMediaAssetIsADurableIdentity,TheImportReusesAnIdenticalLibraryFile}Tests.swift
CURRENT_INVARIANTS: a shared MediaAssetRecord moves only on equal SHA-256 · digest only ADDED, never
  overwritten · persisted form `sha256:<64 hex>`, no CryptoKit type stored · no hashing at launch/scan/
  periodic/browse · relink = one `.clipSource` undo step, no relink under a playing song · physical
  delete blocked · CLAUDE.md < 150,000 B
LAST_GREEN_COMPILE: Compile Check 2964 on 4735f81e2 (covers all MA4.4 code)
LAST_GREEN_TEST: BfT 6429 green on 4735f81e2 (167 pass / 0 fail in window)
KNOWN_RED_GATE: CI/CD conclusion red on every push (#396) — read the "Build for Testing" step
FOUNDER_PENDING: device acceptance WA4 / R1 / M1–M10 / MA1–MA4 / B3; MIDI "AUTONOMOUS GATES NOT
  CLOSED" until xcresult; EF3 decision; DC2 paused
NEXT_3_ACTIONS: 1) build MA4.4c per its contract, checkers, one push  2) independent read-only review →
  fix HIGH/MED  3) Compile Check + BfT → DONE; then MA4.4d (browser Place door hashes a minted record)
