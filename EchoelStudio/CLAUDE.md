# EchoelStudio/ — the restart (2026-10-17)

This directory is the new app. **The build plan (`NEUPLANUNG_2026-10-18.md`, approved
2026-10-18: no genres, no generated notes, EchoelStudio is ordered rather than rewritten,
phase P0 before 1.0) and the product scope (`NEUSTART_2026-10-17.md`) live under `docs/dev/` in
the private repo `echoelmusic-intern` since 2026-11-05. Read both there before any change here.
The song format is public: `docs/FORMAT.md`, pinned by
`Core/Tests/EchoelCoreTests/FormatGoldenTests.swift` — a change that breaks it is a format
version bump with a migration, never an edit to the golden files.** The root `CLAUDE.md` is
the map of the whole repo, and its universal laws apply here too. The legacy bio-instrument
under `Sources/Echoelmusic` has its own law in `Sources/CLAUDE.md` (moved there 2026-11-01) —
its PRODUCT rules do not apply here. Its engineering lessons do, and the ones that matter are
restated below so nothing has to be fished out of the long file.

## Layout

| Path | What | Depends on |
|---|---|---|
| `Core/` | Swift package `EchoelCore`: project document, commands, command catalog, undo, codec, parameters, tempo map | Foundation, Observation |
| `DSP/` | Swift package `EchoelDSP`: oscillator, filter, envelope, PolySynth, drum kit, sampler, EQ/compressor/delay/reverb, loudness (BS.1770) and true peak — pure processors, render-thread safe, no Core | Foundation |
| `Engine/` | Swift package with three libraries. `EchoelKernels`: the instrument and effect kernels (synth, drums, sampler, EQ/compressor/delay/reverb), the synth patch mapping, the demo gate, and the protocols a hosted unit plays through (`HostedInstrument`, `HostedProcessor`). `EchoelEngine`: snapshot, sample-accurate sequencer, mixer, meters, metronome, offline render — render thread, pure Swift, tested offline. `EchoelHost`: the Audio Unit side — `HostedUnit`/`HostedEffect` (a loaded unit for the engine), `StandardEffectUnit` (our effect as an Audio Unit), `SampleFile`; the only place AVFoundation/AudioToolbox enter the package. **Host never depends on Engine**, so the extension can drop the engine (S-26 D1.4) | Kernels: EchoelCore, EchoelDSP, Synchronization · Engine: EchoelKernels plus those · Host: EchoelKernels, EchoelCore, Synchronization, AVFoundation, AudioToolbox |
| `App/` | the app (XcodeGen spec `project.yml`): design system, AVAudioEngine glue, media import, views | EchoelCore, EchoelDSP, EchoelKernels, EchoelEngine, EchoelHost |
| `Plugins/AUv3/` | the ONE AUv3 extension `EchoelPlugins` under `com.echoelmusic.app.auv3` (the only registered Audio Unit id): Synth `eSyn`, Drums `eDrm`, Sampler `eSmp`, the 25 standard effects `xEQ5` … `xDes` (`StandardEffect.extensionComponent`; the one list, which `OwnPlugin.effects` describes), plus `echl` (the earlier app's instrument, kept so saved host sessions open). ONE purchase unlocks the instruments (`PluginUnlock` in `Plugins/Shared/PluginUnlock.swift`, compiled into app and extension, `com.echoelmusic.app.pro` — not in `EchoelCore`: the open packages do not know that anything is sold, 2026-10-19); the effects are free and never demo-locked. Until the purchase is on sale (`PluginUnlock.isOnSale`, false since 2026-11-10) the instruments are not locked either, and the store page offers nothing to buy; the value turns `true` in the build that goes to review with the product. Never add a second extension or product: no other id is registered | EchoelCore, EchoelDSP, EchoelKernels, EchoelHost — never EchoelEngine (since S-26 D1.4) |
| `Plugins/Shared/` | the extension's building blocks: the one instrument unit (`InstrumentAudioUnit` over an `InstrumentKernel`), the principal-class base (demo lock, license, controls), controls from the parameter tree. An extension adds only its `makeUnit` | EchoelCore, EchoelKernels, EchoelHost — never EchoelEngine |

This table is the layout P0 left (S-26 D1, 2026-10-22); NEUSTART §3.4 was the proposal before it.
A module may depend only on modules below it — never the other way round.

## Laws

1. **One door.** The document changes only through `ProjectStore.perform`. UI, MIDI-learn
   and the agent build `Command` values; nothing mutates `Project` directly.
2. **A new command is three edits:** the case in `Command`, its `apply` branch, its
   `CommandCatalog` entry (the compiler enforces the last one). Plus a test.
3. **What a song stores is frozen.** A song file stores field names, the names of scales, tone
   systems, track kinds, monitor modes, devices and presets, the `ParameterKey` inside every mapping and
   lane — and, for the scale, the tone system and the synth waveform, the INDEX of the choice,
   so a new choice goes at the end of its list. `FormatGoldenTests` pins the shapes,
   `StoredNamesTests` the names and orders; never rename one, add a new one at the end and to
   that test in the same commit. The catalog's names, `Command`'s case names and the
   assistant's tool names are written nowhere (measured 2026-10-20: `ProjectCodec` is the only
   encoder) — keep them stable anyway, because the assistant's instructions name them, and the
   day one is written to disk it joins `StoredNamesTests`.
