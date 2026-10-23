# Round 1 — concurrency-reviewer: PASS

range: eb590a340..5fa2464245b82ab5227d29cce2e8db208bb6a14d
since: None
paths: EchoelStudio/Core/Sources/EchoelCore/DiagnosticLog.swift, EchoelStudio/Core/Tests/EchoelCoreTests/DiagnosticLogTests.swift, EchoelStudio/App/EchoelStudioApp.swift, EchoelStudio/App/Engine/AudioEngine.swift, scratchpads/factory/010-diagnostics-hardening
criteria: 10  deviceCriteria: []  founderAssumptions: 0  recount: False
workflow: wf_7897b747-bee

Concurrency lens, round 1 (there are no earlier reviews; scratchpads/factory/010-diagnostics-hardening/reviews/ does not exist at 5fa246424). Nothing here blocks the ship.

DiagnosticLog stays a sound `@unchecked Sendable`. The mutable state (`handle`, `written`, `isFull`) is still only touched under `lock`: `append` is private, and all three callers hold the lock through `defer`. In `begin()` the `append(launch, at:)` at line 74 runs before the deferred unlock fires. `deinit` is the only access without the lock, and it is exclusive. The new statics `runBeforeHeader`, `latestRunHeader`, `tail(of:bytes:)`, `ownLines`, `isOwn` and `domain` are all pure: Sendable `String` constants, or functions that use only their arguments and locals.

Criterion 6 holds. `clock` is a `let` with type `@Sendable () -> Date` (line 29), so calling it outside the lock is race-free. Each `Self.timestamp(clock())` comes before `lock.lock()` in its function: lines 50/51, 85/86 and 96/97. `text()` never calls the clock. The test clock (DiagnosticLogTests.swift:17) returns a static `Date` and shares no state, so reading it outside the lock is safe.

Criterion 8 holds with no isolation change. `StoreController` is `@MainActor @Observable` (StoreController.swift:10-12), and `App.init` is main-actor. `_plugins = State(initialValue: StoreController())` at EchoelStudioApp.swift:38 runs after `DiagnosticLog.beginApp()` at line 21. The two `Task`s that `StoreController.init` starts inherit the main actor, as they did before.

Criterion 9 (AudioEngine.swift:161) only changes the os_log privacy. `failed` is still a method of the `@MainActor` class AudioEngine (line 18).

One minor finding is a side effect of moving the clock out of the lock: under concurrent writers, the order of lines in the file can differ from the order of their times. It has no effect today because every caller is on the main actor.

Findings:
- **minor** `EchoelStudio/Core/Sources/EchoelCore/DiagnosticLog.swift:85` — The time is now read before the lock (lines 50, 85 and 96), so two threads can serialize on the lock in the opposite order to the times they read. Thread A reads t1, thread B reads t2 > t1, B takes the lock first, and the file shows t2 above t1. Also, a note() whose time was read just before a concurrent begin() takes the lock lands in the new run, stamped earlier than that run's launch line. The class doc (line 17) advertises 'Any thread but the render thread', yet the doc on append (line 112) only says the clock runs outside the lock; it never says the file order can now differ from the time order. No effect today: every production caller is main-actor (AudioEngine is @MainActor at AudioEngine.swift:18 and calls the log at lines 152 and 158, the scenePhase handlers at EchoelStudioApp.swift:102-110 run on the main actor, and beginApp runs from App.init).
  - Fix: Add one clause to the doc on append (line 112), or to the class doc at line 17: with concurrent writers, lines appear in lock order, not time order. Alternatively, keep the clock under the lock only for begin(). Do not change the criterion-6 shape.
