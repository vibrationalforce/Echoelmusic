# Round 1 — ux: PASS

range: eb590a340..5fa2464245b82ab5227d29cce2e8db208bb6a14d
since: None
paths: EchoelStudio/Core/Sources/EchoelCore/DiagnosticLog.swift, EchoelStudio/Core/Tests/EchoelCoreTests/DiagnosticLogTests.swift, EchoelStudio/App/EchoelStudioApp.swift, EchoelStudio/App/Engine/AudioEngine.swift, scratchpads/factory/010-diagnostics-hardening
criteria: 10  deviceCriteria: []  founderAssumptions: 0  recount: False
workflow: wf_7897b747-bee

UX and claims lens, round 1 of job 010. There are no earlier reviews under scratchpads/factory/010-diagnostics-hardening/reviews/. This job comes from the job-008 round-1 minors, and the 008 ux minor on the run headers is fixed. DiagnosticLog.swift:20-22 now has "== run before ==" and "== latest run ==", and the launch line ends with ", times in UTC" (line 49). The other two 008 ux minors (the privacy-page sentence and the tester pointer to the path) are left out on purpose by A6 and Out of scope. No sentence becomes false because of that, so the deferral stands.

The diff adds no screen, control, sheet or on-screen string. EchoelStudioApp.swift:38 only moves StoreController() after beginApp(), and AudioEngine.swift:160 only marks the os_log description .private. So VoiceOver, Dynamic Type, contrast, reduce motion, the 3 Hz flash cap and the Uncodixfy rules do not apply.

The only user-visible text is the shared file in Files, and every sentence in it is true for this build:
- "times in UTC": timestamp() at lines 198-215 is pure UTC arithmetic with a Z suffix.
- "latest run": after a crash and before the next launch, the last run in the file is the one that died.
- The full line still says later lines are dropped: append() returns once isFull is set.
- A cut final byte costs one character (U+FFFD), not the run. tail() decodes lossily, and isOwn() rejects only control characters, so the cut line survives.

I found no stale reference to the old header names or the old launch-line shape in docs/, ContentPipeline/CLAIMS.md, docs/dev/FEATURE_STATUS.md, docs/privacy.html, EchoelStudio/RELEASE or fastlane. A2 holds: EchoelStudio/RELEASE last changed at 394299ab2, before 008's head 42d91ecfb, and not since, so no shipped build carries the old format. There is no health, wellness or esoteric wording.

I checked criteria 6, 8 and 9 by reading the code:
- 6: begin, both note overloads and the error note each call Self.timestamp(clock()) before lock.lock() (lines 50/51, 85/86, 96/97).
- 8: _plugins is set at EchoelStudioApp.swift:38, after DiagnosticLog.beginApp() at line 21.
- 9: AudioEngine.swift:160 passes the description with privacy: .private.

One wording point is left, and it is minor.

Findings:
- **minor** `EchoelStudio/Core/Sources/EchoelCore/DiagnosticLog.swift:24` — A3 renamed the headers because 'this run' reads like the running one. The full line still says "diagnostics: this run's log is full, later lines are dropped". This line now carries a timestamp and passes isOwn(), so after the next launch it moves under "== run before ==". A reader then sees 'this run' directly above "== latest run ==" and can take it to mean the latest (current) run is full. That is the same misreading A3 fixed for the headers. Wording only: the line's position already says which run it belongs to.
  - Fix: Drop the run reference, e.g. "diagnostics: log full, later lines of the run are dropped" or "diagnostics: log full, later lines are dropped". The tests already go through DiagnosticLog.fullLine, so only the constant changes.
