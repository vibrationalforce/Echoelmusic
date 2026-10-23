# Round 1 — security-agent: PASS

range: f6143a92e67550bba8a2021458b81c6a7438c1bb..42d91ecfb54b987251777bb67e3649deb7472b8d
since: None
paths: EchoelStudio/Core/Sources/EchoelCore/DiagnosticLog.swift, EchoelStudio/Core/Tests/EchoelCoreTests/DiagnosticLogTests.swift, EchoelStudio/App/Documents/Diagnostics.swift, EchoelStudio/App/EchoelStudioApp.swift, EchoelStudio/App/Engine/AudioEngine.swift, scratchpads/factory/008-diagnostics
criteria: 10  deviceCriteria: []  founderAssumptions: 0  recount: False
workflow: wf_dca9ce6d-79c

Security/privacy lens, round 1. There are no earlier reviews to reconcile: the job folder holds only board.json and spec.md. The diff does not touch .claude/, any CLAUDE.md or .claude/rules/. I found no blocker or major issue.

Checked against the source:
(1) Content of the file. Event, reason and field names are StaticString and values are Double, so a call site cannot put a runtime String into a line; the compiler enforces this. resume/wake/healIfStopped were narrowed from String to StaticString, so a caller that passes a String no longer compiles. Version and build are filtered to digits and dots, at most 16 characters (DiagnosticLog.swift:138-141). Errors write _domain and _code only (DiagnosticLog.swift:92). The os_log mirror of each line is .public, but the line is static text plus numbers.
(2) Location and exposure. The file is Documents/Diagnostics/Echoel diagnostics.log, a fixed path with no user-derived component, so nothing can escape the folder. It is outside both App Groups, so the plugin extension and foreign hosts cannot read it. The app has no iCloud or ubiquity entitlement (Support/App/EchoelStudio.entitlements has App Groups only), so the file never syncs. It is excluded from backup (Diagnostics.swift:18-21). ProjectLibrary.list() and package(_:) filter on pathExtension == "echoel", so the folder is never read as a song. Nothing sends the file off the device; the musician shares it manually from Files. NSPrivacyCollectedDataTypes stays empty, which is still true.
(3) Privacy manifest. The new code calls no new required-reason API: no file timestamps, no boot time, no disk space, no UserDefaults. createDirectory, Data.write(.atomic), FileHandle, String(contentsOf:) and the isExcludedFromBackup resource value are all unlisted, so PrivacyInfo.xcprivacy needs no change.
(4) Render thread. Every DiagnosticLog caller is on the main actor: App.init, the scenePhase handler, and AudioEngine methods and notification handlers under MainActor.assumeIsolated. None is inside makeSourceNode, the sink-node closures or the detached drain task. The lock and the file write therefore never reach a render path.
(5) Untrusted input. The only foreign input is the existing log file, which the user can replace through Files or Finder. A folder or file placed in the way makes the log go silent without throwing, and the tests cover this.

Four minor hardening notes, none blocking:
- An oversized file is read whole at launch, on the main thread.
- NSError domains are a free-form string and are not filtered.
- The carry-over keys on a marker line, not on who wrote the file.
- One os_log line that was already .public keeps localizedDescription public.

This is compile-level reasoning from reading the source; nothing was run (no toolchain). Device behaviour of the Files door is not verified.

## Findings

- **minor** `EchoelStudio/Core/Sources/EchoelCore/DiagnosticLog.swift:56` — begin() reads the existing log whole with String(contentsOf:) and then searches it backwards. It runs on the main thread inside EchoelStudioApp.init (EchoelStudioApp.swift:21), before anything else. The file sits in a folder the user can write to through Files or Finder file sharing (UIFileSharingEnabled + LSSupportsOpeningDocumentsInPlace). Under the app's own writes it stays below about 2 x 256 KiB. A large foreign file put at that exact name would be loaded into memory at every launch, which can mean a watchdog or jetsam kill before the file is ever rewritten, and so a launch loop. It is self-inflicted and needs the exact path, which is why it is minor.
  - Fix: Check the size first (FileHandle + seekToEnd), read only the last 2 x capacity bytes (seek(toOffset: max(0, size - 2*capacity))), then decode and look for the marker in that tail.
- **minor** `EchoelStudio/Core/Sources/EchoelCore/DiagnosticLog.swift:92` — A5 says the types decide what a line can hold, but error._domain is a runtime String and is written unfiltered. For Swift errors it is the type name, which is safe. For an NSError it is whatever string the producer chose. configure() can surface errors from engine.start(), and those can come from hosted third-party Audio Units, so the one free-form string in the file is not covered by the StaticString guarantee. In theory it could carry a newline (forged lines, or a forged '== this run ==' marker that moves the next launch's carry-over cut) or arbitrary text.
  - Fix: Pass _domain through an allowlist the same way plain() filters version and build: [A-Za-z0-9._-], cap of about 64 characters, '?' otherwise. Add a test with an NSError whose domain holds a newline and a name.
- **minor** `EchoelStudio/Core/Sources/EchoelCore/DiagnosticLog.swift:132` — Carry-over keys on the presence of the line '== this run ==\n', not on who wrote the file. A file the user dropped or edited that contains the marker has everything after it, up to capacity bytes, copied verbatim under '== previous run ==' into the file the musician later shares. Acceptance criterion 7 ('eine Datei, die dieses Log nicht schrieb, wird nicht übernommen') and the doc claim that nothing a musician typed is ever in the file hold only for marker-less files. testAFileThisLogDidNotWriteIsNotCarriedOver covers only a file without the marker.
  - Fix: Either narrow the wording of criterion 7 and the doc comment to 'a file without this log's header is not carried over', or carry over only lines that match the log's own shape (a timestamp prefix plus static text).
- **minor** `EchoelStudio/App/Engine/AudioEngine.swift:159` — failed(_:_:) still sends error.localizedDescription to os_log with privacy: .public. For the take writer (record: writing failed), an NSCocoa or POSIX description can name the take file inside the song package, and so the song's name. This line existed before the diff and was rewritten here unchanged, so the diff introduces nothing new. The new doc comment ('Only source text and numbers reach the file, never a name a musician typed') is true for the file only. Unified logging ends up in sysdiagnose archives.
  - Fix: Optional: use .private for the description, or log domain and code publicly with the description private, so the os_log mirror keeps the same guarantee as the file.
