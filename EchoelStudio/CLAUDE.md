# EchoelStudio/ — the restart (2026-10-17)

This directory is the new app. **The product, scope and architecture are defined in
`docs/dev/NEUSTART_2026-10-17.md`; read it before any change here.** The root `CLAUDE.md`
describes the legacy bio-instrument under `Sources/Echoelmusic` — its PRODUCT rules do not
apply here. Its engineering lessons do, and the ones that matter are restated below so
nothing has to be fished out of the long file.

## Layout

| Path | What | Depends on |
|---|---|---|
| `Core/` | Swift package `EchoelCore`: project document, commands, command catalog, undo, codec, parameters, tempo map | Foundation, Observation |
| `DSP/` | Swift package `EchoelDSP`: oscillator, filter, envelope — pure value types, render-thread safe | Foundation |
| `Engine/` | Swift package `EchoelEngine`: snapshot, synth slots, sample-accurate sequencer, mix, metronome — render thread, tested offline | EchoelCore, EchoelDSP, Synchronization |
| `App/` | the app (XcodeGen spec `project.yml`): design system, AVAudioEngine glue, media import, views | EchoelCore, EchoelDSP, EchoelEngine |

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
  comes with `import AudioToolbox` on macOS only; on iOS it needs `import AVFoundation`.
- **A test file can hold more than one test class.** Appending at the end of the file puts a
  test into the LAST class, which may lack the helpers. Insert next to the tests it belongs to.

## Verifying

There is no Swift toolchain in a cloud session. The workflow `.github/workflows/studio.yml`
runs `swift test` for `Core/` on macOS and builds it for iOS; read its job steps on the
commit you pushed. On a Mac: `swift test --package-path EchoelStudio/Core`.

⚠️ `EchoelStudio/**` is in no auto-merge path filter yet: a commit touching only this
directory does not reach `main` by itself. That is deliberate until the Studio workflow is a
merge gate.
