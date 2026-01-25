# Core Module

Fundamental utilities and shared components for Echoelmusic.

## Overview

The Core module provides essential utilities, data structures, and shared components used throughout the Echoelmusic platform. It includes async bio data streaming, circuit breakers for fault tolerance, and core definitions.

## Key Components

| Component | Description |
|-----------|-------------|
| `AsyncBioStream` | Async stream for real-time biometric data |
| `CircuitBreaker` | Fault tolerance with exponential backoff |
| `MVPDefinition` | Core MVP feature definitions |
| `EchoelLogger` | Unified logging with categories |

## Usage

```swift
// AsyncBioStream - Real-time bio data
let bioStream = AsyncBioStream()
for await bioData in bioStream {
    updateVisualization(with: bioData)
}

// CircuitBreaker - Fault tolerance
let breaker = CircuitBreaker(name: "api", config: .default)
let result = try await breaker.execute {
    try await fetchData()
}
```

## Circuit Breaker States

| State | Description |
|-------|-------------|
| `closed` | Normal operation, requests pass through |
| `open` | Failures exceeded threshold, requests rejected |
| `halfOpen` | Testing recovery, limited requests allowed |

## Logger Categories

- `audio` - Audio engine operations
- `biofeedback` - Biometric data processing
- `quantum` - Quantum emulation
- `streaming` - Live streaming
- `orchestral` - Film score engine

## Dependencies

- Foundation
- Combine
