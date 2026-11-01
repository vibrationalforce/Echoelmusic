# Swift & Audio Rules — Mandatory for All Code Changes

## Swift 6 Strict Concurrency
- `@MainActor` on ALL `@Observable` view models
- `nonisolated(unsafe)` for audio thread parameters
- `@Sendable` closures where required — and ALWAYS on a closure literal that a framework
  calls off the main queue, when it is formed inside a `@MainActor` type. Without it the
  closure inherits MainActor isolation; passed as an argument to a module that is not
  concurrency-checked (Dispatch, AVFoundation, CoreMIDI, HealthKit …) it gets an isolation
  check at its ENTRY, and on a worker that check traps (`dispatch_assert_queue` → SIGTRAP)
  before the body runs. Builds 2613/2618 died this way; a `nonisolated` callee does not help.
  An SDK block marked `NS_SWIFT_SENDABLE` (NotificationCenter's) is already safe — check the
  header, not the habit. Guard: `TheOffMainDispatchHandlerIsSendableTests` (four API families).
- No `self` before `super.init()`
- `Task { @MainActor in }` for async UI updates from non-isolated context

## Audio Thread — ABSOLUTE RULES
These apply to ALL code in DSP kernels and render blocks:

### FORBIDDEN on Audio Thread
```
malloc, free, new, delete          — No heap allocation
Array.append, Array.init           — Allocates
String(), String interpolation     — Allocates
Dictionary operations              — Allocates
class instantiation                — Allocates
NSLog, print, os_log               — I/O (os_log OK in non-render paths)
@objc method calls                 — ObjC runtime
DispatchQueue, Task, async/await   — Thread management
NSLock, pthread_mutex, semaphore   — Blocking
fopen, fclose, read, write         — File I/O
```

### SAFE on Audio Thread
```
Pre-allocated Float arrays         — Index access only
vDSP_* functions                   — Accelerate framework
memcpy, memmove                    — C memory ops
Arithmetic (+, -, *, /)            — Direct computation
sin, cos, pow, sqrt, logf          — C math functions
Ring buffer read/write             — Lock-free patterns
nonisolated(unsafe) property access — Atomic-width reads
```

## Naming Conventions
- Types: `PascalCase` (`VocalDSPKernel`, `EchoelVoiceAudioUnit`)
- Functions/Properties: `camelCase` (`processBlock`, `detectedPitch`)
- Constants: `camelCase` (`defaultSampleRate`)
- Test methods: **sentence-style** in the blocking bundle — a method `testTheXDoesY` in a
  file named TheXDoesYTests, per `Tests/CISmoke/CLAUDE.md` §2 (#374). ⚠️ Those two names are
  PLACEHOLDERS and deliberately carry no backticks: `TheLawFileCitesGuardsThatExistTests`
  requires every backtick-quoted `…Tests` name in the always-loaded files to resolve to a file,
  and a placeholder never can — it was red here from #1232 until #1311. ⛔ The underscore form
  `test[Unit]_[Scenario]_[Expected]` stood here alone and is followed by 0 of the bundle's
  methods (#1232, audit `tests-guards-7`; measure:
  `git grep -ho 'func test[A-Za-z0-9]*_[A-Za-z0-9]*_[A-Za-z0-9_]*' -- 'Tests/CISmoke/*.swift' | wc -l`
  against `git grep -ho 'func test[A-Za-z0-9_]*' -- 'Tests/CISmoke/*.swift' | wc -l`). It
  remains the convention of `Tests/EchoelmusicTests` only (about a third there).
- Commit prefixes: `feat:`, `fix:`, `test:`, `refactor:`, `docs:`, `chore:`, `perf:`

## Logging
```swift
// CORRECT — os_log with OSLog instance
os_log(.info, log: Self.auLog, "Message: %{public}@", value)

// WRONG — print (banned)
print("Message")

// WRONG — calling logger as function
log(.info, ...)

// Math log — use logf() or Foundation.log()
let x = logf(frequency)  // NOT log(frequency) — shadows EchoelLogger
```

## Type Safety
```swift
// CORRECT — guard let
guard let format = AVAudioFormat(...) else { throw error }

// WRONG — force unwrap (banned)
let format = AVAudioFormat(...)!

// CORRECT — safe array access
guard index < array.count else { return }

// CORRECT — safe division
guard divisor != 0 else { return defaultValue }
```

## Platform Guards
```swift
// REQUIRED for UIKit code
#if canImport(UIKit)

// REQUIRED for AVFoundation code
#if canImport(AVFoundation)

// REQUIRED for Metal code
#if canImport(Metal)
```

## `DSP/` imports Foundation and Accelerate, nothing else

```
for f in Sources/Echoelmusic/DSP/*.swift; do grep -o '^import [A-Za-z]*' "$f"; done | sort -u
```

Measure, do not quote: 41 files at GMMW GA-9 (2026-10-08), set exactly `{Foundation, Accelerate}` (7 take
Accelerate). No control-plane type — `EngineBus`, `BioSampleFrame`, `MusicalFrame`,
`PatternEngine` — in **code** there; the four that appear are in comments. A DSP file that
reaches for a Core or Sequencer type has stopped being a pure processor.

⛔ A block of AUv3 patterns stood here for a target removed 2026-07-24; 3 of its 4 symbols then
occurred zero times under `Sources/`. Dead law in the always-loaded set is worse than none —
it is prescriptive, so a session follows it. ⭐ **The target came BACK on 2026-09-20 (#1385) and
the block is still not restored, deliberately**: a rules file earns its place by what a session
must not get wrong, not by completeness, and `Sources/EchoelmusicAUv3/EchoelmusicAudioUnit.swift`
now carries that vocabulary at the one place it is written. The audio-thread bans above apply to
its `internalRenderBlock` exactly as they do to any other render path — that is the law, and it
never needed AUv3-specific phrasing.

⚠️ Reason = hygiene + one-way dependency; stated once, in `FieldSoundSurvivesRelaunchTests`
(#416). ⭐ **Corrected 2026-09-20 (#1385): this line used to end "**not** portability and **not**
AUv3", and the second half has flipped.** The AUv3 extension compiles `Sources/Echoelmusic/DSP`
in ISOLATION — no Core or Sequencer type is even visible there — so a DSP file that reaches for
one is now a BUILD failure in the extension, not merely a hygiene lapse. The rule did not
change; it went back to having teeth, which is how it started. "Not portability" still holds. Do **not** write "Linux-testable": `EchoelWSOLA.swift`
imports Accelerate unguarded where the other 6 use `#if canImport`. Guard, with the long
version of all of this: `TheDSPLayerStaysFoundationOnlyTests`.

## CRITICAL BUILD ERROR PATTERNS

Moved here from the root `CLAUDE.md` on 2026-11-01 (W-MAP): Swift lessons that each cost a red CI
round, and they hold for both apps. The type names in the examples belong to the earlier app
(`Sources/`); Echoel Studio's own build lessons are in `EchoelStudio/CLAUDE.md`.

### Swift Compiler Errors

| Pattern | Fix |
|---------|-----|
| UIKit refs on non-iOS | `#if canImport(UIKit)` |
| @MainActor in Sendable closure | `Task { @MainActor in }` |
| deinit calls @MainActor method | Nonisolated cleanup directly |
| `public let foo: InternalType` | Hard error — match access levels |
| `Color.magenta` | Doesn't exist. Use `Color(red:1,green:0,blue:1)` |
| WeatherKit | `@available(iOS 16.0, *)` AND `#if canImport(WeatherKit)` |
| vDSP overlapping accesses | Copy inputs to temp vars before `vDSP_DFT_Execute` |
| `self` before `super.init()` | Move setup AFTER `super.init()` |
| `inout` + escaping closure | Copy to local var first |
| `@MainActor` property read from a `nonisolated` audio-render block ("main actor-isolated property X can not be referenced from a nonisolated context") | Keep the public `@MainActor` prop for the UI, add an `@ObservationIgnored nonisolated(unsafe)` mirror written in its `didSet`; the render reads the mirror (see SubBassVoice.audioSubGain / PolySynthVoice params) |
| `@Observable` class: a manual stored prop named `_foo` ("invalid redeclaration of '_foo'" / "ambiguous use of '_foo'") | The macro generates `_foo` as `foo`'s backing — never name your own field `_<name>`; use a non-underscore name (e.g. `audioFoo`) |
| `static let` on a `@MainActor` class read from `Task.detached` — "main actor-isolated static property X cannot be accessed from outside of the actor" | Xcode's toolchain isolates it even when immutable (SwiftPM CI may accept the same code — toolchains disagree on SE-0434 inference). Mark it `nonisolated static let` explicitly |
| `static let` holding key paths or closures — "static property X is not concurrency-safe because non-'Sendable' type … may have shared mutable state" | A `KeyPath` is NOT `Sendable` in Swift 6 even when Root and Value are, so a STORED global of them is a hard error (#1402, `MoodProfile.variationSpread`). Make it a COMPUTED `static var` — no storage, nothing to share. Do not paper over it with `nonisolated(unsafe)` |
| `Self.` in a STORED property initializer — "covariant 'Self' type cannot be referenced from a stored property initializer" | Illegal even on a `final class` (#1444, `LightingStore.lookIntensity = Self.defaultLookIntensity`). Write the TYPE NAME. ⚠️ `Self.` in a METHOD body or a computed property is fine, so the legal and the illegal spelling sit a few lines apart in the same file and only one of them is a build error — a §0 transcription cannot see this, only a gate can |

### Language-level notes

Language-level notes that ARE still true and worth keeping:

- `Swift.max`/`Swift.min` must be qualified when a struct in scope has a static
  `.max` property.
- **Argument order in `max`/`min` decides NaN behaviour.** `max(x, y)` is
  `y >= x ? y : x`, so `max(0, NaN)` returns `0` (NaN-safe) while `max(NaN, 0)`
  returns `NaN`. `min(max(v, lo), hi)` therefore passes NaN straight through — use
  the NaN-safe `clamped(to:)` (`Core/FloatingPointClamp.swift`) for anything that
  reaches the audio thread. This has caused shipped permanent-silence bugs.
- `@escaping` required for `TaskGroup.addTask` closures.
- Result builder: `buildBlock(_ components: [T]...)` when using `buildExpression`.

(`Core/FloatingPointClamp.swift` above is the earlier app's file, `Sources/Echoelmusic/Core/FloatingPointClamp.swift`.)
