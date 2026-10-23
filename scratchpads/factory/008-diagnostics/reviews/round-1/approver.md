# Round 1 — approver: APPROVE

range: f6143a92e67550bba8a2021458b81c6a7438c1bb..42d91ecfb54b987251777bb67e3649deb7472b8d
since: None
paths: EchoelStudio/Core/Sources/EchoelCore/DiagnosticLog.swift, EchoelStudio/Core/Tests/EchoelCoreTests/DiagnosticLogTests.swift, EchoelStudio/App/Documents/Diagnostics.swift, EchoelStudio/App/EchoelStudioApp.swift, EchoelStudio/App/Engine/AudioEngine.swift, scratchpads/factory/008-diagnostics
criteria: 10  deviceCriteria: []  founderAssumptions: 0  recount: False
workflow: wf_dca9ce6d-79c

reason: all 10 criteria graded, every code criterion met

unmet: []
founderOpen: []
deviceAsks: []

## approver

```json
{
 "decision": "APPROVE",
 "why": "I counted the spec at 42d91ecfb myself before reading the board or the reviews. It has 10 numbered acceptance criteria. None is tagged [DEVICE]; A2 says why on purpose (no new surface, the WIP limit is full). No Assumption bullet starts with [FOUNDER], and none mentions it.\n\nboard.json records base f6143a92e67550bba8a2021458b81c6a7438c1bb, the range under review.\n\nThe unscoped diff touches 7 files: 5 under EchoelStudio/ plus spec.md and board.json. At the job base, the founder-locked set is:\n- .claude/settings.json and .mcp.json (protect-founder-gated.py PROTECTED_FILES; PROTECTED_DIRS is empty)\n- .claude/hooks/** (settings.json permissions.ask)\n- .github/workflows/**, project.yml and Resources/iOS/Info.plist (context.md §3)\n\nNone of these is touched. No CLAUDE.md or .claude/rules file changed.\n\nNothing founder-owned is decided:\n- The diff adds no in-app surface, no store, website or claims text, and no legal or health wording.\n- It fixes a promise the plan already makes (NEUPLANUNG §6 promise 1).\n\nEvery criterion has repo evidence. What I checked:\n- I recomputed the four test timestamps against Python datetime, and they match.\n- At the base, AudioEngine.swift has 29 log.info/error lines. At head the criterion-9 grep finds only AudioEngine.swift:159, inside failed(_:_:).\n- The callers of resume, wake and healIfStopped pass only literals, so the change to StaticString holds.\n- DocumentController.defaultDirectory is nonisolated, so the static app log is legal under Swift 6.\n\nCI on the head:\n- \"Echoel Studio (Linux)\" succeeded.\n- \"Echoel Studio / Core + DSP + Engine\" succeeded, so the DiagnosticLog tests are green on macOS and Linux.\n- \"App (iPhone + iPad)\" was still running when I checked, so the app-side compile named in criteria 9 and 10 is not yet confirmed. Auto-merge waits for the Echoel Studio gate, so a red app job cannot reach main.\n\nThe reviewers' minor findings are all hardening notes and none blocks:\n- the previous file is read whole with strict UTF-8;\n- an NSError domain is written unfiltered;\n- carry-over is keyed on the marker line;\n- the full-line has no timestamp;\n- the clock is called under the lock;\n- an @State default value runs before init.\n\nNothing is device-verified.",
 "acceptance": [
  {
   "number": 1,
   "criterion": "A run starts with exactly one line naming version and build, under '== this run =='; the folder is created.",
   "kind": "code",
   "met": true,
   "evidence": "DiagnosticLog.swift begin(version:build:) creates the parent directory and writes thisRunHeader, then the stamped 'app: launch v… (…)' line. DiagnosticLogTests.testARunStartsWithItsVersionAndBuild compares the exact file text, with the file in a not-yet-existing Diagnostics/ subfolder. Core + DSP + Engine passed on head."
  },
  {
   "number": 2,
   "criterion": "A version or build with anything other than digits and dots is written as '?'.",
   "kind": "code",
   "met": true,
   "evidence": "DiagnosticLog.plain(_:) keeps ASCII digits and dots only, at most 16 characters, otherwise '?'. testAVersionThatIsNotDigitsAndDotsIsAQuestionMark asserts 'app: launch v? (?)' and that 'Song' is absent."
  },
  {
   "number": 3,
   "criterion": "A note is in the file before the call returns, with the reason in parentheses, whole numbers without a fraction, others to three places, 'nan' for NaN; the call returns the line without its time.",
   "kind": "code",
   "met": true,
   "evidence": "note(_:because:_:) appends through an unbuffered FileHandle.write under the lock before returning. number(_:) handles whole numbers, 3 places and nan/inf. testANoteIsInTheFileBeforeItReturns reads the file directly with String(contentsOf:) and checks the three returned strings and the three stamped lines."
  },
  {
   "number": 4,
   "criterion": "A new run keeps the last under '== previous run ==' and drops the one before, even when the last was never closed.",
   "kind": "code",
   "met": true,
   "evidence": "begin() takes lastRun(in:), the text after the last thisRunHeader, and rewrites the file atomically with previousRunHeader + last + thisRunHeader. testANewRunKeepsTheLastRunAndDropsTheOneBefore uses three DiagnosticLog instances that are never closed, and asserts 'run one' is gone, run two sits under previous, run three under this, and there is one this-run header."
  },
  {
   "number": 5,
   "criterion": "A run stops at its capacity with exactly one last line; two full runs stay under 2x capacity plus header; the line still reaches os_log.",
   "kind": "code",
   "met": true,
   "evidence": "append(_:) reserves room for fullLine and sets isFull once. note still returns the line, and AudioEngine.step passes it to log.log (AudioEngine.swift:153). testARunStopsAtItsCapacityWithOneLastLine checks size <= 1024, the suffix fullLine said once, the returned line on every call, and the second run <= 2*capacity + previousRunHeader + 1. I verified the arithmetic: last run <= capacity-15, this run <= capacity."
  },
  {
   "number": 6,
   "criterion": "An error is written with domain and code, never its description.",
   "kind": "code",
   "met": true,
   "evidence": "note(_:error:) writes 'error=\\(error._domain) code=\\(error._code)' only. testAnErrorIsWrittenByDomainAndCodeNeverByItsDescription uses a LocalizedError whose description carries 'My Secret Song' and asserts 'Secret' is absent from the file. AudioEngine.failed(_:_:) sends the description to os_log only."
  },
  {
   "number": 7,
   "criterion": "A log that cannot make its folder never throws and writes nothing; a note before begin creates no file; a file this log did not write is not carried over.",
   "kind": "code",
   "met": true,
   "evidence": "begin() catches every error and returns with handle nil. append guards on handle, and lastRun returns '' when the file has no marker. Covered by testALogItCannotWriteStaysSilent (a file is placed where the folder should be), testANoteBeforeTheRunBeganIsDropped and testAFileThisLogDidNotWriteIsNotCarriedOver (a marker-less foreign file). Carry-over is keyed on the marker, a minor point the security lens raised."
  },
  {
   "number": 8,
   "criterion": "Time is UTC to the millisecond, also before 1970 and on the leap day.",
   "kind": "code",
   "met": true,
   "evidence": "timestamp(_:) uses civil-from-days integer arithmetic with floorDivision. testTheTimeIsUTCToTheMillisecond expects 2026-10-23T01:15:00.250Z, 2000-02-29T00:00:00.000Z, 1969-12-31T23:59:58.500Z and 1970-01-01T00:00:00.000Z. I recomputed all four with Python datetime and they match."
  },
  {
   "number": 9,
   "criterion": "Every AudioEngine os_log line goes first to the file, then os_log, at the same place before the step; new rungs for interruption begin/end and every route change with reason code. Check: git grep log.(info|error) yields only the line in failed(_:_:); compile evidence on the head.",
   "kind": "code",
   "met": true,
   "evidence": "`git grep -n 'log\\.\\(info\\|error\\)' 42d91ecfb -- EchoelStudio/App/Engine/AudioEngine.swift` returns only AudioEngine.swift:159, inside failed(_:_:). The same grep at the base counts 29, all converted in place. New rungs: 'engine: interruption began' and 'engine: interruption ended', and 'route: change' with reason=raw, at AudioEngine.swift:180-198. Compile evidence: the Echoel Studio run 39883655718 job 'App (iPhone + iPad)' was still in_progress when I checked. Auto-merge waits for the Echoel Studio gate, so a red app job cannot reach main."
  },
  {
   "number": 10,
   "criterion": "The app begins the run FIRST in EchoelStudioApp.init and writes each scene change (active, inactive, background) before its handler.",
   "kind": "code",
   "met": true,
   "evidence": "EchoelStudioApp.swift:21: DiagnosticLog.beginApp() is the first statement of init(). Lines 100, 104 and 108 write note('app: active' / 'app: background' / 'app: inactive') before each phase's handler. The @State default for plugins = StoreController() runs before init's body (code-lens minor), so this is 'first statement of init'. The app compile was still pending, as in criterion 9."
  }
 ],
 "forTheHuman": [],
 "specCriteria": 10,
 "specDevice": [],
 "specFounder": 0
}
```
