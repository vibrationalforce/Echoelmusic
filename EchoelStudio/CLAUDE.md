# EchoelStudio/ — the restart (2026-10-17)

This directory is the new app. **The build plan is `docs/dev/NEUPLANUNG_2026-10-18.md`
(approved 2026-10-18: no genres, no generated notes, EchoelStudio is ordered rather than
rewritten, phase P0 before 1.0); product and scope are in `docs/dev/NEUSTART_2026-10-17.md`.
Read both before any change here. The song format is public: `docs/FORMAT.md`, pinned by
`Core/Tests/EchoelCoreTests/FormatGoldenTests.swift` — a change that breaks it is a format
version bump with a migration, never an edit to the golden files.** The root `CLAUDE.md`
describes the legacy bio-instrument under `Sources/Echoelmusic` — its PRODUCT rules do not
apply here. Its engineering lessons do, and the ones that matter are restated below so
nothing has to be fished out of the long file.

## Layout

| Path | What | Depends on |
|---|---|---|
| `Core/` | Swift package `EchoelCore`: project document, commands, command catalog, undo, codec, parameters, tempo map | Foundation, Observation |
| `DSP/` | Swift package `EchoelDSP`: oscillator, filter, envelope, PolySynth, drum kit, sampler, EQ/compressor/delay/reverb, loudness (BS.1770) and true peak — pure processors, render-thread safe, no Core | Foundation |
| `Engine/` | Swift package `EchoelEngine`: snapshot, sample-accurate sequencer, mixer, meters, metronome, offline render, plugin kernels, AUv3 hosting — render thread, tested offline | EchoelCore, EchoelDSP, Synchronization |
| `App/` | the app (XcodeGen spec `project.yml`): design system, AVAudioEngine glue, media import, views | EchoelCore, EchoelDSP, EchoelEngine |
| `Plugins/AUv3/` | the ONE AUv3 extension `EchoelPlugins` under `com.echoelmusic.app.auv3` (the only registered Audio Unit id): Synth `eSyn`, Drums `eDrm`, Sampler `eSmp`, EQ/Compressor/Delay/Reverb `xEQ5`/`xCmp`/`xDly`/`xRvb`, plus `echl` (the earlier app's instrument, kept so saved host sessions open). ONE purchase unlocks the instruments (`EchoelCore.PluginUnlock`, `com.echoelmusic.app.pro`); the effects are free and never demo-locked. Never add a second extension or product: no other id is registered | EchoelCore, EchoelDSP, EchoelEngine |
| `Plugins/Shared/` | the extension's building blocks: the one instrument unit (`InstrumentAudioUnit` over an `InstrumentKernel`), the principal-class base (demo lock, license, controls), controls from the parameter tree. An extension adds only its `makeUnit` | EchoelCore, EchoelEngine |

More modules follow the plan (§3.4): DSP, Engine, App, Plugins. A module may depend only
on modules below it — never the other way round.

## Laws

1. **One door.** The document changes only through `ProjectStore.perform`. UI, MIDI-learn
   and the agent build `Command` values; nothing mutates `Project` directly.
2. **A new command is three edits:** the case in `Command`, its `apply` branch, its
   `CommandCatalog` entry (the compiler enforces the last one). Plus a test.
3. **Catalog names are stable.** They are stored in MIDI mappings and agent transcripts.
   Never rename one; add a new command instead.
4. **Validate at the door.** `apply` rejects non-finite numbers, out-of-range values,
   unknown and duplicate ids, and leaves the project untouched when it throws.
5. **Render thread** (once the engine exists): no locks, no allocation, no ObjC, no file
   I/O, no GCD. It reads a compiled playback plan, never the `Project`.
6. **No hot state in a view body.** Playhead, meters, levels are read by small leaf views.
7. **One presentation slot.** Modals go through one `.sheet(item:)` with an enum. A presented sheet may own ONE presentation of its own (the Sound page's file picker), because it cannot use the root slot without closing itself.
8. **Tests test behaviour.** No test reads source text or prose.
9. **Swift 6 language mode, strict concurrency.** No `print`, no force unwrap.

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
- **A test file can hold more than one test class.** Appending at the end of the file puts a
  test into the LAST class, which may lack the helpers. Insert next to the tests it belongs to.

## Verifying

There is no Swift toolchain in a cloud session. The workflow `.github/workflows/studio.yml`
runs `swift test` for `Core/`, `DSP/` and `Engine/` on macOS, builds each for iOS, and builds the
app for the simulator and as a Release device build; read its job steps on the commit you
pushed (a newer push cancels the older run). On a Mac:
`swift test --package-path EchoelStudio/Core` (likewise `DSP`, `Engine`).

⚠️ `EchoelStudio/**` is in no auto-merge path filter yet: a commit touching only this
directory does not reach `main` by itself. That is deliberate until the Studio workflow is a
merge gate.
