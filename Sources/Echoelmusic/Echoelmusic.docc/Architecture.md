# Architecture Overview

Understanding the quantum-inspired architecture of Echoelmusic.

## Overview

Echoelmusic uses a modern, modular architecture designed for:

- **Thread Safety**: All shared state managed through actors
- **Resilience**: Circuit breakers, retry logic, and self-healing components
- **Cross-Platform**: Unified API across all Apple platforms
- **Security**: End-to-end encryption and certificate pinning

### Layer Diagram

```
┌────────────────────────────────────────────────────────────────┐
│                        Presentation Layer                       │
│    SwiftUI Views │ UIKit Views │ Metal Renderers │ Shaders     │
├────────────────────────────────────────────────────────────────┤
│                         Domain Layer                            │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────────┐   │
│  │ Audio Domain │  │ Visual Domain│  │ Biofeedback Domain │   │
│  │  - Synthesis │  │  - Cymatics  │  │  - HRV Processing  │   │
│  │  - Effects   │  │  - Spectrum  │  │  - Coherence       │   │
│  │  - Spatial   │  │  - Mandala   │  │  - Stress Level    │   │
│  └──────────────┘  └──────────────┘  └────────────────────┘   │
├────────────────────────────────────────────────────────────────┤
│                       Infrastructure Layer                      │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │               Thread-Safe Actors                          │  │
│  │  AudioEngineActor │ MIDIEngineActor │ BiofeedbackActor   │  │
│  │  VisualEngineActor │ SessionActor                         │  │
│  └─────────────────────────────────────────────────────────┘  │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │               Core Services                               │  │
│  │  EventBus │ DependencyContainer │ Logger │ Validator     │  │
│  └─────────────────────────────────────────────────────────┘  │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │               Security & Networking                       │  │
│  │  QuantumEncryption │ CertificatePinner │ WebRTCSignaling │  │
│  │  MDNSDiscovery │ AbletonLinkManager │ AudioTransport     │  │
│  └─────────────────────────────────────────────────────────┘  │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │               Resilience                                  │  │
│  │  CircuitBreaker │ RetryEngine │ FallbackChain            │  │
│  │  SelfHealingComponent │ QuantumState                      │  │
│  └─────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────┘
```

### Event-Driven Architecture

Components communicate through the EventBus:

```swift
// Subscribe to events
await EventBus.shared.subscribe(to: AudioEvent.self) { event in
    switch event {
    case .levelChanged(let level):
        // Update visuals
    case .frequencyChanged(let freq):
        // Update spatial positioning
    }
}

// Publish events
await EventBus.shared.publish(AudioEvent.levelChanged(0.8))
```

### Dependency Injection

The framework uses a centralized DI container:

```swift
// Register services
let container = DependencyContainer.shared
container.register(myAudioService)

// Resolve dependencies
let audioService: AudioServiceProtocol? = container.resolve()
```

### Resilience Patterns

#### Circuit Breaker

Prevents cascading failures:

```swift
let breaker = CircuitBreaker(failureThreshold: 5, resetTimeout: 30)

let result = try await breaker.execute {
    try await networkCall()
}
```

#### Retry Engine

Handles transient failures:

```swift
let retry = RetryEngine(maxAttempts: 3, strategy: .exponentialBackoff(base: 1.0))

let result = try await retry.execute {
    try await unreliableOperation()
}
```

#### Fallback Chain

Provides alternatives when primary fails:

```swift
let chain = FallbackChain<Data>()
    .addStrategy { try await fetchFromNetwork() }
    .addStrategy { try await fetchFromCache() }
    .addStrategy { return defaultData }

let data = try await chain.execute()
```

### Security Architecture

All data transmission uses:

1. **AES-256-GCM Encryption** for data at rest and in transit
2. **ECDH Key Exchange** for secure session establishment
3. **Certificate Pinning** for SSL/TLS connections
4. **Secure Keychain** for sensitive data storage

```swift
// Encrypt audio for transmission
let encryption = QuantumEncryption()
let encrypted = try await encryption.encryptAudioBuffer(samples)

// Secure key exchange
let keyExchange = SecureKeyExchange()
let keyPair = await keyExchange.generateKeyPair()
let sharedSecret = try await keyExchange.deriveSharedSecret(peerPublicKeyData: peerKey)
```

## Topics

### Core Components

- ``EventBus``
- ``DependencyContainer``
- ``Logger``

### Resilience

- ``CircuitBreaker``
- ``RetryEngine``
- ``FallbackChain``
