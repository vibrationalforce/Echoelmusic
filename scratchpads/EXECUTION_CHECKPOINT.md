# EXECUTION CHECKPOINT — the one compact state file (founder orchestrator addendum 2026-09-26)

Rules: `memory/preferences.md` § "Orchestrator hardening". This file is NOT a roadmap — product order
lives in `docs/dev/ECHOELMUSIC_MASTER_PLAN.md` and the canonical PLAN_* files. Overwrite, don't append.

CURRENT_HEAD: f84d4121e on claude/echoelmusic-review-optimize-u5jjpd (PUSHED; the checked-out local branch
  feature/media-seed-2026-09-27 mirrors it). Repair SHAs of the 5.1/5.2 round: 1cf2f92af · 60565f846 · e9999dc58 · adae9432c · f84d4121e. Review base dfe9525e6 · review commit 9d479f922 (22 commits
  media workstation + EchoelAI, transcribed only, NEVER compiled before step 1 below).
CURRENT_MAIN: f84d4121e (read via `git ls-remote origin refs/heads/main` after Compile Check 36413615068 + BfT went green).
CODEX HANDOVER (portable, outside the worktree — scratchpad `codex-handover/`): full bundle in 4 parts
  (sha256 3131556d…) · thin bundle from dfe9525e6 · FABLE_REVIEW_9d479f922.md · IMPORT_ANLEITUNG.md ·
  SHA256SUMS.txt. Verified with `git bundle verify` and a fresh import (both SHAs + diff readable).

