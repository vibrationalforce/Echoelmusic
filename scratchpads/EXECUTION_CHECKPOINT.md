# EXECUTION CHECKPOINT — the one compact state file (founder orchestrator addendum 2026-09-26)

Rules: `memory/preferences.md` § "Orchestrator hardening". This file is NOT a roadmap — product order
lives in `docs/dev/ECHOELMUSIC_MASTER_PLAN.md` and the canonical PLAN_* files. Overwrite, don't append.

CURRENT_HEAD: 7e6aea965 on claude/echoelmusic-review-optimize-u5jjpd (PUSHED code/gate SHA; subsequent docs commits
  may advance the branch tip). Codex applied the prepared, founder-authorized case-20 manifest patch through the connected
  GitHub tools; Claude's local checkout was not inspected and must incorporate the remote commit before its next push.
  Repair SHAs of the 5.1/5.2 round: 1cf2f92af · 60565f846 · e9999dc58 · adae9432c · f84d4121e. Review base dfe9525e6 · review commit 9d479f922 (22 commits
  media workstation + EchoelAI, transcribed only, NEVER compiled before step 1 below).
CURRENT_MAIN: 30503f2b0 (read via the GitHub branch API after 7e6aea965 was pushed; not a gate result for 7e6aea965).
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
XCRESULT_f84d4121e (EXTERNAL — Codex evaluation 2026-09-28, relayed as text by the founder; artifact 10968101637 of
  job 108899686909, run 36413614937 attempt 1, ZIP 3,680,211 B, SHA-256 0a44e91d…c7613593 = GitHub artifact digest; NOT
  reproducible here, blob host denied): the xcresult is INCOMPLETE (no final ActionsInvocationRecord, no Info.plist). From
  the data objects: 2,293 unique ActionTestSummary records = 2,272 Success · 21 Failure · 0 Skipped — NOT a complete run and
  no statement about the planned total. EXECUTED GREEN on f84d4121e: all 12 tests of TheAgentActsThroughTheButtonsPathsTests,
  incl. claim 5 testStaleSelectionChangedSongAndRepeatsAreSafe · claim 10 testAReopenedIdenticalProjectIsNotThePlannedOne ·
  claim 12 testAProjectOpenedAgainBetweenTwoStepsEndsTheRequestThere (all three Failure on e9999dc58); suite log
  Session-EchoelmusicTests-2026-09-28_111352-Nu761o.log: 12 tests, 0 failures at 11:22:47 UTC. testOwnLaterWritesDoNotBlock
  OwnEarlierUndoEntries (5.2): Success on e9999dc58, NO completed result on f84d4121e → no new pass claimed.
  History: all 21 Failure IDs were already Failure in artifact 10963874977 (e9999dc58); of e9999dc58's 39 Failures: 21 again
  Failure, 3 Success (claims 5/10/12), 15 without a completed result (= unrecorded, not passed, not "never started").
  "Red on e9999dc58" ≠ "red before the whole repair round". Abort: 11:36:25 XCTHTestOperationCoordinatorErrorDomain Code=14
  "The test runner timed out while preparing to run tests" (Session-…_111709-WENENc.log + scheduling.log), 11:36:52 Abort
  trap: 6 / exit 134, NSInternalInconsistencyException "Unexpected operation <IDERunOperation …>, current operation is
  (null)" → runner/Xcode abort proven; no test identified as trigger; #396 attribution not proven by this alone. The 21
  recorded Failures stand; the abort does not cancel them. Hook re-check by Codex: selftest 56/56, copy case → deny (auto).