4. **Validate at the door.** `apply` rejects non-finite numbers, out-of-range values,
   unknown and duplicate ids, and leaves the project untouched when it throws.
5. **Render thread** (the `AVAudioSourceNode` block in `App/Engine/AudioEngine.swift`, the
   kernels in `Engine/`, the extension's render block): no locks, no allocation, no ObjC, no file
   I/O, no GCD. It reads a compiled playback plan, never the `Project`.
6. **No hot state in a view body.** Playhead, meters, levels are read by small leaf views.
7. **One presentation slot.** Modals go through one `.sheet(item:)` with an enum. A presented sheet may own ONE presentation of its own (the Sound page's file picker), because it cannot use the root slot without closing itself.
8. **Tests test behaviour.** No test reads source text or prose.
9. **Swift 6 language mode, strict concurrency.** No `print`, no force unwrap.
10. **Network only where the musician turns it on** (NEUPLANUNG §6, rule 3). The places are the
    files `studio.yml`'s "Network only where named" lists, and only they: StoreKit (the app sells
    the one purchase; the extension asks StoreKit only when the shared record says nothing,
    `PluginLicense`); Network MIDI, off until its toggle in the Song menu (`MIDIInput.setNetwork`);
    the live stream, off until Go Live (`StreamPublisher`); the Connections module, each connection
    off until switched on (`UDPSender`); and the Jam (W16), MultipeerConnectivity, off until the
    musician hosts or joins one on its page (Song menu, Connect, Jam…) — `JamLink`. A new connection
    is off by default, shows in the Song menu's Connect section, and joins that list in the same commit.
    Measure, do not trust this line: `git grep -n -E "import (Network|StoreKit|MultipeerConnectivity|HaishinKit|RTMPHaishinKit|SRTHaishinKit)\b|URLSession|NWConnection|MIDINetworkSession" -- 'EchoelStudio/**/*.swift'`.

## Build lessons (each cost one red CI round, 2026-10-17)

- **A local never takes the name of a method or helper in scope.** `let end = end(of:)`,
  `let core = core()` — Swift resolves the name to the local and reports "cannot call value of
  non-function type". Name locals for what they hold (`stop`, `engine`).
- **Split a large view body into builders.** One long `body` expression with nested `ForEach`
  and many modifiers exceeds the type checker's time limit; a property per region and a
  function per row/cell fix it.
- **Every new file imports what it uses.** A sibling file's `import EchoelCore` does not reach
  it; `Tick` and `TimeConversion` were "not in scope" in a fresh Engine file. And a package
  that passes `swift test` on macOS can still fail for iOS: `UnsafeMutableAudioBufferListPointer`
  comes with `import AudioToolbox` on macOS only; on iOS it needs `import AVFoundation`. `AUAudioUnit.requestViewController` needs
  `import CoreAudioKit` — the legacy target only compiled because another file imported it.
- **A `@Sendable` callback may send its captured `self` to the main actor only once.** Two
  `Task { @MainActor in self?.… }` in the same block is "sending 'self' risks causing data races";
  do both steps in one task.
- **Give a test's arithmetic closure its types (2026-10-22).** `(0..<24_000).map { Float(sin(2 * Double.pi
  * 220 * Double($0) / 48_000) * (1 - Double($0) / 24_000)) }` timed out the type checker; name
  the parameter and result (`{ (index: Int) -> Float in … }`) and split the steps. And
  `slice.filter { … }.map(\.field)` compared with `[a + b]` was "ambiguous": an `ArraySlice` has
  two `filter`s — copy it into an `Array` first and give the expected value a type.
- **A test file can hold more than one test class.** Appending at the end of the file puts a
  test into the LAST class, which may lack the helpers. Insert next to the tests it belongs to.
- **No `@MainActor` on an `XCTestCase` class (Linux, 2026-10-19).** swift-corelibs-xctest's
  generated discovery casts every synchronous test to `(T) -> () throws -> ()`; a class-level
  `@MainActor` types them `(T) -> @MainActor () throws -> ()` and the cast traps before any test
  runs — macOS never shows it. A test that needs `ProjectStore` is `async throws` and does its
  work inside `try await MainActor.run { … }`; tests on value types stay synchronous.
- **Inside such a closure, two things the main-actor hop does not carry (Linux run #4):**
  `XCTAssertThrowsError(try …)` makes the closure INFERRED throwing — the test must be
  `async throws` with `try await`, even though nothing throws at runtime; and a local `func`
  does not inherit the closure's isolation — write `@MainActor func` or read `store` outside it.

## Verifying

There is no Swift toolchain in a cloud session. The workflow `.github/workflows/studio.yml`
runs `swift test` for `Core/`, `DSP/` and `Engine/` on macOS, builds each for iOS (the Engine
package by two schemes, `EchoelEngine` and `EchoelHost`, because nothing in the package depends on
the Host), and builds the app for the simulator and as a Release device build; read its job steps on the commit you
pushed (a newer push cancels the older run). On a Mac:
`swift test --package-path EchoelStudio/Core` (likewise `DSP`, `Engine`).

**Commands** (a Mac with Xcode 26; the same lines CI runs, `.github/workflows/studio.yml`):

| What | Command |
|---|---|
| Tests of one package | `swift test --package-path EchoelStudio/Core` (likewise `DSP`, `Engine`) |
| One test class | `swift test --package-path EchoelStudio/Core --filter ChordRowTests` — a source `X.swift` is tested by class `XTests` in its package (219 of 269 sources; four live in `DSPTests.swift` or `EngineCoreTests.swift`) |
| A package for iOS | `cd EchoelStudio/DSP && xcodebuild build -scheme EchoelDSP -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO` (Engine: schemes `EchoelEngine` and `EchoelHost`; Core: `EchoelCore`) |
| The app | `xcodegen generate --spec EchoelStudio/project.yml`, then `xcodebuild build -project EchoelStudio/EchoelStudio.xcodeproj -scheme EchoelStudio -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO` (Release: `-destination 'generic/platform=iOS' -configuration Release`) |
| The checks that need no toolchain | `python3 .claude/hooks/verify-after-edit.py --tree` (every Studio Swift file against the line-decidable laws, the import rows and the network list, read from studio.yml) · `python3 EchoelStudio/Support/CI/swift_imports.py --selftest` |

The CI steps, in order, which a session reads on its own commit: job "Core + DSP + Engine" — Network only where
named · Imports only where named · Test (macOS host) [Core] · Test DSP (macOS host) · Build DSP for iOS · Test Engine
(macOS host) · Build Engine for iOS · Build for iOS [Core]; job "App (iPhone + iPad)" — Generate project · Build for
iOS Simulator · Extension carries no engine code · Launch smoke (iOS Simulator) · Build for iOS device (Release).
App/ and Plugins/ have no test target: their only CI execution is the build and the 20 s launch smoke.

**The module boundary is enforced by building, never by a test (Law 8).** In the gate,
"Imports only where named" compares each library's imports with its row (Core, DSP, Kernels,
Engine, Host; `Plugins/` never imports EchoelEngine) and "Extension carries no engine code"
reads the linked extension. A new import is a deliberate act: widen its row in `studio.yml` in
the same commit. `studio-linux.yml` builds and tests Core, DSP, Kernels and Engine on Linux,
where `EchoelHost` is not declared at all; it measures and does not block the merge.

**Shipping to TestFlight:** bump `EchoelStudio/RELEASE` and push —
`.github/workflows/studio-testflight.yml` archives, signs (App Store Connect API key, automatic
signing), checks that `EchoelPlugins.appex` is inside and uploads build `10000 + run number` of
version 11.0.0. Only bump it on a commit whose `Echoel Studio` run is green. The earlier app's
`.deploy/release` trigger is frozen, so the two never alternate on the same record.

Since 2026-10-20 `EchoelStudio/**` starts the auto-merge, and the `Echoel Studio` run
(`studio.yml`, read by its conclusion) is the gate for it: a merge that brings Studio code waits
for that run on the same commit. A push to `main` never uploads (`studio-testflight.yml` ignores
`main`). Guard: `TheAutoMergeWaitsForTheGatesTests` claim 8.
