# Thread Safety in Echoelmusic

How Echoelmusic ensures thread-safe operations across all components.

## Overview

Real-time audio applications require strict thread safety. Echoelmusic uses Swift's actor model to guarantee safe concurrent access to all shared state.

### The Actor Model

All critical state is managed through actors:

```swift
// Audio state is always thread-safe
let audioActor = ThreadSafeManagers.audio

// Safe from any thread
await audioActor.setSampleRate(48000)
let isRunning = await audioActor.isRunning()
```

### Available Actors

| Actor | Purpose |
|-------|---------|
| `AudioEngineActor` | Audio engine state (sample rate, buffer size, etc.) |
| `MIDIEngineActor` | MIDI state (notes, controllers, ports) |
| `VisualEngineActor` | Rendering state (frame rate, resolution) |
| `BiofeedbackActor` | Sensor data (heart rate, HRV, stress) |
| `SessionActor` | Recording state (transport, tempo, tracks) |

### Global Access

Access actors through the global managers:

```swift
// All thread-safe actors in one place
let managers = ThreadSafeManagers.self

await managers.audio.setRunning(true)
await managers.midi.noteOn(60, velocity: 100)
await managers.visual.setFrameRate(60)
await managers.biofeedback.updateHeartRate(72)
await managers.session.startRecording()
```

### Quantum State

For custom thread-safe state, use `QuantumState`:

```swift
// Create a thread-safe state container
let counter = QuantumState<Int>(0)

// Safe atomic operations
await counter.set(10)
await counter.update { $0 += 1 }

// Compare-and-swap for lock-free synchronization
let success = await counter.compareAndSwap(expected: 11, new: 20)
```

### Quantum Lock

For critical sections that can't use actors:

```swift
let lock = QuantumLock()

await lock.withLock {
    // Critical section - only one task can execute this
    performCriticalOperation()
}
```

### Best Practices

1. **Never use shared mutable state** - Use actors instead
2. **Prefer `await` over locks** - Actors are more efficient
3. **Keep actor methods fast** - Long operations block the actor
4. **Use `nonisolated` for read-only properties**

```swift
actor MyActor {
    private var state: Int = 0

    // This blocks the actor while executing
    func updateState(_ newValue: Int) {
        state = newValue
    }

    // Read-only, can be accessed without await
    nonisolated var constantValue: String {
        "constant"
    }
}
```

### Sendable Conformance

All types that cross actor boundaries must be `Sendable`:

```swift
// Struct with only Sendable properties
struct AudioConfig: Sendable {
    let sampleRate: Double
    let bufferSize: Int
}

// Enum is automatically Sendable
enum AudioEvent: Sendable {
    case started
    case stopped
    case levelChanged(Float)
}
```

### Actor Isolation Errors

If you see "Actor-isolated property cannot be mutated from a non-isolated context":

```swift
// Wrong
actor MyActor {
    var value = 0
}
let actor = MyActor()
actor.value = 10 // Error!

// Correct
await actor.setValue(10)
```

## Topics

### Core Actors

- ``AudioEngineActor``
- ``MIDIEngineActor``
- ``VisualEngineActor``
- ``BiofeedbackActor``
- ``SessionActor``

### Utilities

- ``QuantumState``
- ``QuantumLock``
- ``ThreadSafeManagers``
