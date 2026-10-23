# Round 1 — concurrency-reviewer: PASS

range: f6143a92e67550bba8a2021458b81c6a7438c1bb..42d91ecfb54b987251777bb67e3649deb7472b8d
since: None
paths: EchoelStudio/Core/Sources/EchoelCore/DiagnosticLog.swift, EchoelStudio/Core/Tests/EchoelCoreTests/DiagnosticLogTests.swift, EchoelStudio/App/Documents/Diagnostics.swift, EchoelStudio/App/EchoelStudioApp.swift, EchoelStudio/App/Engine/AudioEngine.swift, scratchpads/factory/008-diagnostics
criteria: 10  deviceCriteria: []  founderAssumptions: 0  recount: False
workflow: wf_dca9ce6d-79c

Concurrency review, round 1, job 008-diagnostics (f6143a92e..42d91ecfb). I found no blocker and no major finding, and there were no earlier rounds to check. I verified against the source at 42d91ecfb:

(1) DiagnosticLog's `@unchecked Sendable` holds up. Its three mutable fields (handle, written, isFull) are only touched with the NSLock held, in begin, note, note(error:), text and the private append. The deinit access needs no lock. url, capacity and the @Sendable clock never change.

(2) The new `static let app` is a Sendable global with a nonisolated initializer: `DocumentController.defaultDirectory` is declared `nonisolated static var` (DocumentController.swift:167). So the @MainActor-static trap in the CLAUDE.md build-error table does not apply.

(3) Every new `step(...)` or `failed(...)` call in AudioEngine runs in a @MainActor method. In the four NotificationCenter observers (all `queue: .main`) the calls sit inside `MainActor.assumeIsolated` (AudioEngine.swift:176-225). The only value crossing into those closures is `raw: UInt?`, which is Sendable.

(4) Nothing reaches the render thread (Studio law 5). `makeSourceNode`'s @Sendable block and the sink node do not touch DiagnosticLog. A tree-wide `git grep DiagnosticLog` finds only Diagnostics.swift, EchoelStudioApp.init, the scenePhase onChange handler and AudioEngine.step/failed.

(5) No NSLock call is made directly from an async context. The call sites inside `endTake() async` and `beginTake` go through the synchronous step/failed.

(6) The String-to-StaticString change of resume, wake and healIfStopped is complete. All four callers pass literals: "interruption ended", "media services reset", "foreground" and "play".

(7) DiagnosticLogTests is not @MainActor (Studio CLAUDE.md, Linux lesson). Its @Sendable clock closure reads only a `static let` of type Date on a nonisolated XCTestCase subclass.

Compile-verified status: this is a source read only. I ran no build and did not check CI.

## Findings

- **minor** `EchoelStudio/Core/Sources/EchoelCore/DiagnosticLog.swift:85` — The caller-supplied `clock` closure is called while the non-recursive NSLock is held: `append(stamped(line))` at lines 72, 85 and 95, with `stamped` calling `clock()` at line 125. If a clock ever wrote to the same log, or took a lock that a logging thread holds, it would deadlock. The production clock `{ Date() }` and the test clock are both safe, so this is robustness only.
  - Fix: Build the stamped line before `lock.lock()` in `note`, `note(error:)` and the launch line of `begin`, so that only `append` runs under the lock.
