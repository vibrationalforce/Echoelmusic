# Swift & Audio Rules — Mandatory for All Code Changes

## Swift 6 Strict Concurrency
- `@MainActor` on ALL `@Observable` view models
- `nonisolated(unsafe)` for audio thread parameters
- `@Sendable` closures where required
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
- Test methods: `test[Unit]_[Scenario]_[Expected]`
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

## AUv3 Plugin Patterns
```swift
// Parameter addresses: always use enum
enum ParameterAddress: UInt64 {
    case wetDry = 0
    // ...
}

// Render block: capture kernel, not self
public override var internalRenderBlock: AUInternalRenderBlock {
    let kernel = self.kernel  // Capture value, not self
    return { ... kernel.process(...) ... }
}

// State: round-trip via fullState dictionary
public override var fullState: [String: Any]? {
    get { /* serialize params */ }
    set { /* deserialize params */ }
}
```
