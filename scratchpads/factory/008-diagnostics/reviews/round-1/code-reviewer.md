# Round 1 — code-reviewer: PASS

range: f6143a92e67550bba8a2021458b81c6a7438c1bb..42d91ecfb54b987251777bb67e3649deb7472b8d
since: None
paths: EchoelStudio/Core/Sources/EchoelCore/DiagnosticLog.swift, EchoelStudio/Core/Tests/EchoelCoreTests/DiagnosticLogTests.swift, EchoelStudio/App/Documents/Diagnostics.swift, EchoelStudio/App/EchoelStudioApp.swift, EchoelStudio/App/Engine/AudioEngine.swift, scratchpads/factory/008-diagnostics
criteria: 10  deviceCriteria: []  founderAssumptions: 0  recount: False
workflow: wf_dca9ce6d-79c

Round 1, code lens. This is the first round, so there are no earlier reviews to check. The diff does not touch .claude/workflows, .claude/agents, any CLAUDE.md or .claude/rules.

What I checked:
- DiagnosticLog's civil-from-days timestamp: I copied it into Python and ran 200,000 random dates against datetime, including negative ones. Zero mismatches.
- The four expected timestamp values in the tests are correct.
- Capacity: a run is at most capacity bytes and two runs are at most 2×capacity+4 bytes, inside the test's 2×capacity+19 bound. The full line always fits, because each earlier append keeps room for it.
- Edge cases: NaN, inf and -0.0 are handled. Integer conversion is guarded below 1e15. The NSLock covers all mutable state, so @unchecked Sendable is justified.
- No force unwraps. Logging goes through os_log/Logger only.
- AudioEngine: all 29 os_log lines from the base are converted, plus 3 new rungs, 32 call sites in total. Every converted rung keeps its place before its step.
- The String to StaticString change for resume/wake/healIfStopped: every caller passes a literal.
- Criterion 9's grep finds only the log.error in failed(_:_:). No name clashes for step or failed. No step call can reach a render path, since the helpers are @MainActor and private.
- DocumentController.defaultDirectory is nonisolated, so the static app log is legal under Swift 6. ProjectLibrary only lists .echoel packages, so the Diagnostics folder is never taken for a song.

CI on 42d91ecfb: "Core + DSP + Engine" and "Core + DSP + Engine on Linux" passed. "App (iPhone + iPad)" was still running when I last checked, so the app-side compile is not yet confirmed. Nothing is device-verified.

No blocker or major findings. Four minor ones below.

## Findings

- **minor** `EchoelStudio/Core/Sources/EchoelCore/DiagnosticLog.swift:56` — begin() reads the previous file with a strict String(contentsOf:encoding:.utf8) under try?. One invalid byte, for example a 3-byte '→' cut short when the device loses power, throws, and the whole previous run is silently dropped and overwritten. That is the post-incident case the file exists for. The same call also loads the whole file into memory on the main thread at launch, with no size limit, so an oversized file placed at that path through the Files app is read in full before it is replaced.
  - Fix: Read the bytes with Data(contentsOf:), or better only the last 2×capacity bytes through a FileHandle. Then decode with String(decoding:as: UTF8.self), which replaces bad bytes instead of throwing, before calling lastRun(in:).
- **minor** `EchoelStudio/Core/Sources/EchoelCore/DiagnosticLog.swift:114` — The 'this run's log is full' line is written without the 'yyyy-mm-ddThh:mm:ss.mmmZ  ' prefix that every other line has, including the launch line. The file format is inconsistent, and the moment the log filled is not recorded.
  - Fix: Write stamped(Self.fullLine) and size the reserve check with the stamped length. Tests that use hasSuffix(fullLine + "\n") and the count of fullLine still pass.
- **minor** `EchoelStudio/Core/Sources/EchoelCore/DiagnosticLog.swift:109` — When a run reaches capacity, it keeps its first 256 KiB and drops everything after. In a long-lived process (many background/foreground cycles at roughly 15 rungs each, or a flapping Bluetooth route writing a 'route: change' line every time), the dropped lines are the ones closest to a later crash, which are the ones most worth sharing. This is the design spec A6 chose, so it is noted, not asked to change.
  - Fix: Optional, for a later slice: keep the tail of the run instead (rotate or trim the current run when it passes capacity), so the end of a run always survives.
- **minor** `EchoelStudio/App/EchoelStudioApp.swift:12` — `@State private var plugins = StoreController()` has a default value, so it is evaluated before the first statement of init(). DiagnosticLog.beginApp() at line 21 is therefore not the first code of the launch, as criterion 10 and its comment suggest. The risk is low, because StoreController.init only starts two Tasks.
  - Fix: Either move plugins to `_plugins = State(initialValue: StoreController())` after beginApp(), or reword the comment and criterion 10 to say 'first statement of init'.
