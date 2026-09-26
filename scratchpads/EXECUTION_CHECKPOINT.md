# EXECUTION CHECKPOINT — the one compact state file (founder orchestrator addendum 2026-09-26)

Rules: `memory/preferences.md` § "Orchestrator hardening". This file is NOT a roadmap — product order
lives in `docs/dev/ECHOELMUSIC_MASTER_PLAN.md` and the canonical PLAN_* files. Overwrite, don't append.

CURRENT_HEAD: 4735f81e2 (branch claude/echoelmusic-review-optimize-u5jjpd)
CURRENT_MAIN: ab1586c95
ACTIVE_TASK: MA4.4 — SHA-256 content evidence + relink hierarchy A–D (`scratchpads/PLAN_MEDIA_ASSET_2026-09-26.md`)
TASK_STATE: VERIFY — review 1 fixed (292d2d4c8), re-review clean (no HIGH/MED; LOWs 1506446a4); COMPILE CHECK 2964 GREEN on 4735f81e2; CI/CD 6428/6429 (Build for Testing) queued
OWNED_FILES: Core/MediaContentDigest.swift · Core/MediaAssetStore.swift · Core/MediaAssetRecord.swift ·
  Sequencer/MediaRelink.swift · Sequencer/Clip.swift (doc) · Studio/MediaBrowserView.swift ·
  Studio/WorkstationView.swift (post-import task only) · Tests/CISmoke/{TheMediaAssetIsADurableIdentity,
  TheMediaLibraryIsBrowsedAndPlaced,TheWorkstationJourneySurvivesSaveAndOpen}Tests.swift
CURRENT_INVARIANTS: a shared MediaAssetRecord moves only on equal SHA-256 · digest only ADDED, never
  overwritten · persisted form `sha256:<64 hex>`, no CryptoKit type stored · no hashing at launch/scan/
  periodic/browse · relink = one `.clipSource` undo step, no relink under a playing song · physical
  delete blocked · CLAUDE.md < 150,000 B
LAST_GREEN_COMPILE: Compile Check 2964 on 4735f81e2 (covers all MA4.4 code)
LAST_GREEN_TEST: BfT green through ab1586c95 (main)
KNOWN_RED_GATE: CI/CD conclusion red on every push (#396) — read the "Build for Testing" step
FOUNDER_PENDING: device acceptance WA4 / R1 / M1–M10 / MA1–MA4 / B3; MIDI "AUTONOMOUS GATES NOT
  CLOSED" until xcresult; EF3 decision; DC2 paused
NEXT_3_ACTIONS: 1) read the CI/CD "Build for Testing" step of 6429 (4735f81e2) → MA4.4 DONE if green
  (red → failure packet, Builder fix, retry limit 3)  2) run gh-test-verdict on Run Tests (execution of
  claims 9–11 recorded or UNRECORDED)  3) orchestrator picks the next media slice + writes its handoff contract
