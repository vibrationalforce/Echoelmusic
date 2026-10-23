# Round 1 — approver: APPROVE

range: eb590a340..5fa2464245b82ab5227d29cce2e8db208bb6a14d
since: None
paths: EchoelStudio/Core/Sources/EchoelCore/DiagnosticLog.swift, EchoelStudio/Core/Tests/EchoelCoreTests/DiagnosticLogTests.swift, EchoelStudio/App/EchoelStudioApp.swift, EchoelStudio/App/Engine/AudioEngine.swift, scratchpads/factory/010-diagnostics-hardening
criteria: 10  deviceCriteria: []  founderAssumptions: 0  recount: False
workflow: wf_7897b747-bee

reason: all 10 criteria graded, every code criterion met

unmet: []
founderOpen: []
deviceAsks: []

## approver

```json
{
 "decision": "APPROVE",
 "why": "I counted the spec at 5fa246424 myself before opening board.json or the reviews: 10 numbered acceptance criteria, none tagged [DEVICE], and no Assumption tagged [FOUNDER]. A1 to A6 carry no tag. A6 only lists what stays out, including the docs/privacy.html sentence, so it decides nothing the founder owns. board.json records base eb590a34007cfb182dcfcb4bdf6d9006363aa6c4, so the range under review is the whole job. The unscoped diff touches six files: DiagnosticLog.swift, DiagnosticLogTests.swift, EchoelStudioApp.swift, AudioEngine.swift, and the job's own spec.md and board.json. None of them is locked at the base: PROTECTED_FILES is .claude/settings.json and .mcp.json, PROTECTED_DIRS is empty, and permissions.ask covers settings.json, .mcp.json and .claude/hooks/**. No CLAUDE.md and nothing under .claude/rules/ changed. Context.md §3 at the base also names workflows, project.yml and Info.plist; none of those is touched. The change decides nothing the founder owns: no scope, money, legal or licence text, health wording, store submission or deletion of user data. It is a repair of job 008's own diagnostics file, and the reworded headers are ones no shipped build carries; A2 says so and the ux lens confirmed it. I checked criteria 6, 8 and 9 by reading the code at head. Every new and changed test is present, and I traced the oversize, broken-byte and domain tests by hand against the code. On CI, the 'Echoel Studio' run 39885512255 on 5fa246424 concluded success: Core + DSP + Engine tests on the macOS host, the simulator build, the launch smoke and the Release device build. 'Echoel Studio (Linux)' run 39885512238 also concluded success. All four lenses passed. Their minors are real but non-blocking. The oversize test does not tell a tail read from a whole-file read; the code at :62 and :133-140 does read only the tail. The doc wording overstates what the shape filter keeps out. The 2*capacity+64 overflow cannot happen through the only caller, which uses the 256 KiB default. The full line still says 'this run'. Lines can be written in lock order rather than time order, which has no effect while every writer is on the main actor. All of these are good inputs for the next diagnostics slice. Nothing here is verified on a device, and the spec claims nothing that would need it.",
 "acceptance": [
  {
   "number": 1,
   "criterion": "Only own lines are carried into the run before: testOnlyTheLogsOwnLinesAreCarriedOver and testAFileThisLogDidNotWriteIsNotCarriedOver green.",
   "kind": "code",
   "met": true,
   "evidence": "DiagnosticLogTests.swift:138 and :197 at 5fa246424. The implementation is DiagnosticLog.ownLines/isOwn at :152-173 (timestamp shape, then a character, no Cc scalars). Echoel Studio run 39885512255 job 'Core + DSP + Engine', step 'Test (macOS host)' = success, and Echoel Studio (Linux) run 39885512238 = success, both on 5fa246424."
  },
  {
   "number": 2,
   "criterion": "A broken UTF-8 byte at the end of the file does not cost the run before: testABrokenByteDoesNotCostTheRunBefore green.",
   "kind": "code",
   "met": true,
   "evidence": "DiagnosticLogTests.swift:121. tail(of:bytes:) at DiagnosticLog.swift:133-140 decodes with String(decoding:as: UTF8.self), so the cut E2 86 becomes U+FFFD (category So, not control) and isOwn keeps the line. CI is green as in criterion 1."
  },
  {
   "number": 3,
   "criterion": "An oversized file is read only at its end, and the newest lines that fit one capacity are carried over: testAnOversizedFileIsReadOnlyAtItsEnd green.",
   "kind": "code",
   "met": true,
   "evidence": "DiagnosticLogTests.swift:150, green in run 39885512255 and Linux run 39885512238. By hand: the 20 lines with reason=10..29 at 49 B make 980 B; reason=9 would make 1028 B, over 1024, so the loop stops there. The read is tail-only at DiagnosticLog.swift:62 (2 * capacity + 64) and :133-140. The test alone would not catch a return to a whole-file read (code-reviewer minor)."
  },
  {
   "number": 4,
   "criterion": "An error domain stays a short line: testAnErrorDomainStaysOneShortLine and testAnErrorIsWrittenByDomainAndCodeNeverByItsDescription green.",
   "kind": "code",
   "met": true,
   "evidence": "DiagnosticLogTests.swift:169 and :109. DiagnosticLog.domain at :184-189 keeps ASCII letters, digits and ._- from the last 64 characters and maps everything else to '_'. By hand, 'bad\\ndomain (with) spaces' becomes 'bad_domain__with__spaces'. CI is green as in criterion 1."
  },
  {
   "number": 5,
   "criterion": "The full line carries its time stamp, and the run stays within the capacity computed from the real stamp length: testARunStopsAtItsCapacityWithOneLastLine green.",
   "kind": "code",
   "met": true,
   "evidence": "DiagnosticLogTests.swift:79 asserts the suffix '2026-10-23T01:15:00.250Z  ' + fullLine. DiagnosticLog.append at :113-120 sizes the reserve as (time + '  ' + fullLine + '\\n').utf8.count. CI is green as in criterion 1."
  },
  {
   "number": 6,
   "criterion": "The clock never runs under the lock: every Self.timestamp(clock()) in DiagnosticLog.swift comes before lock.lock() in the same function.",
   "kind": "code",
   "met": true,
   "evidence": "`git show 5fa246424:EchoelStudio/Core/Sources/EchoelCore/DiagnosticLog.swift | grep -n 'timestamp(clock())\\|lock.lock()'` gives 50/51 (begin), 85/86 (note with fields) and 96/97 (note with error). text() at 104-105 never calls the clock."
  },
  {
   "number": 7,
   "criterion": "Headers '== latest run ==' / '== run before ==', and the launch line ends with ', times in UTC': testARunStartsWithItsVersionAndBuild and testANewRunKeepsTheLastRunAndDropsTheOneBefore green.",
   "kind": "code",
   "met": true,
   "evidence": "DiagnosticLog.swift:20-22 (runBeforeHeader, latestRunHeader) and :49 (launch line '..., times in UTC'). The tests are at DiagnosticLogTests.swift:20 and :56. CI is green as in criterion 1."
  },
  {
   "number": 8,
   "criterion": "StoreController() is built in EchoelStudioApp.init() AFTER DiagnosticLog.beginApp(), not as the property's default value.",
   "kind": "code",
   "met": true,
   "evidence": "EchoelStudioApp.swift at 5fa246424: the declaration is `@State private var plugins: StoreController`, with no default. DiagnosticLog.beginApp() is at :21 and `_plugins = State(initialValue: StoreController())` is at :38."
  },
  {
   "number": 9,
   "criterion": "AudioEngine.failed(_:_:) passes the error description to os_log with privacy: .private.",
   "kind": "code",
   "met": true,
   "evidence": "AudioEngine.swift:160-161 at 5fa246424: log.error(\"\\(event.description, privacy: .public) — \\(error.localizedDescription, privacy: .private)\")."
  },
  {
   "number": 10,
   "criterion": "On the head, 'Echoel Studio' (macOS: Core tests, app for Simulator and Release device) and 'Echoel Studio (Linux)' are green.",
   "kind": "code",
   "met": true,
   "evidence": "`gh run view 39885512255 -R vibrationalforce/Echoelmusic --json status,conclusion` returned 'completed success' (head_sha 5fa2464245b8). Job 'Core + DSP + Engine' was all success. In job 'App (iPhone + iPad)', 'Build for iOS Simulator' and 'Extension carries no engine code' were success before the run finished; the launch smoke and 'Build for iOS device (Release)' then completed with the run, which concluded success. Echoel Studio (Linux) run 39885512238 concluded success on the same sha."
  }
 ],
 "forTheHuman": [],
 "specCriteria": 10,
 "specDevice": [],
 "specFounder": 0
}
```