TRIAGE_21_f84d4121e (2026-09-28, read against test + product code AT f84d4121e; failure KIND and HISTORY kept apart.
  "cause commit" = the commit that made the assertion red; every one listed is an ancestor of 9d479f922 (the start of the
  repair round) — that is a git fact per commit, NOT an inference from "red on e9999dc58". Kinds: P product defect ·
  T test/fixture defect · A stale anchor/needle · N nondeterministic expectation · E environment · U unexplained.)
   1 A  TheHomePageLeadsWithTheMechanismTests.testTheOverviewSellsThePlayablePicture — docs/overview.html:167 heading went
        h4→h3 (77598dbdd, #1399 a11y), content intact · fix: needle <h3>EchoelVis</h3> · unc.: none
   2 A  TheCaptureTapDoesNotTouchTheDiskTests.testTheOverrunTestComparesMonotonicCounters — the "not held" note was
        rewritten because #1429 (40bed1424) ADDED the fence (enum RetroRingCursor, RetroCapture.swift:44; pinned by
        TheRingCursorPublishesWithABarrierTests) · fix: needle on the new text · unc.: fence not device-verified
   3 A  TheGenreListsMatchTheirOwnCountTests.testTheStatedNumberIsTheRosterCount — `spelled` lacks "Forty-one"/
        "Einundvierzig"; all four surfaces and the roster say 41 (275fba7b8, #1382) · fix: add both spellings
   4 T  TheLightingLookIsACanonicalParameterTests.testEligibilityGovernsRegardlessOfBindingOrder — expected list built in
        automatableBases order, product returns registry order (ParameterApplyRouter.swift:222-223) (4879829ec) · fix: build
        expectation from DDSPParameterCatalog order
   5 T  TheAutomatableSetHasOneWriterTests.testBrightnessIsAutomatableOnlyWhileItsSentinelIsOutOfRange — fixture registry
        never filled (EchoelParameterRegistry init empty, :41) (15990f2a1/a055043be) · unc.: downstream needles never ran
   6 A  TheMIDI2SourceIsSwitchableTests.testTheRoutingModelCallsMIDI2Live — "no MIDI-CI" sits in a trailing comment
        (SignalRouting.swift:68), test reads codeOnly (8116b3663; its body claimed "both pass" — wrong) · fix: raw text
   7 A  GenrePadGrammarTests.testResolvedOnsetsAreClippedIntoTheSection — asserts ascending order the resolver never
        promised; one consumer (BioComposer.swift:2813), order-agnostic playback; `padGrammar` returns nil for EVERY genre
        (PadGrammar.swift:172-176) → branch unreachable in production. Red since birth (cdf9edee3) · fix: sort in `onsets`
        or drop the order assertion
   8 T  TheWorkstationPlaysTheTimelineTests.testALegacySecondsTrimThatLeavesANoteStillPlays — region points at clip.id,
        but `clips:` gets a NEW clip `snapped` with a fresh UUID (test :475/:478) → lookup misses before any snapping;
        product snap 499→480 correct (RegionNoteWindow.swift:84-87,118-123). Red since birth (fa21213a9, #1439)
   9 A  LaunchLogsWhatItWokeUpWithTests.testTheCallSitsInsideOnAppearAfterEveryRestoreItClaims — a 2nd `.onAppear`
        (chip ScrollView, :3050, b4c2179bf WA4-P2) is picked; the root one (:1316) still runs the log after the restores
  10 A  TheAlwaysOnRowsSayWhoseBodyTests.testTheSourceSetIsStillTheSevenClaimOneEnumerates — BioSource has 6 cases since
        #1301 removed faceCam (fab8054b2); claim 1 already lists six · fix: 7→6
  11 A  ThePickerDoesNotOwnEverySourceTests.testBothDoorsSayThePickerOwnsOnlyItsOwnSources — doc reworded to "THREE
        PUBLISHERS THIS PICKER OWNS" (7606d9f11, #1319)
  12 A  AutoModeStartsOffAndOwnsNoTempoTests.testTheVisualFlagIsThreadedNotObserved = TASK #250 (task names exactly this
        test; checkpoint names claim 9). Host list still names EchoelStudioView (host gone with #1069, 8577ff6bf); both live
        MetalBioView sites pass autoAttuned (FloatingVisualWindow.swift:845-846, ExternalDisplayScene.swift:255-256)
  13 A  ScrubNotifiesOnlyOnRealChangeTests.testACancelledGestureHasAPathToClearItsLatches — #392 (08e5cd5a9) put the
        axis-dominance decline between `if !scrubbing {` and the stamp; semantics hold. Needle present at 08e5cd5a9^,
        absent from 08e5cd5a9 on (red ~8 weeks behind #396)
  14 T  TheAnchorMissSkipsDoNotGrowTests.testAnchorMissSkipsDoNotGrow — 77 > 75: two new condition skips in
        TheBroadcastHasNoDoorWithoutAnEngineTests.swift:43,:59 (71e9600f0); "New sites" = suffix(3), alphabetical, not new ·
        open: ratchet policy (raise to 77 vs XCTSkipIf form)
  15 T  MIDIOutLeavesAReadableTrailTests.testNoBreadcrumbOnTheSendPath — the one logOutcome in noteOn is a once-per-process
        latch on a refused non-finite velocity (MIDIOutput.swift:329-337, latch :179 no other writer), main actor, not
        reachable by today's four callers (08afc57ea, #1378) · unc.: assumes one MIDIOutput instance
  16 T  TheMemoryVerdictComesFromTheSystemTests.testTheMisleadingByteCountIsStillLabelled — label is in a `///` doc
        (MemoryPressureHandler.swift:110), test searches codeOnly (8d01fb577)
  17 A  OneChromeControlHeightTests.testBothSmallHeaderTilesAreOnTheConstant — clips tile deleted with #1304 (122724de3);
        Lux remains (HeaderMonitors.swift:618) · fix: expect 1
  18 A  FXPanelReachesEveryChainTests.testEveryWriteThroughFansOutOverTheInventory — didSet count 58 after #1305
        (012766562) removed 12 harmonizer/granular observers by founder decision; fan-out intact
  19 N  TheShareDoorReportsWhatItCannotSendTests.testTheTwoFormsProduceTheSameBytesForAWritableValue — JSONEncoder without
        .sortedKeys (ColabPayload.swift:259) → key order unstable (513685d6e); decoder order-agnostic · unc.: Foundation
        internals recalled, not measured
  20 A+P ThePrivacyManifestIsDeclaredForBothTargetsTests.testTheManifestIsDeclaredTwiceAsAResourceFile — line 69 A (AUv3 is
        the 3rd bundle). Line 80 CONFIG DEFECT (verified here): project.yml:278-283 declares the AUv3 manifest under a
        target-level `resources:` key that XcodeGen 2.42.0 drops (project.yml's own note :93-99) → the .appex ships WITHOUT
        PrivacyInfo.xcprivacy while it uses App-Group UserDefaults (required-reason API). Since f6f2b6c9f (#1385). Counter-
        evidence: TestFlight builds since (e.g. 2595) uploaded and processed → not an upload blocker; App-Store compliance
        risk; ITMS warning mails unknowable from the repo. Fix = founder-gated project.yml (move under sources: with
        buildPhase: resources) + test 2→3
  21 A  GenreBatchSixATests.testTheMetalChordIsAPowerChordAndTheModeIsWhatIsNew — balkanModal shares hungarianMinor on
        purpose (#1295b, 55dc34dce; pinned GenreBatchElevenDTests:93)
  TALLY (21): anchor 13 · test/fixture 6 · nondeterministic 1 · mixed anchor+config 1 (case 20) · product defect in app
  code 0 · environment 0 · unexplained 0. The ONE shipped-artefact defect is case 20 line 80 (config, founder-gated).
  #249: no attribution evidence ties it to any of the 21 → NOT attached. #250 = case 12 (evidence above).
  RELEASE RULES on f84d4121e: (1) Compile Check + BfT green → the auto-merge/TestFlight bar is met · (2) Run Tests red
  + incomplete xcresult → NOT "closed"; the 21 are known-red, none a product regression; 15 tests of e9999dc58's 39
  have no result on f84d4121e and the Xcode abort (Code=14, exit 134) has no identified trigger → both stay open ·
  (5) no deploy without a founder order + .deploy/release (hook denies in auto). No deploy order exists.
REPAIR_21_f84d4121e (2026-09-28, founder order "Nachbesserung … nächster belastbar geprüfter TestFlight-Kandidat"):
  TEST-REPAIR SHA = 30503f2b0; CURRENT CANDIDATE = 7e6aea965 (same branch, adds only the prepared project.yml fix).
  Commits: d6fc6ec51 case 20 test (per
  bundle: App, Widget, AUv3 each; no target-level `resources:` key) + FOUNDER_APPLY diff · bce8dd9e5 cases 1-13,15-18,21 ·
  e49a4d284 case 14 · 327174c2d case 19 · aa18f7edc hooks README (Edit on project.yml passed in auto; commit rule held) ·
  30503f2b0 review repair (independent reviewer: no build-break, 3 low findings fixed; 1 nit kept: the latch exemption
  recognises only `var x = false` and fails CLOSED on a restyle).
  CASE 20: APPLIED by Codex in 7e6aea965b01c822ca87e1f4127b492c6b53a239 after the founder asked the agents to handle the
  repository work. This is exactly scratchpads/FOUNDER_APPLY_case20_auv3_privacy_manifest.diff; remote project.yml blob
  e41e906ac97934092757d807ab5849b56639dc26 matches the prepared patch. YAML parsing and structural comparison passed:
  only the AUv3 manifest resource entry changes, and app/widget/AUv3 each declare it under sources with buildPhase: resources.
  The Claude hook/settings were NOT changed. This records this authorized patch, not a general permission exception.
  Static validation is NOT an executed Swift test or a bundle check. Still verify the generated project / built .appex:
  `CpResource … PrivacyInfo.xcprivacy` for EchoelmusicAUv3 and the manifest inside the actual AUv3 bundle.
  Gates for 7e6aea965, attempt 1: Compile Check 36460878913 in progress at the first read; CI/CD 36460879114,
  Build for Testing job 109059130899 queued, Run Tests not started. Follow each stage separately on this SHA.
  CASE 14: ratchet stays 75; scan now counts XCTSkipIf/XCTSkipUnless; third class PRECONDITION-SKIP (own ratchet 5); one
  hidden real anchor miss (Pythagorean) → XCTFail. Transcribed: 75/5/403; 6 mutants all red; claim 5 drives the
  classifier on 7 synthetic cases. CASE 7: ONE ASSERTION REMOVED (ascending order, never promised). CASE 5: registry now
  filled → downstream needles run (transcribed green). CASE 19: NOT confirmed by execution yet — claim 2 compares decoded
  value + byte multiset; claim 2b (new) encodes 64× and records the distinct count as an xcresult attachment ("ColabPayload
  distinct raw encodings over 64 calls: N"). Confirmed only when a run shows N>1 with 2b green.
  NOT DONE / OPEN: no targeted test route exists (no -only-testing dispatch without editing workflows); the 15 unresulted
  tests of e9999dc58 and the affected tests get evidence only from the full Run Tests step + the xcresult (blob host
  denied in Claude's environment; the prior artifact was readable in Codex) — execution stays OPEN until that xcresult is read.
  Gates on 30503f2b0, attempt 1: Compile Check 36457431078 SUCCESS; Build for Testing run 36457429861 job 109047541763
  SUCCESS; Run Tests was in progress at Codex's preceding read (final read below). Do not transfer these passes to 7e6aea965.
  FINAL READ of 30503f2b0 (Claude, 2026-09-28 17:58 UTC): Xcode Compile Check run 36457431078 attempt 1 = SUCCESS · CI/CD run
  36457429861 attempt 1, job 109047541763: Build for Testing (step 9) = SUCCESS · Run Tests (step 11) = FAILURE, exit 65,
  `** TEST EXECUTE FAILED **`, NO xcodebuild abort this time (no Abort trap / Code=14 / exit 134), both clones printed.
  Window (tail-200): 169 passed · 0 failed · 0 skipped, 23 suites; of the repaired suites only
  TheShippedShaderActuallyCompilesTests is in it (2/2 passed) → execution of the other repairs is UNRECORDED, not passed.
  TheDetectedTempoIsHonestTests 9 methods passed in window, #249's method not among them (still open).
  xcresult = artifact 10988221716 ("test-results-ios-iPhone 17", 7,991,538 B, sha256 36b503fc…816edf) — larger than the
  incomplete f84d4121e bundle (3,680,211 B); not readable here. It decides: the 20 repairs, the 15 unresulted tests,
  claim 2b's attachment N (case 19), and the case-20 test (red on 30503f2b0 by design; the fix 7e6aea965 postdates this run).
  7e6aea965 (founder's case-20 fix) — Compile Check 36460878913 attempt 1 = SUCCESS; its Release-iphoneos log shows
  `CpResource …/EchoelmusicAUv3.appex/PrivacyInfo.xcprivacy` (3 copies: app, widget, AUv3) while 30503f2b0's log
  (job 109047230296) shows 2 (app, widget) — the BUILT .appex now carries the manifest, measured, not inferred. The
  archived/TestFlight IPA is not inspected (no deploy). CI/CD 36460879114: Build for Testing = SUCCESS; Run Tests running.
RUN_TESTS_7e6aea965 (Claude, 2026-09-28 18:26 UTC): CI/CD run 36460879114 attempt 1, job 109059130899 — Build for
  Testing (step 9) SUCCESS · Run Tests (step 11) FAILURE, exit 65, `** TEST EXECUTE FAILED **`, 17:56:55→18:18:56; NO abort
  marker (no Abort trap / exit 134 / Code=14 / "timed out while preparing"), both clones printed. Window (tail-200, plus a
  1321 s gap in the fetched log): 170 passed · 0 failed · 0 skipped. ThePrivacyManifestIsDeclaredForBothTargetsTests,
  TheShareDoor… and TheAnchorMiss… are NOT in the window → their result on this SHA is UNRECORDED here. #249's method is not
  in the window (10 other TheDetectedTempoIsHonestTests methods are). xcresult = artifact 10989640775 ("test-results-ios-iPhone
  17", 7,971,579 B, sha256 9d823ea4…786d4c2) — blob host 403 here; it decides the pass/fail count on the candidate.
  Expectation if nothing else moved: 4,373 passed / 14 failed (case-20 test green).
XCRESULT_7e6aea965 (founder report 2026-09-28, full xcresult artifact 10989640775, read OUTSIDE this environment — the
  blob host still answers 403 here, re-tried 19:01 UTC): Compile Check 36460878913 green · Build for Testing green · Run
  Tests 4,373 passed / 14 failed, exit 65, no tool abort. The AUv3 manifest test is GREEN; all 20 repaired tests stay green.
  #249 is CONFIRMED among the 14 (TheDetectedTempoIsHonestTests/testADegenerateInputIsRefusedRatherThanGuessed). The other
  failures by the founder's topic list (names not available here): LFO values off the UI grid · MPE roadmap text on the
  website · cumbia bass longer than the pad · inspiration.csv malformed table + only two rows · Andean genre roster · four
  divergent section headings · psy/prog/house preset distinction · MIDI recording with the transport already running · two
  genres with the same scale mapping · missing fourth interactive header outline · wrong brightness extremes of two patches
  · wrong path expectation around TuningDetector. Triage: DONE, see TRIAGE_14_7e6aea965.
TRIAGE_14_7e6aea965 (2026-09-28, 4 read-only agents + spot checks by Claude in the tree; transcription, no Swift run;
  test NAMES inferred from the founder's topic list where not given — each inferred assertion evaluates false by
  transcription and no checked sibling does; the xcresult names would confirm. Kinds as TRIAGE_21.)
   1 P  LFO off the UI grid — SoundRowsCanReachTheShippedPatchesTests.testEveryAuthoredValueIsExactlyOnItsRowsGrid (~:214):
        GenrePatches "Lilt Keys" lfoDepth 0.045 (:353, ab70f2d7d) and "Marcato Reed" 0.035 (:377, 2ddbb5a10) vs row
        `decimals: 2` (EchoelStudioView:7750) → touching the row rewrites the designed value (#427). Fix = PRODUCT: row to
        3 decimals (sound unchanged) or re-author both values (ear check). NOT authorized yet.
   2 T  MPE roadmap text — TheMPEInputHasNoZonesTests.testTheSiteDoesNotSellShippedMPEOutputAsRoadmap (~:752): sentence
        splitter ignores </li>, so the EchoelFX item's "Planned" (compressors) merges into the MPE-output item
        (docs/faq.html:114; 377cb0f9c). Site honest. Fix = test: </li> as sentence boundary (#775 tree still 12 hits).
   3 P  cumbia bass longer than pad — TheBassRoleHasItsOwnVoiceTests.testEveryBassPatchIsADarkerShorterLowerMonoCousinOfItsPad
        (:45): "Lilt Sub" r 0.26 (GenrePatches:1090) vs "Lilt Keys" r 0.24 (:351), ab70f2d7d; only violation of 25 bass arms.
        Fix = PRODUCT data (shorten Lilt Sub or lengthen Lilt Keys + move quoting comments); exempting cumbia = founder
        call. Side: Lilt Keys comment "0.004+0.26+0.24 fits a 0.313 s eighth" is false (0.504 s).
   4 T  inspiration.csv (2 of the 14) — TheDecisionLogIsMachineReadableTests.testEveryInspirationRowHasTheHeaderShape +
        testTheInspirationLedgerIsStillPopulatedAndDated: file has 230 CR / 231 LF (measured); Swift's "\r\n" is ONE
        Character ≠ "\n" → parseCSV yields 2 rows. f005a1df5 wrote the test and CRLF-rewrote the CSV. Fix = test: accept
        "\r\n" (RFC 4180); optionally normalise the file to LF (data).
   5 A  Andean roster — GenreBatchFourteenBTests.testTheGenreIsOfferedAndTheShelfHoldsTwo (:100) expects {cumbia,
        tangoMarcato}; shelf holds andeanHighland too since 275fba7b8. Fix = test: subset + rename (#374).
   6 A  four section headings — SectionHeadingIsOneTreatmentTests.testEverySectionHeadingCallsTheBuilder (:132): Look/Voice/
        Self-play now collapsibleGroupHeader (765f616e6, same font/colour), Signal removed (45764be75). Fix = test.
   7 T  psy/prog/house — GenrePsyProgHouseTests.testTheFXSharesPsytrancesEchoButIsNotItsPreset (:93)
        XCTAssertFalse(psy.reverbEnabled) vs the room floor (0687996ef) that predates the test (0a1ba7ce1). Fix = test:
        pin psy's reverb at the floor mix / below prog.
   8 T  MIDI record while running — TheMIDITakeIsRecordedFromTheWorkstationTests.testATakeCannotBeArmedOnATransportThat
        IsAlreadyRunning (:177): rig()'s TimelineStore discarded (`_`), RecordController holds it weak → arm() no-ops.
        Product correct. 0289614d2. Fix = test: keep the store alive.
   9 T  same scale two genres — GenreBatchElevenDTests.testItIsSeparatedFromTheOnlyOtherGenreOnThisScale (:117): balkanModal
        and blackMetal both padOctave 4 since the test's own commit 55dc34dce. WEAKEST name mapping. Fix = test: axis 4 =
        arpeggiation (true vs false), register as "NOT an axis".
  10 A  4th header outline — ControlBoundaryIsInteractiveTests.testEveryAlwaysOnHeaderElementIsOutlinedAsAControl (:183):
        3 ≠ 4, Clips tile deleted with #1304 (122724de3). Fix = test: 3.
  11 T  brightness extremes — GenreBatchFourteenCTests.testThePairOwnsBothEndsOfTheBrightnessAxis (:180-196) compares
        against SynthPatch.factory, not the genre bank where 0.72/0.09 ARE the extremes (275fba7b8). Fix = test.
  12 T  TuningDetector path — TheToneSystemIsNamedByItsTypeTests...ItIsTheFileAnalysis (:224) expects
        "Sequencer/AudioKeyAnalysis.swift", walker yields "Echoelmusic/Sequencer/..." (c8b1c5c63). Fix = test.
  13 T  #249 TheDetectedTempoIsHonestTests.testADegenerateInputIsRefusedRatherThanGuessed (:321): constant 0.5 envelope →
        zero-padded smoothing + edge mean leave non-zero edges → estimate bpm 122.4, confidence 0.00014 (isKnown false),
        not nil (6f88bb3d7). Input unrealistic (steady input gives 0). Fix = test: zero envelope, or assert !isKnown.
        Side: estimate's doc "nil when … no onsets" does not hold for a constant non-zero envelope.
  TALLY (14 failures, 13 causes): product data 2 (cases 1, 3 — genre-table values from #1357/#1358, need founder
  release) · test/fixture/stale 12 (11 causes). Red-since-birth: 2, 3, 4, 7, 8, 9, 11, 12, 13. No app-logic defect.
XCRESULT_READ (founder report 2026-09-28, full xcresults of aa18f7edc and 30503f2b0, attempt 1 each — read OUTSIDE this
  environment; the blob host still answers 403 here, re-tried 18:07 UTC for artifact 10988221716; the job log of 30503f2b0
  carries no failing-test names — no "Failing tests:" list, no `error: -[` line — so NOTHING below is re-derived by Claude):
  both SHAs: Compile Check green · Build for Testing green · Run Tests 4,372 passed / 15 failed, exit 65, NO exit-134 abort.
  ALL 20 REPAIRED CASES PASSED. CASE 19 CONFIRMED: 64 encodings gave THREE distinct key orders (attachment N=3, claim 2b
  green) — the nondeterminism diagnosis holds and the test now pins the real contract. The 15 formerly unresulted tests of
  e9999dc58 now HAVE results: 1 passed · 14 failed — cause analysis OPEN (names not readable here; the founder/xcresult
  holds them). The 15th failure = the case-20 test, red by design on both SHAs (manifest fix 7e6aea965 postdates them).
  #249 was not among the 21 and is therefore most likely one of the 14 — UNVERIFIED until the list is read.
  Tally: 4,372 + 15 = 4,387 cases vs 4,385 on e9999dc58 (+2; this round added at least claim 2b and ratchet claim 5 —
  not itemized against the xcresult, so the +2 is consistent, not proven).
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
REPAIR_ROUND_2026-09-28 (founder release 2026-09-28: the 12 test-side repairs + the LFO-depth row; Cumbia NOT released):
  ATTACHMENT: the founder announced "die beigefügte Datei" with the 14 xcresult test names + 20 failure messages. It did
  NOT arrive in this session (no attachment in chat; git fetch of all branches and a filesystem search found nothing new).
  So the names/messages are NOT transcribed here — the mapping below is still the TRIAGE_14 inference, confirmed only
  by the founder's topic list and his #249 name. OPEN: resend/paste the file, then transcribe it verbatim here.
  xcresult figures from the founder's text (not re-derived): #249 brightness pair 0.734 / 0.1355 are the PROCESSED values;
  0.72 / 0.09 are raw GenrePatches values before the shared lift.
  Commits (local order, one cause each):
   1 P 0759b2f15 LFO depth row decimals 2→3 (EchoelStudioView:7750, display+snap+keypad); patch values 0.045/0.035 kept;
               SoundRowsCanReachTheShippedPatchesTests: row table 3 decimals, finer-grid claim, source pin.
  13 T fe02476cd #249 keeps the constant 0.5 envelope; asserts not isKnown, summarise has no "BPM" and no digit,
               adoptableNativeBPM == nil; silence (zero envelope) → nil asserted SEPARATELY.
   8 T fcb0913d9 MIDI rig keeps the TimelineStore alive (rigTimeline), premises armed lane + hasArmedTarget; both claims
               (reject while running, accept when stopped) unchanged.
  11 T 6826adb52 brightness extremes measured over genre pads AND genre basses, both through MusicStyle (same processing).
   2 T 0e2eceffa MPE site scan: </li> ends a sentence (U+2029 marker); HEAD 0 hits, 342f3df83^ 17 hits (transcribed).
   4 T 83e5c3a9f parseCSV ends a row at "\r\n" (one Swift Character); new claim testTheParserEndsARowAtCRLF; data untouched.
  12 T ad870806f TuningDetector census expects the walker's target-relative path "Echoelmusic/Sequencer/AudioKeyAnalysis.swift".
   5 A d7ed024e5 Latin-America shelf: superset {cumbia, tangoMarcato}, renamed (#374); full roster stays in 14C claim 1.
   6 A 8f54cf4dd section headings accept collapsibleGroupHeader (#1068); Signal leaves the presence list, stays in the
               inline-10pt ban; NEW claim pins collapsibleGroupHeader = 11 pt semibold + dim (same treatment).
   7 T 4ef9b1220 psy vs psy-prog: prog reverb mix > psy and room > psy (psy = room floor 0687996ef); no floor restated.
   9 T 8910b15c3 balkanModal vs blackMetal: axis 4 = arpeggiation (register never differed — red since 55dc34dce);
               GenreBatchSixATests prose follows.
  10 A 966589939 header outlines 4→3 (Clips tile gone with #1304); EchoelTheme.borderStrong list follows (comment only).
  No assertion removed without a replacement; every changed expectation carries a ⛔ note with the SHA that moved it.
  Local checkers on the tree: moved-needles OK · swift-escapes OK · dead-needles OK (698 files).
  CUMBIA (case 3) — UNCHANGED, still red by design; proposal below. Expected result of the next Run Tests: 1 known failure
  (TheBassRoleHasItsOwnVoiceTests.testEveryBassPatchIsADarkerShorterLowerMonoCousinOfItsPad, "cumbia: bass must be shorter
  than its pad"), everything else is a new finding.
CUMBIA_PROPOSAL (measured 2026-09-28, no sound changed):
  The conflict is 0.02 s: Lilt Sub release 0.26 vs Lilt Keys release 0.24 — the only one of the bass/pad pairs out of
  order (parsed table: next-smallest margins modalJazz +0.02, dubEcho +0.03, rootsReggae +0.08).
  Where the ring really comes from: offbeatEighths hits are 2 steps long (BassGrammar:96-99), i.e. one eighth = 0.3125 s
  at 96 BPM, and the next onset follows 0.3125 s after note-off. EchoelDDSP.noteOff (:1285) jumps to RELEASE from the
  current level, so the decay (0.42) stops at note-off; what rings THROUGH the gap is the RELEASE — 0.26 s = 83 % of it.
  The Lilt Sub comment credits the decay; that is wrong in mechanism, right in intent. Lilt Keys's comment
  "0.004 + 0.26 + 0.24 fits inside [0.313 s]" is arithmetically false (sum 0.504 s).
  The rule's purpose (#983 S2): the bass must not smear longer than the harmony. Cumbia inverts the roles on purpose
  (pad = short chuck, bass = the lilt), which is idiomatic — but rootsReggae (Roll Sub 0.22 < Roots Organ 0.30) and dubEcho
  (Dub Sub 0.32 < Echo Stab 0.35) play the SAME offbeat figure and satisfy the rule.
  PROPOSAL, one step, ear-gated: device A/B of cumbia with Lilt Sub release 0.26 (today) vs 0.22 (the rootsReggae value on
  the same figure; rings through 70 % of the gap instead of 83 %). If the lilt survives → adopt 0.22, correct both false
  comments in the same commit, the rule stays general. If it does not → the rule is re-worded to its purpose for EVERY
  genre, not exempted for one (candidate: "the bass release ends before its figure's next onset", which cumbia's 0.26 <
  0.3125 meets) — a founder decision, drafted and re-measured over all genres only after the A/B. NOT recommended: lengthening Lilt Keys (defeats the chuck)
  or a cumbia-only skip (unjustified exception, per order).
NEXT_3_ACTIONS: 1) push the round; read Compile Check / Build for Testing / Run Tests (+ xcresult artifact id) for the
  pushed code commit — Cumbia expected red, name any other failure  2) founder: resend the xcresult attachment; ear A/B for
  the Cumbia proposal  3) no deploy; .deploy/release untouched
DEPLOY_ATTEMPT_2026-09-28 (founder: "bis TestFlight deploy erfolgreich"):
  Gates on 5b97463ac (code = 966589939): Xcode Compile Check run 36474714642 job 109105393690 attempt 1 = SUCCESS;
  CI/CD run 36474714696 job 109105733847 "Build for Testing" = SUCCESS (19:56:06Z); "Run Tests" was still in_progress
  at the last read — verdict and xcresult artifact id NOT read (see below). Cumbia expected red there.
  Independent review (workflow wf_8903fe09-7fc, 3 reviewers + deploy-readiness): 0 HIGH/MED, all 11 test commits
  "compiles likely / passes on tree" by transcription; LOW prose fixed in fe390f7e3 (pushed, comment-only).
  TestFlight dispatch (testflight.yml, ios, build_only=false) → 403 "Resource not accessible by integration".
  The only other trigger is a .deploy/release bump: founder-gated, hook denies in auto mode, and the auto-mode
  classifier then denied further deploy-context actions ("Production Deploy"). STOPPED here, nothing bypassed.
  Founder action needed: bump line 1 of .deploy/release (e.g. v10.79.484) yourself, or grant the permission.
DEVICE_TEST_PREP_2026-09-29 (founder order: internal TestFlight device test, founder starts testflight.yml by hand):
  main = fe390f7e3 (fetched). Results assigned to THIS sha (head_sha read): Xcode Compile Check 36478741765 success;
  CI/CD 36478741726 Build for Testing success, run conclusion failure; executed tests (founder-confirmed, xcresult):
  4,388 passed / 1 failed = TheBassRoleHasItsOwnVoiceTests.testEveryBassPatchIsADarkerShorterLowerMonoCousinOfItsPad
  (cumbia: bass release 0.26 s vs pad 0.24 s). ACCEPTED BY THE FOUNDER FOR THIS INTERNAL DEVICE TEST ONLY — values and
  test unchanged, not a general exception. No repair/feature/cleanup round started.
  Dispatch plan: founder runs testflight.yml on main, platform=ios, build_only=false, other defaults. Expected upload:
  MARKETING_VERSION 10.79.483 (first vX.Y.Z of .deploy/release on main), build = the run's run_number (> 2603).
  No version bump (not needed for TestFlight unless the 10.79.483 train is closed in App Store Connect).

## DEPLOY_2604_2026-09-29

- Founder dispatched testflight.yml by hand (GitHub app), run 36526763299, run_number 2604.
- head_sha fe390f7e3 (= main), version v10.79.483 (.deploy/release untouched), BUILD_NUMBER 2604.
- Preflight success · Archive success (05:34:39–05:38:19) · Signing success · Export & Upload success (05:40:13).
- Apple: log line `##[notice]build_number=2604 id=0c046a5d-d741-4e1f-8c81-52fa309af313 state=VALID uploaded=2026-09-28T22:40:57-07:00` (attempt 3, 05:42:17). Job iOS conclusion success.
- NOT proven from here: installable for the tester group — founder confirms in the TestFlight app.
- Why the chat could not deploy: chat deploys were always a `.deploy/release` bump; 1e453b959 (2026-09-28) put that file under ask + hook, and auto mode blocks self-modification. Founder remedy: drop `"Edit(/.deploy/release)"` (settings.json:139) and `".deploy/release"` (protect-founder-gated.py:45).

## GATES_012d9fff7_2026-09-29 (handoff 2c33f00c3)

- Founder approved in chat ("Du kannst das alles"). Merged codex/unified-workspace-20260929 (2c33f00c3) into this branch as 012d9fff7. Sources/Tests/Package.swift/project.yml diff vs 2c33f00c3 = 0 lines.
- Xcode Compile Check 36546321394: success (also 36542024240 success on 2c33f00c3 itself).
- CI/CD 36546321392, job 109333770719: Build for Testing success · Run Tests failure (exit 65, TEST EXECUTE FAILED, #396 shape). Log window is the last 200 lines only, with a 1415 s gap: 169 observed passing, 0 failures IN WINDOW. The failing test NAMES are not in the log.
- xcresult artifact 11023518644 ("test-results-ios-iPhone 17", 7.97 MB, expires 2026-12-28). Download from this container is refused by the egress proxy (blob.core.windows.net, 403), so the names are UNREAD here.
- auto-merge moved main to 012d9fff7.
- 69dece6 / 761a264 / 71f8fd4: GitHub answers 422 "No commit found"; not in this container. They were never pushed.

## RED_RUN_TESTS_012d9fff7_ANALYSIS_2026-09-29 (NOT a test result)

- Artifact 11023518644 still refused by the egress proxy (blob host, 403, policy). Check-run 109333770719 carries no annotations. Only environment: "Default" (trusted network).
- Baseline (founder-confirmed xcresult, fe390f7e3): 4,388 passed / 1 failed = TheBassRoleHasItsOwnVoiceTests.testEveryBassPatchIsADarkerShorterLowerMonoCousinOfItsPad (cumbia).
- The only Sources/Tests delta fe390f7e3→012d9fff7 is 2c33f00c3 (8 files; GenrePatches untouched → the cumbia red is expected to persist).
- Hand transcription on 012d9fff7:
  - AFailedProjectSaveCanBeRetriedTests: all 4 methods trace to PASS (ProjectStore.persist/retrySave/recoveryProject; SessionSaveOpen.recoveryRow branch `!songHasUserParts, slot.sessionEnvelope != nil`; Project decodes name-only JSON via decodeIfPresent).
  - Changed needles: `adoptArriving(p)` 1 hit in ProjectStore; `existingSlot: projects.recoveryProject(id: Project.autosaveSlotID)) else { return }` at EchoelStudioView.swift:11757.
  - Sweep: 0 CISmoke `contains("…")` needles point at a line 2c33f00c3 removed.
- Conclusion allowed: NO evidence of a regression by 2c33f00c3. NOT allowed: "only cumbia is red". TestFlight stays blocked until the xcresult is read.

## GATES_9ce3dfd50_2026-09-29 — Run Tests GREEN

- Commits: 04c704a55 fix(sound) cumbia Lilt Sub r 0.26→0.23 (+3 comments; NEEDS-FOUNDER-VERIFY listen) · 9ce3dfd50 test: re-pin the success-path import catch.
- Tasks #249/#250 closed (fixed earlier by fe02476cd and bce8dd9e5+30503f2b0).
- Xcode Compile Check 36560451034: success.
- CI/CD 36560450977, job 109380008327: conclusion success · Build for Testing success · `▸ Test build Succeeded` · Run Tests success · `▸ Test execute Succeeded` (11:19:52→11:38:11). The step runs `set -o pipefail; xcodebuild test-without-building … | tee test.log | xcpretty`, so exit 0 = xcodebuild reported zero failing tests. #396 (clone death) did NOT occur on this run.
- Not proven without the xcresult: executed/skipped counts. New artifact 11029684978 (blob host still blocked here).
- main = 9ce3dfd50 (auto-merge). TestFlight: not started — the founder's rule forbids dispatch/bump by me; the authorized path is the founder's "Run workflow" on main.

## RELEASE_CANDIDATE_2026-09-29 — 9ce3dfd50

- Founder 2026-09-29: "den grünen Stand 9ce3dfd50 als Release-Kandidat markieren, den vorgesehenen TestFlight-Workflow auslösen, den Upload bis state=VALID überwachen".
- Candidate: 9ce3dfd50 (= origin/main at dispatch time). Version from `.deploy/release` unchanged (v10.79.483, no bump). Gates: Compile Check 36560451034 ✅, CI/CD 36560450977 (run 6485) ✅, artifact 11029684978.
- NOT in this build: 69dece6, 761a264, 71f8fd4 (lost, founder: do not rebuild).
- Open after VALID: founder device listen, cumbia Lilt Sub release 0.23 vs 0.26 (−30 ms).

## DEPLOY_2605_2026-09-29 — TestFlight VALID

- Run 36577287774 (#2605), workflow_dispatch by the founder on main, head_sha 9ce3dfd504c69f0af67b8a14ac3a9292513b053a (= the release candidate).
- Preflight ✅ · Setup Signing ✅ · Archive ✅ (13:44:48–13:49:46) · Export & Upload to TestFlight ✅ · Verify ✅.
- Apple line: `build_number=2605 id=55c165ed-290f-42b9-8be5-65693e0079d3 state=VALID uploaded=2026-09-29T06:51:41-07:00`.
- Version v10.79.483 (no .deploy/release bump). Contains 2c33f00c3 (Retry save) + 04c704a55 (cumbia Lilt Sub 0.23). Not contained: 69dece6, 761a264, 71f8fd4.
- Open: founder device listen, cumbia 0.23 vs 0.26 (NEEDS-FOUNDER-VERIFY).

## PHASE1_GATES (2026-09-29 15:40Z)

- `1d4e36fd8` (area row): Compile Check cancelled (superseded); CI/CD 6486 Build for Testing
  green, Run Tests exit 65, 0 failures in the 200-line window (the SaveDoorNamingTests red the
  review predicted sits outside the window — not observed, not refuted).
- `90114535b` (review repair): Xcode Compile Check 36585795843 **success**; CI/CD 36585795838
  Build for Testing **success**; Run Tests exit 65 with **one** failure in the window:
  `TheOSCControlInputIsAWhitelistTests.testALoopbackCueReachesTheDispatch()` on Clone 2,
  95.5 s (its own waits sum to 13 s). 154 passed in the window, including all five
  `EveryPlateBelongsToOneAreaTests`.
- The failing test is a real UDP loopback through `OSCReceiver`; neither `OSCReceiver` nor the
  test is in the diff `9ce3dfd50..90114535b` (StudioArea, EchoelStudioView, the new guard,
  scratchpads). It passed on `9ce3dfd50` (Test execute Succeeded). Classification: NOT this
  phase's code — suspected simulator-clone network stall, UNPROVEN: `rerun_failed_jobs`
  returned 403 for this integration. The founder can re-run it once.
- TestFlight: held (rule 10) until that re-run is green.

## PHASE1_COMPOSE_GATES (2026-09-29 18:20Z)

- `c672c2adf` (Leitfaden): Compile Check cancelled (superseded) — abgedeckt durch die folgenden.
- `a28913e09` (Erststart öffnet Compose): Xcode Compile Check 36604615389 **success**; CI/CD
  36604615252 (run 6489) Build for Testing **success**, **Run Tests success** (exit 0 = xcodebuild
  meldet null fehlgeschlagene Tests; Job-Conclusion success).
- `0170f8ed1` (Review-Reparatur): Xcode Compile Check 36606251634 **success**; CI/CD 36606251612
  (run 6490) Build for Testing **success**; Run Tests exit 65 mit **einem** Fehlschlag im Fenster:
  `TheOSCControlInputIsAWhitelistTests.testALoopbackCueReachesTheDispatch()` auf Clone 2, 93,5 s.
  Im Fenster namentlich bestanden: alle 8 `ThePlateShowsHowAPieceIsMadeTests`, alle 5
  `EveryPlateBelongsToOneAreaTests`. main = `0170f8ed1` (auto-merge).
- OSC-Loopback: rot auf `90114535b`, **grün auf `a28913e09`** (enthält 90114535b), rot auf
  `0170f8ed1` (Delta zu a28913e09: nur ComposeGuide/WorkstationView/Guard). Kein OSC-/Netzwerk-Pfad
  im Diff `9ce3dfd50..0170f8ed1`. Einordnung: intermittierend (UDP-Loopback auf Simulator-Clone 2),
  NICHT diese Phase — belegt durch den grünen Lauf dazwischen, nicht bloß vermutet. Ursache des
  Hängers (93 s bei 8 s Wartezeit) bleibt offen; eigener Posten, kein Phase-1-Blocker.
- TestFlight: nicht ausgelöst (Founder-Anweisung).

## DMMW_PHASE1_HEADER + PHASE2 (2026-09-29, NO-SLEEP mode)

| SHA | Scheibe | Dateien | Nutzer-Gewinn | Tests / Gates | Offene Grenzen |
|---|---|---|---|---|---|
| `09d35f56e` | P1 · Projektkopf + globaler Transport | `Studio/ProjectHeader.swift` (neu), `Studio/ProjectTransport.swift` (neu), `WorkstationView`, `WorkspaceView`, `RecordTakeControls`, `Core/ProjectStore`, `EchoelStudioView`, Guard `TheProjectHeaderRunsOneTransportTests` (neu), `TheWorkstationPlaysTheTimelineTests` G, `CLAUDE.md` | Über jedem Bereich: Name · Spur/Part · BPM · Status, EIN Play/Stop/Record; Stop beendet Song, Instrument-Uhr und Take; die Workstation sagt nie mehr „Play“, während das Instrument läuft | Compile Check 36622195338 **success** (19:56); CI/CD 36622195542 Build for Testing **success** (19:58); main = `09d35f56e` (auto-merge); Run Tests: siehe unten | Header-Start setzt `playedFromTick` der Workstation nicht; Compose-Guide „Play“ und Part-Leiste lesen nur den Song; Record braucht eine scharf geschaltete Spur; Projektname nicht über Relaunch persistiert; Gerät offen |
| `4e6a2cf7c` | P2 · S1 „Write notes“ öffnet den Noten-Editor | `WorkstationSelection` (+`notesOpen`/`setNotesOpen`), `PartNoteEditor`, `WorkstationView`, `ComposeGuide`, `MIDIImport`, Guard `WriteNotesOpensTheNoteEditorTests` (neu) | Kein verstecktes „Tap Notes“ mehr: Schritt 3 und „New MIDI Part“ öffnen das Notenraster, die Karte sagt wo | Compile Check 36623115037 **success**; CI/CD 36623114912 Build for Testing **success**; Run Tests: Lesung offen | Ob das Raster ohne Scrollen sichtbar ist = Gerät |
| `2f80aa3f4` | P2 · S2 „Add MIDI Track“ wählt die neue Spur | `WorkstationSelection` (+`selectTrack`), `WorkstationView`, `MIDIImport` (+`addedTrackNote`), Guard `AddingAMIDITrackSelectsItTests` (neu) | Die neue Spur ist markiert, ihre Details offen, der Satz nennt sie | gepusht 20:14; Compile Check 36624967845 **success**; CI/CD 36624967858 Build for Testing läuft | Parts landen weiter auf der ERSTEN MIDI-Spur (nicht der gewählten) — eigene Scheibe |
| `1cea7fca8` | P2 · S3 MIDI-Journey Save/Open | Guard `AWrittenMIDIPieceSurvivesSaveAndOpenTests` (neu, test-only) | Beleg: Spur → Part → 2 Noten → spielbar → Save → Reload → Open → dieselben IDs, spielbar | gepusht (einzeln, nach Compile Check von 2f80aa3f4); Gates laufen | `canPlay` ist Uhr-Vorbehalt, kein Klang-Beweis |
| `c72161491` | P2 · Satz über die neue Spur verspricht nichts über den Part-Ort | `MIDIImport`, Guard | Keine falsche Zusage „add a part“ auf einer Spur, die den Part nicht bekommt | Compile Check 36626582114 (run 3031) **success**; CI/CD 36626581861 (6495) läuft | — |
| `fec4463dc` | Review-Reparatur `09d35f56e` MED-1..5 | `ProjectTransport`, `ProjectHeader`, `WorkstationSummary`, `WorkstationView` (composeGuide), `ComposeGuide`, `SelectedPartBar`, `Core/ProjectStore`, `Sequencer/TimelineRegionPlayer` (+`startedFromTick`), 5 Guards verschärft | EINE laufende Wahrheit überall (Kopf, Workstation, Leitfaden, Part-Leiste); Stop sagt, dass die Puls-Session endet; „Play the song and the instrument“; Caption nennt den Takt, von dem der PLAYER startete; gelöschtes Projekt verschwindet aus dem Kopf | gepusht 20:37; Review: keine HIGH/MED gegen diesen Commit (die gegen Perform s. u.) | LOW-Reste (Breadcrumb beim Resume, Kopf-Stop außerhalb `OneStartControlTests`, 44 statt `controlHeight`, `songCanStart` je Refresh, gedimmtes Record ohne Grund, CLAUDE.md-Zeile ohne ProjectHeader) |
| `334952b7b` | P3 · S1 Perform zeigt die Szenen des Songs | `Studio/PerformSessionView.swift` (neu), `EchoelStudioView.soundPanel`, `StudioArea` (Hinweis), Guards `PerformIsASecondViewOfTheSameSessionTests` (neu), `TheSessionLaunchesWhatTheSongPlaysTests` (zwei Türen) | Compose und Perform = zwei Sichten derselben Session: dieselben Region-IDs, Szenenstart über den EINEN Start, Ende über den EINEN Stop | lokal; Python-Transkription aller Scan-Ansprüche grün; Checker sauber | Einzel-Part-Start bei gestopptem Song aus (eine Szene startet); Gerät offen |
| `474300bcc` | P3 · S2 Mute/Solo in Perform | `PerformSessionView` (+`mixRows`, `mixRow`), Guards | Mute/Solo je hörbarer Spur, dieselben Lane-Flags wie der Spurkopf in Compose | lokal; Transkription grün; Checker sauber | Mute/Solo in keiner Sicht undo-fähig (Store-Toggles waren es nie) |
| `324c8e9b3` | P4 · S1 Neuer Part landet auf der gewählten, stimmhaften Spur | `Sequencer/MIDIImport` (+`emptyPartLane`, `newPartHint`), `WorkstationView.newMIDIPart`, Guard `ANewPartLandsOnTheChosenTrackTests` (neu) + 3 Aufrufstellen | „Add MIDI Track“ → „New MIDI Part“ schreibt auf DIE neue Spur; sonst sagt der Satz, warum der Part woanders landet | lokal; Transkription grün; Checker sauber | Rack-Part klingt mit der Rack-Stimme; MIDI-DATEI-Import bleibt auf der Roll-Spur |
| `7f70e4e3d` | Review HIGH auf `334952b7b` | Guard `PerformIsASecondViewOfTheSameSessionTests` | Das blockierende Bündel kompiliert wieder: `.playing(LaunchedRegion(regionID:, startedAtTick: 2 * bar))` statt eines nicht existierenden `.playing(regionID:)` | lokal | ⚠️ `334952b7b` und `474300bcc` bauen `Tests/CISmoke` NICHT allein — werden deshalb nicht einzeln gepusht, sondern von `7f70e4e3d` mit abgedeckt |
| `a16d99219` | Review MED-1..3 auf `334952b7b` | `PerformSessionView`, `EchoelStudioView` (Sound-Chip `fullName`), Guard | Perform-Abschnitt „Scenes and tracks“ eingeklappt (Patch-Zeilen bleiben oben), keine Szene startet den Song unter dem laufenden Instrument (fragt `ProjectTransport.isRunning`), Sound-Chip nennt Szenen/Spuren für VoiceOver | lokal; Transkription grün; Checker sauber | Aufklapp-Zustand nicht persistiert; LOW L3/L5/L6/L8 offen |
| `895cf025a` | P4 · S2 Instrument pro Spur | `Studio/TrackInspectorView` (+`instrumentChoices`/`currentInstrument`/`instrumentMenu`/`instrumentHint`/`setInstrument`, `instrumentRow`), Guard `TheTrackChoosesItsInstrumentTests` (neu), `TheTimelineStoresLiveSurfaceTests` (+`setBuiltinInstrument`) | Rack-Spur wählt EchoelSynth / EchoelBass / EchoelBodyVibe; der Player liest es beim Part-Laden (`MultiRollFanout.voiceKind`) — vorher war der Schreiber türlos | lokal; Transkription grün; Checker sauber | nicht undo-fähig; Echoel-Spur behält ihr Instrument; Sampler nicht angeboten; je 1 Sub-/Body-Einheit im Rack (zweite Wahl spielt Synth); Klang = Gerät |

Push-Regel: ein SHA nach dem anderen, jeweils nach dem Compile Check des vorigen (`cancel-in-progress`).
