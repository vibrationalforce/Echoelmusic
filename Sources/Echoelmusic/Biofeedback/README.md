# Biofeedback Module

HealthKit integration and biometric signal processing for Echoelmusic.

## Overview

The Biofeedback module connects to Apple HealthKit and wearables to capture real-time biometric data including heart rate, HRV (Heart Rate Variability), and breathing patterns.

## Key Components

| Component | Description |
|-----------|-------------|
| `HealthKitManager` | HealthKit authorization and data queries |
| `RealTimeHealthKitEngine` | Live biometric streaming |
| `HRVCoherenceCalculator` | SDNN, RMSSD, pNN50 calculations |

## Usage

```swift
let manager = HealthKitManager()
await manager.requestAuthorization()

// Start streaming
manager.startHeartRateMonitoring { heartRate in
    // Update audio parameters based on heart rate
}
```

## Metrics

| Metric | Range | Bio-Reactive Mapping |
|--------|-------|---------------------|
| Heart Rate | 40-200 BPM | Tempo, intensity |
| HRV Coherence | 0-1 | Reverb, warmth |
| Breathing Rate | 4-20/min | Delay, envelope |

## Health Disclaimer

This module is NOT a medical device. All biometric features are for creative and wellness purposes only. No medical claims are made.

## Privacy

- HealthKit data never leaves device
- No third-party analytics on health data
- User controls all data sharing