REPAIR ROUND on 9d479f922 (founder release 2026-09-27; per package: SHA · findings · SHA-exact CI):
  step 1  226ba8dd5  compile fix                — Compile Check 36353468431 SUCCESS · BfT 36353468460 SUCCESS ·
                                                  Run Tests job 108716569099: 169 pass, 1 fail = PRE-EXISTING #249
  step 2  7331ff86a…2e04fc931  repairs 2a–2e     — Compile Check 36354828282 SUCCESS · BfT 36354828297 SUCCESS ·
          (2a selection pinned before step 1 · 2b   Run Tests job 108720517282: #396 shape, 170 pass / 0 fail
          same-number re-entry counts as a write · IN THE WINDOW (1281 s gap)
          2c "taken back" vs "had already been taken
          back" · 2d look undo on the display grid ·
          2e read publishes only while the card is open)
  step 3a 456b6b213  MED-8 grey-Apply reason in    — Compile Check 36355497435 CANCELLED (covered by 36355582407) ·
          sight + spoken; MED-2 lifecycle doc       BfT 36355497368 SUCCESS · Run Tests job 108722468987: xcodebuild
                                                  ABORT (tool, not a test); 117 pass, 1 fail = PRE-EXISTING #250
  step 3b 860007368  placeTaken = overlap, not     — Compile Check 36355582407 SUCCESS · BfT 36355582304 SUCCESS ·
          start-only (#1440 law); message           Run Tests job 108722669251: #396 shape, 169 pass / 0 fail IN THE
                                                  WINDOW (1244 s gap)
  docs    b29a4f7de  CENSUS_MUSICAL_EVENTS + log   — docs only, no gate (#1176)
  4a      02bcb429f  Codex 1: project binding —    — Compile Check 36356779303 CANCELLED (covered by fcb53dc05's
          `TimelineStore.documentGeneration` in     36356878358, pending) · BfT 36356779325 FAIL: test-only compile
          the plan basis + journal pruned across    error (`store` used before declaration in claim 8) — repaired
          an Open; reproduced via the REAL          in 33a70c329. Sources: TimelineStore · EchoelCommand ·
          Save/Open path (claim 10)                 EchoelCommandExecutor (3 files)
  4b      fcb53dc05  Codex 4 (selection gap between — test only; BfT red until 33a70c329 (carries the 4a test error)
          steps after preflight): claim 11
  4d      fc719443e  Codex 3: number / display grid — test only (new file TheLevelRequestSeparatesNumberGridAndWrite
          / write responsibility, 3 claims           Tests); BfT red until 33a70c329
  4e      9cb151b20  Codex 4: result invalidation  — test only (TheMediaLookHasOneWriterTests claim 5); BfT red until
          = same main-actor turn as the check       33a70c329
  fix     33a70c329  claim 8 anchor order          — Compile Check 36357182443 SUCCESS (first Release/device compile of
                                                  the 4a Sources) · BfT 36357182490 SUCCESS (the bundle with 4a–4e builds)
                                                  · Run Tests job 108728801787: #396 shape, 169 pass / 0 fail IN THE
                                                  WINDOW (1701 s gap); none of this round's suites in the window →
                                                  execution unrecorded (#445/#807), compile proven
  5.1     1cf2f92af  generation re-checked after  — Sources: EchoelCommandExecutor (`betweenSteps` seam, default Task.yield;
          EVERY suspension between steps;          `.projectChanged` on the step after an Open, rest `.notRun`; group stamped
          claim 11 rewritten onto the seam,          with the PLAN generation). Compile Check 36406926161 SUCCESS (on 60565f846,
          claim 12 = real Save/Open in the gap       covers) · Compile Check 36407799896 SUCCESS (e9999dc58)
  5.2     60565f846  own later level writes move   — Sources: EchoelCommandExecutor (`noteOwnLevelWrite`: change + Undo restore
          own journal marks; claim 4 (a) one        advance the `write` mark of own `.level` entries; check unchanged, hand
          request two changes → one Undo, (b) two    re-entry still blocks). BfT 36406925949 FAIL: test-only compile error
          requests → two Undos, (c) hand re-entry    (await inside XCTAssertEqual's autoclosure, ×10) → repaired in e9999dc58
          still blocks
  fix     e9999dc58  claim 4 awaited results bound — Compile Check 36407799896 SUCCESS · BfT run 36407799979 job 108880923546
          to locals                                  step 9 SUCCESS · Run Tests: see RUN_TESTS_e9999dc58 below
  docs    d4a3ee216  Photism → V1–V4 plan + 2 decisions — docs only, no gate (#1176)
RUN_TESTS_e9999dc58: job 108880923546 step 11 FAILURE = #396 shape (TEST EXECUTE FAILED, exit 65, no launch-failure line,
  0 crash markers) · WINDOW = tail -200 · 1431 s gap 10:13:56→10:37:47 · 169 tests observed passing, 0 failures, 0 skips IN THE
  WINDOW · NONE of this round's suites (TheAgentActsThroughTheButtonsPathsTests · TheLevelRequestSeparatesNumberGridAndWriteTests ·
  TheMediaLookHasOneWriterTests · TheAgentProposesOnlyRegisteredCommandsTests) appears in the window → their EXECUTION IS
  UNRECORDED (#445/#807); they COMPILE (BfT green). Neither pre-existing red (#249/#250) is in the window either — absence proves nothing.
  ⚠️ The complete result bundle (`test-results-ios-iPhone 17`, xcresult) exists as an artifact but its download host
  (productionresultssa*.blob.core.windows.net) is denied by this environment's network policy → only the 200-line window is
  readable here; a suite absent from the window = execution unrecorded (#445/#807), never "passed".
  Reach: `EchoelCommandExecutor(` has 0 production callers → 5.1/5.2 were LATENT API defects, not reachable user errors.
  5.1b    adae9432c  no between-step suspension — Sources: EchoelCommandExecutor (`betweenSteps()` + generation check gated on
          after the request has stopped        `!stopped`). Found by the FULL xcresult of e9999dc58, read in ANOTHER SESSION
                                               (artifact 10963874977): claim 12 red, hook ran twice ("2 statt 1"), generation
                                               moved by two ("3 statt 2"). Gates: see GATES_f84d4121e
  tests   f84d4121e  claim 10 fixture (toggleTrack — test only. Claim 10 block B: `selectRegion` had already selected Keys, the
          after selectRegion CLEARED the         toggle cleared it → "No track is selected" (xcresult). Claim 5 last block: since
          selection) · claim 5 contract (2a:     2a (7331ff86a) a removed selected part yields NO plan target → refusal
          refusal, not step-level targetGone)    `.nothingSelected("part")` + `.notRun`; the block still expected the pre-2a
                                               step-level `.targetGone("part")` — never executed until the xcresult read it.
XCRESULT_e9999dc58 (EXTERNAL — read in another session from artifact 10963874977 of job 108880923546; NOT reproducible here,
  the blob host is denied by this environment's network policy): 4,385 test cases · 4,346 Success · 39 Failure; the per-case
  count agrees with the ActionsInvocationRecord aggregates. Of ours: testOwnLaterWritesDoNotBlockOwnEarlierUndoEntries (5.2)
  SUCCESS · testAProjectOpenedAgainBetweenTwoStepsEndsTheRequestThere FAILURE (→ adae9432c) ·
  testAReopenedIdenticalProjectIsNotThePlannedOne FAILURE (→ f84d4121e, fixture) · testStaleSelectionChangedSongAndRepeatsAreSafe
  FAILURE (→ f84d4121e, contract). The other 35 failures are NOT named in this session's evidence: #249 and #250 are known
  pre-existing reds; the remaining ones need the per-case list from the xcresult — they are NOT attributed to #396 (that
  label covers the clone crash / exit 65 shape of the step, never a named failing test).
  ⚠️ "5.1 behoben" is therefore TRUE only as of adae9432c AND only once a run shows claim 12 passing; on e9999dc58 it was red.
  "5.2 behoben" is executed evidence (SUCCESS in the xcresult).
GATES_f84d4121e: Compile Check 36413615068 SUCCESS · Build for Testing run 36413614937, job 108899686909 step 9 SUCCESS ·
  Run Tests step 11 = xcodebuild ABORT (exit 134, Abort trap — the TOOL died, not #396's clone shape and not a test result);
  window tail -200 with a 1387 s gap, 118 tests observed passing, 0 failures, 0 skips IN THE WINDOW; none of the four suites of
  this round in the window → claims 5/10/12 EXECUTION UNRECORDED here. Artifact `test-results-ios-iPhone 17` id 10968101637
  (3.68 MB) was uploaded — readable only from a session whose network policy allows the blob host; the other session's
  per-case reading of THAT artifact is what closes claims 5/10/12. main = f84d4121e (auto-merge; ls-remote).
  ⚠️ So on f84d4121e: 5.1 = COMPILES + transcribed (old form reproduces the xcresult numbers, new form passes); EXECUTED evidence
  still owed. 5.2 = executed SUCCESS (xcresult of e9999dc58; unchanged since).
  Not repaired, reported (user-impact order): MED-9 video import copies the full file before the duration check,
  no cancel button (temp copy removed, newer pick cancels) · MED-11 meter warning colour-only · LOW rest ·
  Codex 2 (look half): a same-value re-entry of a LOOK parameter is indistinguishable and is taken back
  (`MediaSeedApplication.undo`, display grid) — the level path keeps it (2b); a look write journal would route
  39 `@AppStorage(StudioDefaultKeys.visual…)` bindings in 4 files + 1 `set(forKey:)` through an owner = the
  state architecture Codex excluded → recorded, not built · the agent's "0.0 dB → 0.0 dB" answer for a
  sub-grid level change (pinned as is in 4d claim 2; wording decision open) · needle-reachability: 3 findings,
  all interpolation false alarms, none touched by this round.
  Agent findings are LATENT INFRASTRUCTURE: `EchoelCommandExecutor(` has 0 production callers.

CURRENT_INVARIANTS: no new modal (11 on the chain, ceiling 14) · no hot read in host bodies · one media-look
  writer (`MediaLookUndo`) · executor writes only through the button writers (claim 8 allow-list: document ·
  documentGeneration · laneLevelWrites) · CLAUDE.md < 150,000 B · .deploy/release NOT touched · no TestFlight
LAST_GREEN_COMPILE: Compile Check 36413615068 on f84d4121e
LAST_GREEN_TEST: BfT run 36413614937 (job 108899686909 step 9) on f84d4121e
KNOWN_RED_GATE: CI/CD conclusion red on every push (#396) — read the "Build for Testing" step · two PRE-EXISTING
  red guards in the blocking bundle, both in main before this round: #249 TheDetectedTempoIsHonestTests claim 12
  (since 6f88bb3d7) · #250 AutoModeStartsOffAndOwnsNoTempoTests claim 9 (`autoAttuned: autoMode` left
  EchoelStudioView with #1069) — founder decides whether this round fixes them
CANDIDATE_f84d4121e_TRIAGE (2026-09-28, founder order "alle 21 bekannten fehlgeschlagenen Tests sowie den Xcode-Abbruch
  einordnen"): the per-case list of the 21 is NOT in this repo and NOT readable from this session — artifact 10968101637
  (job 108899686909) → download URL issued, CONNECT to productionresultssa13.blob.core.windows.net denied 403 again
  (15:3x UTC). Rules that decide it, all pre-existing: (1) auto-merge/TestFlight bar = Compile Check conclusion + BfT
  STEP green — both green on f84d4121e · (2) decisions.csv 2026-09-26: nothing is declared CLOSED on green BfT while Run
  Tests is red; the 200-line window is not evidence, only an xcresult or a targeted run is · (3) #396: the step's
  conclusion is red by design · (4) decisions.csv 2026-09-09 (#1174): a TRAP looks like a tool death — discriminator is
  the step history · (5) deploy = founder order + .deploy/release (founder-gated; in auto mode the hook now DENIES).
  Classes each of the 21 must land in: A pre-existing in main before this round (#249, #250 known) → known red, founder
  decides · B caused by this round's commits (claims 5/10/12 of the agent suites) → blocks "closed", fix first ·
  C test-only fixture/contract error → fix the test · D not yet classifiable. Xcode abort (Run Tests step 11, exit 134,
  Abort trap, 11:13:45→11:36:53): the TOOL died → execution of every suite after the abort point is UNRECORDED, not
  failed and not passed; by (4) a test trap is not excluded until the xcresult names the last test started.
  NEXT: the per-case list — founder pastes it, or allows *.blob.core.windows.net in the environment's network policy.
FOUNDER_PENDING: device checks for the whole media/agent stack (nothing here is device-verified) · #249/#250 ·
  MED-9 cancel button · "0.0 dB → 0.0 dB" wording · TestFlight (NOT triggered, per order)
VISUAL_PLAN: Photism principles → V1–V4 in `scratchpads/PLAN_MEDIA_SEED_2026-09-27.md` §7 (planned 2026-09-28, NOT released;
  V1(c) = AudioFeatureChannel producer as a MASTER-output tap, audio-thread review mandatory; MPE two-note acceptance blocked).
GATE_PROTECTION: 2026-09-28 — the four founder-gated paths ASK before any Claude write (`permissions.ask` + Bash hook
  `.claude/hooks/protect-founder-gated.py`); release = answer the prompt, one action each — measured in nested `claude -p`
  only. Fix-up (same day): same-command staging + pathspec commit now caught; shutil.copy FROM a protected file no longer
  asks. Phone probe: "ask" emitted, command ran, resolving instance UNKNOWN. → Variant A (founder order): hook DENIES in
  `permission_mode` auto, asks otherwise; live proof in this session (throwaway repo write refused, file unchanged).
  copy protected→protected now caught; selftest 56/56. Release = founder edits himself; phone release proven in no mode;
  Edit/Write in auto relies on built-in ask rules (unmeasured). `.claude/hooks/README.md` „Deny-Beleg".
NEXT_3_ACTIONS: 1) founder: decide V1 release (audio tap first) and #249/#250, MED-9, the "0.0 dB → 0.0 dB" wording
  2) founder: allow the artifact host (productionresultssa*.blob.core.windows.net) in the environment's network policy if the
  xcresult should be readable from a session — until then execution evidence stays the 200-line window  3) no new features; no TestFlight
